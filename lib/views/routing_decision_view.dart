import 'package:flutter/material.dart';
import '../data/models/evaluation_input.dart';
import '../data/repositories/grade_repository.dart';
import '../data/route_helpers.dart';
import '../data/session.dart';
import 'health_card_view.dart';

class RoutingDecisionView extends StatefulWidget {
  final Function(Widget)? onNavigate;
  final Function()? onFinishToHistory;
  final EvaluationInput? evaluation;
  const RoutingDecisionView({super.key, this.onNavigate, this.evaluation, this.onFinishToHistory});

  @override
  State<RoutingDecisionView> createState() => _RoutingDecisionViewState();
}

class _RoutingDecisionViewState extends State<RoutingDecisionView> {
  final GradeRepository _repo = GradeRepository();
  bool _loading = true;
  String? _error;
  RouteResult? _route;
  String? _selected;
  bool _overrideMode = false;
  bool _confirming = false;

  static const _optionMeta = {
    'ReturnToOrigin': {
      'title': 'Return to Origin',
      'desc': 'Send back to the originating warehouse / fulfilment centre.',
      'icon': Icons.assignment_return_outlined,
    },
    'Resell': {
      'key': 'Resell',
      'title': 'Resell',
      'desc': 'Immediate listing on Amazon Renewed.',
      'icon': Icons.storefront,
    },
    'Refurbish': {
      'key': 'Refurbish',
      'title': 'Refurbish',
      'desc': 'Minor repair at regional facility.',
      'icon': Icons.build_circle_outlined,
    },
    'Recycle': {
      'key': 'Recycle',
      'title': 'Recycle',
      'desc': 'Responsible e-waste disposal.',
      'icon': Icons.recycling,
    },
  };

  /// The route options visible to the current user, derived from role + item.
  /// Customers always see Resell/Refurbish/Recycle. Warehouse operators get
  /// ReturnToOrigin too when the item came from a customer return AND the
  /// origin warehouse is reachable.
  List<Map<String, dynamic>> get _options {
    final e = widget.evaluation;
    final eligibility = deriveRouteEligibility(
      reason: e?.reason,
      sortingQueue: e?.sortingQueue,
      nearestWarehouseId: e?.nearestWarehouseId,
    );
    final keys = getVisibleRoutes(Session.role, eligibility);
    return keys
        .map((k) => {'key': k, ...?_optionMeta[k]})
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final eid = widget.evaluation?.evaluationId;
    if (eid == null) {
      setState(() {
        _loading = false;
        _error = 'No evaluation to route.';
      });
      return;
    }
    try {
      final r = await _repo.route(eid);
      if (!mounted) return;
      setState(() {
        _route = r;
        _selected = r.finalDisposition; // pre-select the AI recommendation
        _loading = false;
      });
      // mirror onto the evaluation object
      widget.evaluation!
        ..recommendedRoute = r.recommendedRoute
        ..finalDisposition = r.finalDisposition
        ..routeReason = r.routeReason
        ..distanceKm = r.distanceKm
        ..nearestWarehouseId = r.nearestWarehouseId;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirm() async {
    final eid = widget.evaluation?.evaluationId;
    if (eid == null || _selected == null) return;
    setState(() => _confirming = true);
    try {
      final isOverride = await _repo.confirmRoute(eid, _selected!);
      widget.evaluation!
        ..chosenDisposition = _selected
        ..isOverride = isOverride;
      if (!mounted) return;
      setState(() => _confirming = false);
      if (widget.onNavigate != null) {
        widget.onNavigate!(HealthCardView(onNavigate: widget.onNavigate, evaluation: widget.evaluation, onFinishToHistory: widget.onFinishToHistory));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: _loading
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Color(0xFFFF9900)),
                SizedBox(height: 16),
                Text('Finding the best next life...', style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
            )
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red.shade700)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final r = _route!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00687A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00687A).withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF00687A)),
                  const SizedBox(width: 8),
                  Text('AI RECOMMENDATION: ${r.finalDisposition.toUpperCase()}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00687A), letterSpacing: 1.2)),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Best next life for this product: ${r.finalDisposition}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F1111), letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text(r.routeReason, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5)),
              if (r.nearestWarehouseId != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.warehouse_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text('Nearest warehouse: ${r.nearestWarehouseId} • ${r.distanceKm ?? '—'} km',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ]),
              ],
              const SizedBox(height: 32),

              // Option cards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _options.map((o) {
                  final key = o['key'] as String;
                  final isSelected = _selected == key;
                  final isRecommended = r.finalDisposition == key;
                  final locked = !_overrideMode; // can't change unless override mode
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: InkWell(
                        onTap: locked && !isSelected ? null : () => setState(() => _selected = key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF9900).withValues(alpha: 0.06) : Colors.white,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFF9900) : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(o['icon'] as IconData, color: isSelected ? const Color(0xFFFF9900) : Colors.grey.shade600),
                                const Spacer(),
                                if (isRecommended)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFF00687A), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('AI PICK', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: isSelected ? const Color(0xFFFF9900) : Colors.grey.shade400, size: 20),
                              ]),
                              const SizedBox(height: 12),
                              Text(o['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F1111))),
                              const SizedBox(height: 6),
                              Text(o['desc'] as String, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  if (!_overrideMode)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _overrideMode = true),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Override recommendation'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        foregroundColor: Colors.grey.shade800,
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber.shade300)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Text('Override mode — pick any option', style: TextStyle(fontSize: 13, color: Colors.amber.shade900)),
                      ]),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _confirming ? null : _confirm,
                    icon: _confirming
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle),
                    label: Text(_confirming ? 'CONFIRMING...' : 'CONFIRM & CONTINUE', style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
