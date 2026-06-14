/// Buyer's view of an item they've reserved or bought, returned by
/// GET /purchases. Mirrors the backend's purchase shape.
class Purchase {
  final String evaluationId;
  final String title;
  final num price;
  final String currency;
  final String? condition;
  final String? coverImage;
  final String purchaseStatus;
  final DateTime? purchaseTimestamp;
  final DateTime? reservationExpiresAt;
  final int greenCreditsEarned;

  const Purchase({
    required this.evaluationId,
    required this.title,
    required this.price,
    required this.currency,
    this.condition,
    this.coverImage,
    required this.purchaseStatus,
    this.purchaseTimestamp,
    this.reservationExpiresAt,
    this.greenCreditsEarned = 0,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      evaluationId: (json['evaluationId'] ?? '').toString(),
      title: (json['title'] ?? 'Refurbished item').toString(),
      price: (json['price'] as num?) ?? 0,
      currency: (json['currency'] ?? 'INR').toString(),
      condition: json['condition'] as String?,
      coverImage: json['coverImage'] as String?,
      purchaseStatus: (json['purchaseStatus'] ?? 'RESERVED').toString(),
      purchaseTimestamp: _parseDate(json['purchaseTimestamp']),
      reservationExpiresAt: _parseDate(json['reservationExpiresAt']),
      greenCreditsEarned: (json['greenCreditsEarned'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
