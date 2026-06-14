import 'package:flutter/material.dart';
import '../constants.dart';
import '../data/models/evaluation_input.dart';
import '../data/report_generator.dart';
import 'routing_decision_view.dart';

class GradingResultView extends StatelessWidget {
  final Function(Widget)? onNavigate;
  final Function()? onFinishToHistory;
  final EvaluationInput? evaluation;
  const GradingResultView({
    super.key,
    this.onNavigate,
    this.evaluation,
    this.onFinishToHistory,
  });

  String _formatPrice(num? value, String currency) {
    if (value == null || value == 0) return 'N/A — Recycle';
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  Color _getConditionColor(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'excellent':
        return const Color(0xFF00875A);
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

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return amazonOrange;
      case 'low':
        return const Color(0xFF00875A);
      default:
        return const Color(0xFF00687A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = evaluation;
    final currency = e?.currency ?? 'INR';

    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── Success icon with confetti dots ───
                  _buildSuccessHeader(),
                  const SizedBox(height: 24),

                  // ─── Title ───
                  const Text(
                    'AI grading complete',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e?.productName ?? 'Item graded successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Condition & Priority badges ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (e?.condition != null)
                        _buildBadge(
                          'Condition: ${e!.condition}',
                          _getConditionColor(e.condition),
                        ),
                      if (e?.condition != null && e?.priority != null)
                        const SizedBox(width: 12),
                      if (e?.priority != null)
                        _buildBadge(
                          'Priority: ${e!.priority}',
                          _getPriorityColor(e.priority),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ─── Normalized resale value card ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: amazonNavy.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              e?.estimatedResaleValue != null
                                  ? 'Normalized resale value'
                                  : 'Normalized resale value',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: amazonNavy.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _formatPrice(
                                e?.estimatedResaleValue ?? e?.normalizedPrice,
                                currency,
                              ),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF00687A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currency,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Condition reasoning ───
                  if (e?.conditionReason != null && e!.conditionReason!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00687A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.psychology_outlined,
                              size: 20,
                              color: Color(0xFF00687A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Condition reasoning',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF00687A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.conditionReason!,
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
                  const SizedBox(height: 20),

                  // ─── Detail rows in two columns ───
                  _buildDetailsGrid(e, currency),
                  const SizedBox(height: 28),

                  // ─── Action buttons ───
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (onNavigate != null && e != null) {
                              onNavigate!(
                                RoutingDecisionView(
                                  onNavigate: onNavigate,
                                  evaluation: e,
                                  onFinishToHistory: onFinishToHistory,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Grading complete. Open the History tab to view results.'),
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
                          child: const Text(
                            'FIND BEST ROUTE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                        SnackBar(
                                          content: Text('Could not generate report: $err'),
                                        ),
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti dots
          Positioned(top: 10, left: 60, child: _confettiDot(amazonNavy.withValues(alpha: 0.6), 6)),
          Positioned(top: 5, left: 90, child: _confettiDot(const Color(0xFF00687A).withValues(alpha: 0.4), 4)),
          Positioned(top: 15, right: 60, child: _confettiDot(amazonNavy.withValues(alpha: 0.5), 5)),
          Positioned(top: 8, right: 85, child: _confettiDot(const Color(0xFF00687A).withValues(alpha: 0.3), 4)),
          Positioned(top: 25, left: 75, child: _confettiDot(const Color(0xFF00687A).withValues(alpha: 0.5), 3)),
          Positioned(top: 20, right: 70, child: _confettiDot(amazonNavy.withValues(alpha: 0.4), 4)),
          // Main check icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF00687A).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 44,
              color: Color(0xFF00687A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confettiDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(EvaluationInput? e, String currency) {
    final leftItems = <_DetailItem>[];
    final rightItems = <_DetailItem>[];

    // Left column
    leftItems.add(_DetailItem(Icons.history, 'Reason', e?.reason ?? '—'));
    if (e?.orderId != null) {
      leftItems.add(_DetailItem(Icons.inventory_2_outlined, 'Order ID', e!.orderId!));
    }
    if (e?.normalizedPrice != null) {
      leftItems.add(_DetailItem(Icons.sell_outlined, 'Normalized price', _formatPrice(e?.normalizedPrice, currency)));
    }
    if (e?.avgPrice != null) {
      leftItems.add(_DetailItem(Icons.bar_chart_outlined, 'Category average', _formatPrice(e?.avgPrice, currency)));
    }
    leftItems.add(_DetailItem(Icons.sort_outlined, 'Sorting queue', e?.sortingQueue ?? '—'));

    // Right column
    if (e?.evaluationId != null) {
      rightItems.add(_DetailItem(Icons.verified_outlined, 'Evaluation ID', e!.evaluationId!));
    }
    rightItems.add(_DetailItem(Icons.calendar_today_outlined, 'Graded on', _formatDate(DateTime.now())));
    rightItems.add(_DetailItem(Icons.smartphone_outlined, 'Model', e?.productName?.split(' ').take(2).join(' ') ?? '—'));
    rightItems.add(_DetailItem(Icons.storage_outlined, 'Storage', '—'));
    rightItems.add(_DetailItem(Icons.circle, 'Color', '—'));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: leftItems.map((item) => _buildDetailRow(item)).toList(),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: rightItems.map((item) => _buildDetailRow(item)).toList(),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $ampm';
  }

  Widget _buildDetailRow(_DetailItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(item.icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              item.value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  _DetailItem(this.icon, this.label, this.value);
}
