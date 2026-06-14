import 'package:flutter/material.dart';

/// Small inline badge that shows green credits a user earned for an item.
///
/// Used in the buyer's "My Purchases" list and the seller's grading history
/// to surface sustainable-action rewards without adding a dedicated screen.
class GreenCreditBadge extends StatelessWidget {
  final int credits;

  /// Compact = tighter padding/smaller text for dense table rows.
  final bool compact;

  const GreenCreditBadge({
    super.key,
    required this.credits,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (credits <= 0) return const SizedBox.shrink();

    const green = Color(0xFF1B7A3D);
    final tooltip =
        'You earned $credits green credits for keeping this item '
        'in the loop instead of letting it go to waste.';

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: green.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: compact ? 13 : 15, color: green),
            SizedBox(width: compact ? 4 : 6),
            Text(
              '+$credits credits',
              style: TextStyle(
                color: green,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
