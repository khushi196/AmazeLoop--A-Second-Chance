import 'package:flutter/material.dart';
import '../data/models/evaluation_input.dart';
import '../data/report_generator.dart';
import 'submit_item_view.dart';

class HealthCardView extends StatelessWidget {
  final Function(Widget)? onNavigate;
  final Function()? onFinishToHistory;
  final EvaluationInput? evaluation;
  const HealthCardView({super.key, this.onNavigate, this.evaluation, this.onFinishToHistory});

  String _money(num? v, String currency) {
    if (v == null) return '—';
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${v.toStringAsFixed(0)}';
  }

  List<String> _nextSteps(String? disposition, String? warehouse) {
    final wh = warehouse ?? 'nearest warehouse';
    switch (disposition) {
      case 'Resell':
        return [
          'Generate and attach the digital health passport',
          'List on Amazon Renewed (open box)',
          'Ship from $wh to fulfilment',
        ];
      case 'Refurbish':
        return [
          'Route to $wh refurbishment line',
          'Perform minor repair & quality check',
          'Re-grade and list once restored',
        ];
      case 'Recycle':
        return [
          'Send to $wh e-waste partner',
          'Harvest reusable parts',
          'Issue responsible-disposal certificate',
        ];
      default:
        return ['Proceed with the selected disposition'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = evaluation;
    final currency = e?.currency ?? 'INR';
    final disposition = e?.chosenDisposition ?? e?.finalDisposition ?? '—';
    final isOverride = e?.isOverride == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AmazeLoop HealthCard',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F1111), letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Final summary for this product. Attach this card to guarantee authenticity and condition.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                const SizedBox(height: 32),

                // Passport card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Container(height: 8, decoration: const BoxDecoration(color: Color(0xFFFF9900), borderRadius: BorderRadius.vertical(top: Radius.circular(10)))),
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xFF00687A), borderRadius: BorderRadius.circular(4)),
                                child: Text('${(e?.condition ?? 'N/A').toUpperCase()}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                              const SizedBox(width: 16),
                              Text('ID: ${e?.evaluationId ?? '—'}', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
                            ]),
                            const SizedBox(height: 24),
                            Text(e?.productName ?? 'Graded Item',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F1111))),
                            const SizedBox(height: 8),
                            Text(e?.category ?? '', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),

                            // Key metrics
                            Row(
                              children: [
                                Expanded(child: _metric('Condition', e?.condition ?? '—')),
                                Expanded(child: _metric('Est. resale value', _money(e?.estimatedResaleValue ?? e?.normalizedPrice, currency))),
                                Expanded(child: _metric('Disposition', disposition)),
                              ],
                            ),
                            if ((e?.conditionReason ?? '').isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(e!.conditionReason!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Chosen disposition + next steps
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.route, color: Color(0xFFFF9900)),
                        const SizedBox(width: 8),
                        Text('Final disposition: $disposition',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1111))),
                        const SizedBox(width: 12),
                        if (isOverride)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text('OVERRIDDEN', style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ]),
                      const SizedBox(height: 16),
                      const Text('Next steps', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F1111), letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      ..._nextSteps(disposition, e?.nearestWarehouseId).asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              CircleAvatar(radius: 10, backgroundColor: const Color(0xFFFF9900), child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 12),
                              Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 14, color: Color(0xFF0F1111)))),
                            ]),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: e == null
                          ? null
                          : () async {
                              try {
                                await ReportGenerator.downloadReport(e);
                              } catch (err) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate report: $err')));
                                }
                              }
                            },
                      icon: const Icon(Icons.download),
                      label: const Text('DOWNLOAD REPORT', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), foregroundColor: const Color(0xFF0F1111), side: BorderSide(color: Colors.grey.shade300, width: 2)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (onFinishToHistory != null) {
                          onFinishToHistory!();
                        } else if (onNavigate != null) {
                          onNavigate!(SubmitItemView(onNavigate: onNavigate));
                        }
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('CONFIRM & ROUTE', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), backgroundColor: const Color(0xFFFF9900), foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1111))),
      ],
    );
  }
}
