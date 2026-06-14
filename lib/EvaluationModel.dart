class Evaluation {
  final String evaluationId;
  final String createdAt;
  final String productName;
  final String category;
  final String condition;
  final String conditionReason;
  final String finalDisposition;
  final String? chosenDisposition;
  final String recommendedRoute;
  final double estimatedResaleValue;
  final String status;
  final List<String> photoUrls;

  Evaluation({
    required this.evaluationId,
    required this.createdAt,
    required this.productName,
    required this.category,
    required this.condition,
    required this.conditionReason,
    required this.finalDisposition,
    this.chosenDisposition,
    required this.recommendedRoute,
    required this.estimatedResaleValue,
    required this.status,
    required this.photoUrls,
  });

  factory Evaluation.fromJson(Map<String, dynamic> json) {
    return Evaluation(
      evaluationId: json['evaluationId'] ?? '',
      createdAt: json['createdAt'] ?? '',
      productName: json['productName'] ?? 'Unknown Device',
      category: json['category'] ?? 'Uncategorized',
      condition: json['condition'] ?? 'Unknown',
      conditionReason: json['conditionReason'] ?? 'No reason provided.',
      finalDisposition: json['finalDisposition'] ?? '',
      chosenDisposition: json['chosenDisposition'],
      recommendedRoute: json['recommendedRoute'] ?? '',
      estimatedResaleValue:
          (json['estimatedResaleValue'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'PENDING',
      photoUrls: json['photoUrls'] != null
          ? List<String>.from(json['photoUrls'])
          : [],
    );
  }
}
