/// Mirrors the EvaluationInput object returned by the /grade Lambda.
class EvaluationInput {
  final String? evaluationId;
  final String? productName;
  final String? category;
  final String? reason;
  final String? orderId;
  final num? originalPrice;
  final num? reportedPrice;
  final num? normalizedPrice;
  final num? avgPrice;
  final String? currentPincode;
  final String? sortingQueue;
  final String? priority;
  final String? createdAt;
  final String? currency;

  // Populated by the AI grading step
  String? condition;
  String? conditionReason;
  num? estimatedResaleValue;

  // Populated by the routing step
  String? recommendedRoute;
  String? finalDisposition;
  String? routeReason;
  num? distanceKm;
  String? nearestWarehouseId;
  String? chosenDisposition;
  bool? isOverride;

  EvaluationInput({
    this.evaluationId,
    this.productName,
    this.category,
    this.reason,
    this.orderId,
    this.originalPrice,
    this.reportedPrice,
    this.normalizedPrice,
    this.avgPrice,
    this.currentPincode,
    this.sortingQueue,
    this.priority,
    this.createdAt,
    this.currency,
    this.condition,
    this.conditionReason,
    this.estimatedResaleValue,
    this.recommendedRoute,
    this.finalDisposition,
    this.routeReason,
    this.distanceKm,
    this.nearestWarehouseId,
    this.chosenDisposition,
    this.isOverride,
  });

  factory EvaluationInput.fromJson(Map<String, dynamic> json) {
    return EvaluationInput(
      evaluationId: json['evaluationId'] as String?,
      productName: json['productName'] as String?,
      category: json['category'] as String?,
      reason: json['reason'] as String?,
      orderId: json['orderId'] as String?,
      originalPrice: json['originalPrice'] as num?,
      reportedPrice: json['reportedPrice'] as num?,
      normalizedPrice: json['normalizedPrice'] as num?,
      avgPrice: json['avgPrice'] as num?,
      currentPincode: json['currentPincode'] as String?,
      sortingQueue: json['sortingQueue'] as String?,
      priority: json['priority'] as String?,
      createdAt: json['createdAt'] as String?,
      currency: json['currency'] as String?,
      condition: json['condition'] as String?,
      conditionReason: json['conditionReason'] as String?,
      estimatedResaleValue: json['estimatedResaleValue'] as num?,
    );
  }
}
