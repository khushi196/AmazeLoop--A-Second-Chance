import 'package:flutter/material.dart';
import '../data/repositories/grade_repository.dart';
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
    try {
      final evals = await _repo.listEvaluations(
        userId: Session.userId,
        warehouseId: Session.role == 'warehouse' ? null : null, // use warehouse filter if needed
      );
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
    switch (condition) {
      case 'Like New':
        return const Color(0xFF00687A);
      case 'Good':
        return const Color(0xFFFF9900);
      case 'Used':
        return Colors.purple.shade700;
      case 'Damaged':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Grading History',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F1111), letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('View all previously graded items and their routing dispositions.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 32),
                if (_loading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFFFF9900)))
                else if (_error != null)
                  Center(child: Text(_error!, style: TextStyle(color: Colors.red.shade700)))
                else if (_evaluations.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No evaluations yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ]),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.resolveWith<Color>((_) => const Color(0xFFF3F3F3)),
            dataRowMinHeight: 70,
            dataRowMaxHeight: 70,
            columns: const [
              DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('PRODUCT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('CONDITION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('ROUTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('RESALE VALUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: _evaluations.map((ev) {
              final condition = ev['condition']?.toString();
              final color = _conditionColor(condition);
              final createdAt = ev['createdAt']?.toString() ?? '';
              final dateLabel = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
              final resale = ev['estimatedResaleValue'];
              final disposition = ev['chosenDisposition'] ?? ev['finalDisposition'] ?? '—';
              final status = ev['status']?.toString() ?? 'PENDING';

              return DataRow(cells: [
                DataCell(Text(dateLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                DataCell(Text(ev['productName']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
                    child: Text(condition ?? '—', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                DataCell(Text(disposition, style: const TextStyle(fontSize: 13))),
                DataCell(Text(resale != null ? '₹${(resale as num).toStringAsFixed(0)}' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'ROUTED' ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status == 'ROUTED' ? Colors.green.shade800 : Colors.grey.shade600)),
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () {
                      if (widget.onNavigate != null) {
                        final e = EvaluationInput(
                          evaluationId: ev['evaluationId']?.toString(),
                          productName: ev['productName']?.toString(),
                          condition: condition,
                          estimatedResaleValue: resale as num?,
                          finalDisposition: ev['finalDisposition']?.toString(),
                          chosenDisposition: ev['chosenDisposition']?.toString(),
                          recommendedRoute: ev['recommendedRoute']?.toString(),
                        );
                        widget.onNavigate!(HealthCardView(onNavigate: widget.onNavigate, evaluation: e));
                      }
                    },
                    child: const Text('View HealthCard'),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
