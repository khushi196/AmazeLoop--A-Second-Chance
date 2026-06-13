/// Buyer-facing listing card returned by GET /listings and (in fuller form)
/// GET /listings/{id}. Mirrors the backend's listing shape, with defensive
/// parsing so missing/null fields from older Evaluations don't crash the UI.
class Listing {
  final String listingId;
  final String evaluationId;
  final String title;
  final String? category;
  final num price;
  final String currency;
  final String? condition;
  final double? conditionScore;
  final String? coverImage;
  final List<String> photoUrls;
  final String risk;
  final String? topReturnReason;
  final String sellerType;
  final String? nearestWarehouseId;
  final String? createdAt;

  const Listing({
    required this.listingId,
    required this.evaluationId,
    required this.title,
    this.category,
    required this.price,
    required this.currency,
    this.condition,
    this.conditionScore,
    this.coverImage,
    this.photoUrls = const [],
    required this.risk,
    this.topReturnReason,
    required this.sellerType,
    this.nearestWarehouseId,
    this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      listingId: (json['listingId'] ?? json['evaluationId'] ?? '').toString(),
      evaluationId: (json['evaluationId'] ?? '').toString(),
      title: (json['title'] ?? 'Refurbished item').toString(),
      category: json['category'] as String?,
      price: (json['price'] as num?) ?? 0,
      currency: (json['currency'] ?? 'INR').toString(),
      condition: json['condition'] as String?,
      conditionScore: (json['conditionScore'] as num?)?.toDouble(),
      coverImage: json['coverImage'] as String?,
      photoUrls: json['photoUrls'] is List
          ? List<String>.from(
              (json['photoUrls'] as List).map((e) => e.toString()),
            )
          : const [],
      risk: (json['risk'] ?? 'MEDIUM').toString(),
      topReturnReason: json['topReturnReason'] as String?,
      sellerType: (json['sellerType'] ?? 'WAREHOUSE').toString(),
      nearestWarehouseId: json['nearestWarehouseId'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}
