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

// ---------------------------------------------------------------------------
// Health Card "Sustainability impact" narrative (deterministic, no LLM)
// ---------------------------------------------------------------------------
// A pure text builder so the wording is stable across runs and the numbers can
// never be hallucinated. Honest and approximate by design — always hedged,
// never claims precision or certifications.

/// Rounds reverse-shipping distance: nearest 5 km at/above 50 km, else 1 km.
int _roundReverseKm(double km) {
  if (km <= 0) return 0;
  if (km >= 50) return (km / 5).round() * 5;
  return km.round();
}

/// Rounds a CO2 figure to one decimal place, as a display string.
String _round1(double v) {
  final rounded = (v * 10).round() / 10;
  return rounded.toStringAsFixed(1);
}

/// Builds the 1–2 sentence "Sustainability impact" summary for an item.
///
/// [sourceReason]  "Returned Amazon order" | "Unused at home"
/// [disposition]   "Resell" | "Refurbish" | "Donate" | "Recycle" | "ReturnToOrigin"
/// [reverseKm]     reverse-shipping km avoided vs the default Amazon workflow
/// [transportCo2Kg] transport CO2 (kg) avoided vs the default workflow
/// [reuseCo2Kg]    CO2 (kg) avoided by extending the product's life vs buying new
/// [ownersTotal]   the owner number this listing's next owner will become
///
/// Honest, approximate, Indian English, metric, under ~45 words.
String buildSustainabilityImpact({
  required String sourceReason,
  required String disposition,
  required double reverseKm,
  required double transportCo2Kg,
  required double reuseCo2Kg,
  required int ownersTotal,
}) {
  final km = _roundReverseKm(reverseKm);
  final transport = _round1(transportCo2Kg);
  final reuse = _round1(reuseCo2Kg);
  final owner = 'This will be owner $ownersTotal for this product.';

  // Edge case: nothing measurable saved.
  if (reuseCo2Kg <= 0 && transportCo2Kg <= 0) {
    return 'This item is kept in the loop instead of going to waste. $owner';
  }

  if (sourceReason == 'Returned Amazon order') {
    String s1;
    if (reverseKm > 0 && transportCo2Kg > 0) {
      s1 = 'By routing this Amazon return through AmazeLoop instead of '
          'sending it back to a distant hub, we avoid about $km km of '
          'reverse transport and roughly $transport kg of CO₂.';
    } else if (reverseKm > 0) {
      s1 = 'By routing this Amazon return through AmazeLoop, we avoid about '
          '$km km of reverse transport.';
    } else if (transportCo2Kg > 0) {
      s1 = 'By routing this Amazon return through AmazeLoop, we save roughly '
          '$transport kg of transport CO₂.';
    } else {
      s1 = 'By routing this Amazon return through AmazeLoop, we give the '
          'product another life.';
    }
    final s2 = reuseCo2Kg > 0
        ? 'That also keeps the product in use, avoiding around $reuse kg of '
            'CO₂ compared with buying new. $owner'
        : owner;
    return '$s1 $s2';
  }

  if (sourceReason == 'Unused at home') {
    // An idle home item was never in the reverse-logistics flow, so we never
    // claim reverse-shipping / transport savings here — only the reuse impact.
    final s1 = reuseCo2Kg > 0
        ? 'Instead of sitting unused or being discarded, this item goes back '
            'into circulation, avoiding roughly $reuse kg of CO₂ compared with '
            'buying it new.'
        : 'Instead of sitting unused, this item goes back into circulation for '
            'a second life.';
    return '$s1 $owner';
  }

  // Unknown source reason — neutral, still honest.
  if (reuseCo2Kg > 0) {
    return 'This item is kept in use instead of going to waste, avoiding '
        'around $reuse kg of CO₂ compared with buying new. $owner';
  }
  return 'This item is kept in the loop instead of going to waste. $owner';
}
