import 'listing.dart';

/// The Health Card half of GET /listings/{id} — buyer trust signals.
class HealthCard {
  final String? condition;
  final double? conditionScore;
  final List<String> issues;
  final String? conditionReason;
  final String? routeReason;
  final String? finalDisposition;
  final int? warrantyMonthsRemaining;
  final int owners;
  final double? circularImpactKg;

  const HealthCard({
    this.condition,
    this.conditionScore,
    this.issues = const [],
    this.conditionReason,
    this.routeReason,
    this.finalDisposition,
    this.warrantyMonthsRemaining,
    this.owners = 1,
    this.circularImpactKg,
  });

  factory HealthCard.fromJson(Map<String, dynamic> json) {
    return HealthCard(
      condition: json['condition'] as String?,
      conditionScore: (json['conditionScore'] as num?)?.toDouble(),
      issues: json['issues'] is List
          ? List<String>.from(
              (json['issues'] as List).map((e) => e.toString()),
            )
          : const [],
      conditionReason: json['conditionReason'] as String?,
      routeReason: json['routeReason'] as String?,
      finalDisposition: json['finalDisposition'] as String?,
      warrantyMonthsRemaining: (json['warrantyMonthsRemaining'] as num?)?.toInt(),
      owners: (json['owners'] as num?)?.toInt() ?? 1,
      circularImpactKg: (json['circularImpactKg'] as num?)?.toDouble(),
    );
  }
}

/// Full listing detail returned by GET /listings/{id} — combines the
/// listing card fields with the photos array and the Health Card.
class ListingDetail {
  final Listing listing;
  final List<String> images;
  final HealthCard healthCard;

  const ListingDetail({
    required this.listing,
    this.images = const [],
    required this.healthCard,
  });

  factory ListingDetail.fromJson(Map<String, dynamic> json) {
    return ListingDetail(
      listing: Listing.fromJson(json),
      images: json['images'] is List
          ? List<String>.from(
              (json['images'] as List).map((e) => e.toString()),
            )
          : const [],
      healthCard: json['healthCard'] is Map<String, dynamic>
          ? HealthCard.fromJson(json['healthCard'] as Map<String, dynamic>)
          : const HealthCard(),
    );
  }
}
