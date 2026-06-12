class ItemPayload {
  final String productName;
  final String category;
  final String reason;
  final String originalPriceOrId;
  final String locationPincode;

  ItemPayload({
    required this.productName,
    required this.category,
    required this.reason,
    required this.originalPriceOrId,
    required this.locationPincode,
  });
}

class GradingResult {
  final String condition; 
  final String estimatedValue; 
  final double confidenceScore; 
  final String routeAction; 
  final String routeReasoning; 
  final String healthCardId;

  GradingResult({
    required this.condition,
    required this.estimatedValue,
    required this.confidenceScore,
    required this.routeAction,
    required this.routeReasoning,
    required this.healthCardId,
  });
}