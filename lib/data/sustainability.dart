/// Sustainability / reverse-logistics estimates.
///
/// These mirror the backend (AmazeLoopListingDetailFunction) formulas exactly
/// so the seller Health Card shows the same numbers a buyer sees on the
/// marketplace listing detail. All values are transparent approximations, not
/// measured figures.
library;

/// Origin warehouse -> manufacturer/returns hub leg added to the measured
/// routing distance. Matches REVERSE_HUB_CONSTANT_KM in the backend.
const int kReverseHubConstantKm = 150;

/// Small-parcel road-freight emission factor (kg CO2e per km). Matches
/// FREIGHT_CO2_KG_PER_KM in the backend.
const double kFreightCo2KgPerKm = 0.12;

/// Estimated manufacturing carbon-footprint avoided (kg CO2e) by reusing the
/// item rather than producing a new one. Coarse, category-keyed lookup —
/// matches circularImpactKg() in the backend.
double circularImpactKg(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('phone') || c.contains('mobile')) return 55;
  if (c.contains('laptop') || c.contains('computer')) return 320;
  if (c.contains('tablet')) return 90;
  if (c.contains('watch') || c.contains('wearable')) return 20;
  if (c.contains('tv') || c.contains('television')) return 380;
  if (c.contains('appliance') || c.contains('kitchen')) return 80;
  if (c.contains('shoe') || c.contains('apparel') || c.contains('clothing')) {
    return 8;
  }
  return 25; // generic fallback
}

/// Estimated reverse-shipping distance (km) avoided by reselling locally.
int reverseShippingAvoidedKm(num? distanceKm) {
  final d = (distanceKm ?? 0).round();
  return d + kReverseHubConstantKm;
}

/// Estimated transport CO2e (kg) saved by avoiding that reverse leg.
double transportCo2SavedKg(num? distanceKm) {
  final km = reverseShippingAvoidedKm(distanceKm);
  return (km * kFreightCo2KgPerKm * 10).round() / 10;
}
