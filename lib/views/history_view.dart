import 'package:flutter/material.dart';
import '../constants.dart';
import '../data/repositories/grade_repository.dart';
import '../data/route_helpers.dart';
import '../data/session.dart';
import 'health_card_view.dart';
import '../data/models/evaluation_input.dart';

class HistoryView extends StatefulWidget {
  final Function(Widget)? onNavigate;
  const HistoryView({super.key, this.onNavigate});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final GradeRepository _repo = GradeRepository();
  List<Map<String, dynamic>> _evaluations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final evals = await _repo.listEvaluations(userId: Session.userId);
      if (!mounted) return;
      setState(() {
        _evaluations = evals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Color _conditionColor(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'like new':
        return const Color(0xFF00687A);
      case 'good':
        return const Color(0xFF00875A);
      case 'used':
      case 'fair':
        return Colors.purple.shade700;
      case 'damaged':
      case 'poor':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  ({String label, Color fg, Color bg}) _marketplaceStatus(Map<String, dynamic> ev) {
    final disposition = (ev['chosenDisposition'] ?? ev['finalDisposition'])?.toString();
    final status = ev['status']?.toString();
    final purchaseStatus = ev['purchaseStatus']?.toString();

    if (status != 'ROUTED') {
      return (label: 'Pending', fg: Colors.grey.shade600, bg: Colors.grey.shade100);
    }

    if (disposition == 'Recycle') {
      return (label: 'Recycled', fg: Colors.red.shade700, bg: Colors.red.shade50);
    }
    if (disposition == 'Refurbish') {
      return (label: 'Refurbishing', fg: Colors.purple.shade700, bg: Colors.purple.shade50);
    }
    if (disposition == 'ReturnToOrigin') {
      final label = Session.role == 'customer' ? 'Processing' : 'Returned to origin';
      return (label: label, fg: Colors.indigo.shade700, bg: Colors.indigo.shade50);
    }

    if (disposition == 'Resell') {
      switch (purchaseStatus) {
        case 'SOLD':
          return (label: 'Bought', fg: Colors.green.shade800, bg: Colors.green.shade50);
        case 'RESERVED':
          return (label: 'Reserved', fg: Colors.amber.shade900, bg: Colors.amber.shade50);
        default:
          return (label: 'Listed - not bought', fg: Colors.blue.shade800, bg: Colors.blue.shade50);
      }
    }

    return (label: 'Not listed', fg: Colors.grey.shade600, bg: Colors.grey.shade100);
  }

  String _formatDate(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '—';
    try {
      final dt = DateTime.parse(createdAt);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}\n${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
    }
  }

  String _formatMoney(num? value) {
    if (value == null) return '—';
    return '₹${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Grading History',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'View all previously graded items and their routing dispositions.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: Icon(
                        Icons.refresh,
                        size: 18,
                        color: _loading ? Colors.grey.shade400 : textPrimary,
                      ),
                      label: Text(
                        'Refresh',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _loading ? Colors.grey.shade400 : textPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Content ───
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: CircularProgressIndicator(color: amazonOrange),
                    ),
                  )
                else if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                    ),
                  )
                else if (_evaluations.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No evaluations yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.resolveWith<Color>((_) => Colors.grey.shade50),
            headingRowHeight: 56,
            dataRowMinHeight: 80,
            dataRowMaxHeight: 80,
            horizontalMargin: 24,
            columnSpacing: 32,
            columns: const [
              DataColumn(label: _HeaderCell('DATE')),
              DataColumn(label: _HeaderCell('PRODUCT')),
              DataColumn(label: _HeaderCell('CONDITION')),
              DataColumn(label: _HeaderCell('ROUTE')),
              DataColumn(label: _HeaderCell('RESALE VALUE')),
              DataColumn(label: _HeaderCell('STATUS')),
              DataColumn(label: _HeaderCell('MARKETPLACE')),
              DataColumn(label: _HeaderCell('')), // feedback icon column
              DataColumn(label: _HeaderCell('ACTION')),
            ],
            rows: _evaluations.map((ev) {
              final condition = ev['condition']?.toString();
              final color = _conditionColor(condition);
              final createdAt = ev['createdAt']?.toString() ?? '';
              final resale = ev['estimatedResaleValue'] as num?;
              final disposition = ev['chosenDisposition'] ?? ev['finalDisposition'] ?? '—';
              final dispositionLabel = getPublicDispositionLabel(disposition.toString(), Session.role);
              final status = ev['status']?.toString() ?? 'PENDING';
              final productName = ev['productName']?.toString() ?? '—';
              final category = ev['category']?.toString() ?? '';
              final photoUrls = (ev['photoUrls'] as List?)?.cast<String>();
              final heroPhoto = photoUrls != null && photoUrls.isNotEmpty ? photoUrls[0] : null;

              return DataRow(
                cells: [
                  // Date cell
                  DataCell(
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),

                  // Product cell with image
                  DataCell(
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            image: heroPhoto != null
                                ? DecorationImage(
                                    image: NetworkImage(heroPhoto),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: heroPhoto == null
                              ? Icon(Icons.image, size: 24, color: Colors.grey.shade400)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName.length > 25 ? '${productName.substring(0, 25)}...' : productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                            if (category.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Condition badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        (condition ?? '—').toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  // Route
                  DataCell(
                    Text(
                      dispositionLabel,
                      style: const TextStyle(fontSize: 14, color: textPrimary),
                    ),
                  ),

                  // Resale value
                  DataCell(
                    Text(
                      _formatMoney(resale),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),

                  // Status badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: status == 'ROUTED' ? amazonOrange.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: status == 'ROUTED' ? amazonOrange : Colors.amber.shade800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  // Marketplace status
                  DataCell(
                    Builder(builder: (_) {
                      final m = _marketplaceStatus(ev);
                      return Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: m.fg,
                        ),
                      );
                    }),
                  ),

                  // Feedback flag
                  DataCell(
                    ev['feedbackFlag'] == true
                        ? Tooltip(
                            message: 'Marked as ${ev['feedbackType'] ?? 'mis-graded'}',
                            child: Icon(Icons.flag, size: 16, color: Colors.orange.shade700),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Action
                  DataCell(
                    InkWell(
                      onTap: () {
                        if (widget.onNavigate != null) {
                          final photos = (ev['photoUrls'] as List?)?.map((e) => e.toString()).toList();
                          final e = EvaluationInput(
                            evaluationId: ev['evaluationId']?.toString(),
                            productName: ev['productName']?.toString(),
                            category: ev['category']?.toString(),
                            condition: condition,
                            conditionReason: ev['conditionReason']?.toString(),
                            estimatedResaleValue: resale,
                            finalDisposition: ev['finalDisposition']?.toString(),
                            chosenDisposition: ev['chosenDisposition']?.toString(),
                            recommendedRoute: ev['recommendedRoute']?.toString(),
                            nearestWarehouseId: ev['nearestWarehouseId']?.toString(),
                            photoUrls: photos,
                            bestPhotoIndex: ev['bestPhotoIndex'] as int?,
                          );
                          widget.onNavigate!(HealthCardView(onNavigate: widget.onNavigate, evaluation: e));
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View HealthCard',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 18, color: Colors.blue.shade700),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }
}
