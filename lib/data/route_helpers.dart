/// Role-based routing helpers.
///
/// Adds a small warehouse-only "ReturnToOrigin" disposition without redesigning
/// the existing customer flow. Customers continue to see only Resell /
/// Refurbish / Recycle. Warehouse operators see ReturnToOrigin too, but only
/// when the item came from a customer return AND its origin warehouse is
/// reachable.
///
/// Rules mirrored verbatim from the product spec.
library;

/// Resale value (INR) at or below which a still-usable item is considered
/// "low value" — not worth reselling, so donation becomes a sensible option.
const num kDonateResaleCeilingInr = 1000;

/// Returns the route option keys that should be shown for the given role + item.
/// Customers always get the standard three options. Warehouse users get
/// ReturnToOrigin prepended when the item is eligible. A "Donate" option is
/// appended for still-usable (Used/Good) items whose resale value is too low
/// to be worth listing.
List<String> getVisibleRoutes(String? role, Map<String, dynamic>? item) {
  final routes = <String>['Resell', 'Refurbish', 'Recycle'];
  if (role == 'warehouse' &&
      item?['sourceType'] == 'customer_return' &&
      item?['originWarehouseAvailable'] == true) {
    routes.insert(0, 'ReturnToOrigin');
  }
  if (item?['donateEligible'] == true) {
    routes.add('Donate');
  }
  return routes;
}

/// Customer-safe label for a disposition. If a customer somehow sees
/// "ReturnToOrigin" (an internal logistics state), translate it to "Processing"
/// so the UI never leaks warehouse-only terminology.
String getPublicDispositionLabel(String? finalDisposition, String? role) {
  if (role == 'customer' && finalDisposition == 'ReturnToOrigin') {
    return 'Processing';
  }
  return finalDisposition ?? '—';
}

/// Marketplace push gate. ReturnToOrigin is treated as an internal transfer,
/// never a sellable listing. Recycle never lists. Resell lists once the item
/// is ready_for_sale; Refurbish lists only after refurb completion.
bool shouldPushToMarketplace(String? finalDisposition, String? itemStatus) {
  if (finalDisposition == 'ReturnToOrigin') return false;
  if (finalDisposition == 'Recycle') return false;
  if (finalDisposition == 'Donate') return false;
  if (finalDisposition == 'Resell') {
    return itemStatus == 'ready_for_sale';
  }
  if (finalDisposition == 'Refurbish') {
    return itemStatus == 'refurbished_ready_for_sale';
  }
  return false;
}

/// Derives the eligibility item-shape consumed by [getVisibleRoutes] from an
/// existing evaluation record. The spec asks for `item.sourceType` and
/// `item.originWarehouseAvailable`, so we project the existing fields into
/// that shape without changing the API contract.
Map<String, dynamic> deriveRouteEligibility({
  String? reason,
  String? sortingQueue,
  String? nearestWarehouseId,
  String? condition,
  num? estimatedResaleValue,
}) {
  // "Returned Amazon order" is the customer-return source; everything else is
  // a consumer trade-in or unknown.
  final sourceType = (reason == 'Returned Amazon order' ||
          sortingQueue == 'LOGISTICS_OPTIMIZATION_QUEUE')
      ? 'customer_return'
      : 'consumer_trade_in';

  // Origin warehouse is "available" when we know which hub the item is going
  // through. In the current dataset that's any item with a nearestWarehouseId.
  final originWarehouseAvailable =
      nearestWarehouseId != null && nearestWarehouseId.isNotEmpty;

  // Donation fits a still-usable item (Used/Good) whose resale value is too
  // low to be worth listing on the marketplace.
  final donateEligible = (condition == 'Used' || condition == 'Good') &&
      (estimatedResaleValue ?? 0) <= kDonateResaleCeilingInr;

  return {
    'sourceType': sourceType,
    'originWarehouseAvailable': originWarehouseAvailable,
    'donateEligible': donateEligible,
  };
}
