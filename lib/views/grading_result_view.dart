import 'package:flutter/material.dart';
import '../data/models/evaluation_input.dart';
import '../data/report_generator.dart';
import 'routing_decision_view.dart';

class GradingResultView extends StatelessWidget {
  final Function(Widget)? onNavigate;
  final Function()? onFinishToHistory;
  final EvaluationInput? evaluation;
  const GradingResultView({super.key, this.onNavigate, this.evaluation, this.onFinishToHistory});

  String _formatPrice(num? value, String currency) {
    if (value == null || value == 0) return 'N/A — Recycle';
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final e = evaluation;
    final currency = e?.currency ?? 'INR';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: const Icon(Icons.check_circle, size: 48, color: Color(0xFF00687A))),
                    const SizedBox(height: 24),
                    const Text('AI grading complete', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F1111), letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text(
                      e?.productName ?? 'Item graded successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 32),

                    // Priority badge (from sorting rules)
                    if (e?.condition != null || e?.priority != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF00687A).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified, size: 16, color: Color(0xFF00687A)),
                          const SizedBox(width: 8),
                          Text(
                            (e?.condition ?? '${e?.priority} PRIORITY').toUpperCase(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00687A), letterSpacing: 1.2),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 24),

                    // Estimated resale value (AI-derived; falls back to normalized price)
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: Column(children: [
                        Text(
                          e?.estimatedResaleValue != null ? 'Estimated resale value' : 'Normalized resale value',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatPrice(e?.estimatedResaleValue ?? e?.normalizedPrice, currency),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F1111)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Condition reasoning from the AI step
                    if (e?.conditionReason != null && e!.conditionReason!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8EF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF9900).withOpacity(0.3)),
                        ),
                        child: Text(e.conditionReason!, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Detail rows
                    _detailRow('Reason', e?.reason ?? '—'),
                    if (e?.orderId != null) _detailRow('Order ID', e!.orderId!),
                    if (e?.normalizedPrice != null) _detailRow('Normalized price', _formatPrice(e?.normalizedPrice, currency)),
                    if (e?.avgPrice != null) _detailRow('Category average', _formatPrice(e?.avgPrice, currency)),
                    _detailRow('Sorting queue', e?.sortingQueue ?? '—'),
                    if (e?.evaluationId != null) _detailRow('Evaluation ID', e!.evaluationId!),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (onNavigate != null && e != null) {
                            onNavigate!(RoutingDecisionView(onNavigate: onNavigate, evaluation: e, onFinishToHistory: onFinishToHistory));
                          }
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), elevation: 0),
                        child: const Text('FIND BEST ROUTE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
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
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('DOWNLOAD REPORT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          foregroundColor: const Color(0xFF232F3E),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F1111)))),
        ],
      ),
    );
  }
}
