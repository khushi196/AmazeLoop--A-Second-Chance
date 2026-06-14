import 'package:flutter/material.dart';
import '../constants.dart';
import '../data/models/evaluation_input.dart';
import '../data/report_generator.dart';
import '../data/repositories/grade_repository.dart';
import '../data/sustainability.dart' as sustain;
import 'submit_item_view.dart';

class HealthCardView extends StatelessWidget {
  final Function(Widget)? onNavigate;
  final Function()? onFinishToHistory;
  final EvaluationInput? evaluation;
  /// When true, the card is being viewed for an already-routed item (e.g. from
  /// the History tab), so the primary action is "Back to History" rather than
  /// the end-of-pipeline "Confirm & Route".
  final bool readOnly;
  const HealthCardView({
    super.key,
    this.onNavigate,
    this.evaluation,
    this.onFinishToHistory,
    this.readOnly = false,
  });

  String? _heroPhotoUrl(EvaluationInput? e) {
    if (e == null || e.photoUrls == null || e.photoUrls!.isEmpty) return null;
    final idx = e.bestPhotoIndex ?? 0;
    if (idx >= 0 && idx < e.photoUrls!.length) return e.photoUrls![idx];
    return e.photoUrls![0];
  }

  String _money(num? v, String currency) {
    if (v == null || v == 0) return 'N/A — Recycle';
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  Color _getConditionColor(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'excellent':
      case 'good':
        return const Color(0xFF00875A);
      case 'fair':
        return amazonOrange;
      case 'poor':
        return Colors.red.shade600;
      default:
        return const Color(0xFF00687A);
    }
  }

  List<String> _nextSteps(String? disposition) {
    switch (disposition) {
      case 'Resell':
        return [
          'Item will be listed on AmazeLoop Marketplace.',
          'Quality verification and final listing.',
          'Ready for buyer purchase and shipment.',
        ];
      case 'Refurbish':
        return [
          'Route to refurbishment facility.',
          'Perform repair & quality check.',
          'Re-grade and list once restored.',
        ];
      case 'Recycle':
        return [
          'Send to e-waste partner.',
          'Harvest reusable parts.',
          'Issue responsible-disposal certificate.',
        ];
      case 'ReturnToOrigin':
        return [
          'Route back to origin warehouse.',
          'Inventory reconciliation.',
          'Ready for restocking or processing.',
        ];
      case 'Donate':
        return [
          'Route to a vetted local donation partner.',
          'Partner collects and redistributes the item.',
          'Donation acknowledgement issued.',
        ];
      default:
        return ['Proceed with the selected disposition.'];
    }
  }

  String _getDispositionDescription(String? disposition) {
    switch (disposition) {
      case 'Resell':
        return 'Immediate listing on AmazeLoop Marketplace.';
      case 'Refurbish':
        return 'Minor repair at regional facility.';
      case 'Recycle':
        return 'Responsible e-waste disposal.';
      case 'ReturnToOrigin':
        return 'Return to originating warehouse.';
      case 'Donate':
        return 'Donated to a local partner channel.';
      default:
        return 'Processing your item.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = evaluation;
    final currency = e?.currency ?? 'INR';
    final disposition = e?.chosenDisposition ?? e?.finalDisposition ?? '—';
    final isOverride = e?.isOverride == true;
    final conditionColor = _getConditionColor(e?.condition);

    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                const Text(
                  'AmazeLoop HealthCard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Final summary for this product. Attach this card to guarantee authenticity and condition.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Main Product Card ───
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Orange top bar
                      Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          color: amazonOrange,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Product info row: Image + Details
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product image
                                Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    image: _heroPhotoUrl(e) != null
                                        ? DecorationImage(
                                            image: NetworkImage(_heroPhotoUrl(e)!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _heroPhotoUrl(e) == null
                                      ? Icon(Icons.image, size: 48, color: Colors.grey.shade400)
                                      : null,
                                ),
                                const SizedBox(width: 24),

                                // Product details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Condition badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: conditionColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          (e?.condition ?? 'N/A').toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Product ID
                                      Text(
                                        'Product ID: ${e?.evaluationId ?? '—'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Product name
                                      Text(
                                        e?.productName ?? 'Graded Item',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Category
                                      Text(
                                        'Category: ${e?.category ?? '—'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ─── Metrics row ───
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade200),
                                  bottom: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricItem(
                                      icon: Icons.verified_outlined,
                                      iconColor: conditionColor,
                                      label: 'Condition',
                                      value: (e?.condition ?? '—').toUpperCase(),
                                      valueColor: conditionColor,
                                      sublabel: 'AI-graded',
                                    ),
                                  ),
                                  Container(width: 1, height: 60, color: Colors.grey.shade200),
                                  Expanded(
                                    child: _buildMetricItem(
                                      icon: Icons.sell_outlined,
                                      iconColor: amazonOrange,
                                      label: 'Est. resale value',
                                      value: _money(e?.estimatedResaleValue ?? e?.normalizedPrice, currency),
                                      valueColor: amazonOrange,
                                      sublabel: 'Normalized value',
                                    ),
                                  ),
                                  Container(width: 1, height: 60, color: Colors.grey.shade200),
                                  Expanded(
                                    child: _buildMetricItem(
                                      icon: Icons.local_shipping_outlined,
                                      iconColor: amazonOrange,
                                      label: 'Disposition',
                                      value: disposition.toUpperCase(),
                                      valueColor: amazonOrange,
                                      sublabel: 'Recommended route',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ─── Condition reason ───
                            if ((e?.conditionReason ?? '').isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: amazonNavy.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.description_outlined,
                                        size: 18,
                                        color: amazonNavy,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Condition reason:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            e!.conditionReason!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Final Disposition Card ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: amazonOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.verified_outlined,
                              color: amazonOrange,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Final disposition: ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      disposition,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: amazonOrange,
                                      ),
                                    ),
                                    if (isOverride) ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Text(
                                          'OVERRIDDEN',
                                          style: TextStyle(
                                            color: Colors.amber.shade800,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getDispositionDescription(disposition),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Next steps
                      const Text(
                        'Next steps',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._nextSteps(disposition).asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step number with connecting line
                              Column(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: amazonOrange.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: amazonOrange, width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: amazonOrange,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (entry.key < _nextSteps(disposition).length - 1)
                                    Container(
                                      width: 2,
                                      height: 16,
                                      color: amazonOrange.withValues(alpha: 0.3),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Sustainability impact ───
                _buildSustainabilityCard(e),
                const SizedBox(height: 24),

                // ─── Action buttons ───
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: e == null
                            ? null
                            : () async {
                                try {
                                  await ReportGenerator.downloadReport(e);
                                } catch (err) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not generate report: $err')),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text(
                          'DOWNLOAD REPORT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: textPrimary,
                          side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (onFinishToHistory != null) {
                            onFinishToHistory!();
                          } else if (onNavigate != null) {
                            onNavigate!(SubmitItemView(onNavigate: onNavigate));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Item routed. Check the History tab to track its status.'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: amazonOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          readOnly ? 'BACK TO HISTORY' : 'CONFIRM & ROUTE',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ─── Mis-graded feedback ───
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: e == null
                        ? null
                        : () => _showFeedbackDialog(context, e.evaluationId!),
                    icon: Icon(Icons.flag_outlined, size: 16, color: Colors.grey.shade600),
                    label: Text(
                      'Mark as mis-graded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sustainability impact card — mirrors the buyer marketplace listing detail
  /// so the seller sees the same reuse/reverse-logistics estimates. All values
  /// are transparent approximations.
  Widget _buildSustainabilityCard(EvaluationInput? e) {
    if (e == null) return const SizedBox.shrink();

    final manufacturingCo2 = sustain.circularImpactKg(e.category);
    final hasDistance = e.distanceKm != null;
    final reverseKm = sustain.reverseShippingAvoidedKm(e.distanceKm);
    final transportCo2 = sustain.transportCo2SavedKg(e.distanceKm);
    final owners = 1 + (e.resaleCount ?? 0);
    final isUnusedAtHome = e.reason == 'Unused at home';

    // Deterministic, honest narrative summary (no LLM).
    final summary = sustain.buildSustainabilityImpact(
      sourceReason: e.reason ?? '',
      disposition: e.chosenDisposition ?? e.finalDisposition ?? '',
      reverseKm: hasDistance ? reverseKm.toDouble() : 0,
      transportCo2Kg: hasDistance ? transportCo2 : 0,
      reuseCo2Kg: manufacturingCo2,
      ownersTotal: owners + 1,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.eco_outlined,
                    color: Colors.green.shade700, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Sustainability impact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Deterministic narrative summary.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade900,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sustainRow(
            Icons.recycling_outlined,
            'CO₂ avoided by reuse',
            '${manufacturingCo2.toStringAsFixed(0)} kg',
            'Vs. manufacturing a new unit (approx.)',
          ),
          if (hasDistance && !isUnusedAtHome) ...[
            const SizedBox(height: 16),
            _sustainRow(
              Icons.local_shipping_outlined,
              'Reverse-shipping avoided',
              '$reverseKm km',
              'Resold locally instead of returned to origin (approx.)',
            ),
            const SizedBox(height: 16),
            _sustainRow(
              Icons.co2_outlined,
              'Transport CO₂ saved',
              '${transportCo2.toStringAsFixed(1)} kg',
              'From the avoided reverse leg (approx.)',
            ),
          ],
          const SizedBox(height: 16),
          _sustainRow(
            Icons.people_outline,
            'Owners',
            owners <= 1 ? '1 (original)' : '$owners total',
            'Increases each time the item is resold',
          ),
        ],
      ),
    );
  }

  Widget _sustainRow(
      IconData icon, String label, String value, String sublabel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.green.shade700),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required String sublabel,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  void _showFeedbackDialog(BuildContext context, String evaluationId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Report mis-grading',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: const Text(
            'How was the AI grading inaccurate?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _submitFeedback(context, evaluationId, 'too_optimistic');
              },
              child: const Text('Too optimistic'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _submitFeedback(context, evaluationId, 'too_strict');
              },
              child: const Text('Too strict'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitFeedback(
      BuildContext context, String evaluationId, String feedbackType) async {
    try {
      await GradeRepository().submitFeedback(
        evaluationId: evaluationId,
        feedbackType: feedbackType,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback recorded. Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit feedback: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}
