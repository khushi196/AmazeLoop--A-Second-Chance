import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants.dart';
import '../data/models/evaluation_input.dart';
import '../data/repositories/grade_repository.dart';
import '../data/route_helpers.dart';
import '../data/session.dart';

class RoutingDecisionView extends StatefulWidget {
  final EvaluationInput? evaluation;
  const RoutingDecisionView({super.key, this.evaluation});

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
      'bgColor': Color(0xFFE3F2FD),
      'iconColor': Color(0xFF1976D2),
    },
    'Resell': {
      'title': 'Resell',
      'desc': 'Immediate listing on Amazon Renewed.',
      'icon': Icons.storefront,
      'bgColor': Color(0xFFE8F5E9),
      'iconColor': Color(0xFF388E3C),
    },
    'Refurbish': {
      'title': 'Refurbish',
      'desc': 'Minor repair at regional facility.',
      'icon': Icons.build_circle_outlined,
      'bgColor': Color(0xFFFFF3E0),
      'iconColor': Color(0xFFF57C00),
    },
    'Recycle': {
      'title': 'Recycle',
      'desc': 'Responsible e-waste disposal.',
      'icon': Icons.recycling,
      'bgColor': Color(0xFFE0F2F1),
      'iconColor': Color(0xFF00897B),
    },
    'Donate': {
      'title': 'Donate locally',
      'desc': 'Give to a vetted local partner channel for reuse.',
      'icon': Icons.volunteer_activism_outlined,
      'bgColor': Color(0xFFF3E5F5),
      'iconColor': Color(0xFF8E24AA),
    },
  };

  /// The route options visible to the current user, derived from role + item.
  List<Map<String, dynamic>> get _options {
    final e = widget.evaluation;
    final eligibility = deriveRouteEligibility(
      reason: e?.reason,
      sortingQueue: e?.sortingQueue,
      nearestWarehouseId: e?.nearestWarehouseId,
      condition: e?.condition,
      estimatedResaleValue: e?.estimatedResaleValue,
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
        _selected = r.finalDisposition;
        _loading = false;
      });
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
      context.push('/seller/grade/health', extra: widget.evaluation);
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: amazonOrange),
                  const SizedBox(height: 16),
                  Text(
                    'Finding the best next life...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final r = _route!;
    final options = _options;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                // ─── AI Recommendation pill ───
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00687A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF00687A).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Color(0xFF00687A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI RECOMMENDATION:  ${r.finalDisposition.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00687A),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Heading ───
                Text(
                  'Best next life for this product: ${r.finalDisposition}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Route reason ───
                Text(
                  r.routeReason,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),

                // ─── Nearest warehouse (optional) ───
                if (r.nearestWarehouseId != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Nearest warehouse: ${r.nearestWarehouseId} (${r.distanceKm ?? '—'} km away)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),

                // ─── Route option cards ───
                ...options.map((o) {
                  final key = o['key'] as String;
                  final isSelected = _selected == key;
                  final isRecommended = r.finalDisposition == key;
                  final locked = !_overrideMode;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: locked && !isSelected
                          ? null
                          : () => setState(() => _selected = key),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? amazonOrange.withValues(alpha: 0.05)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? amazonOrange
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // Icon circle
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: o['bgColor'] as Color,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                o['icon'] as IconData,
                                color: o['iconColor'] as Color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Title & description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    o['desc'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // AI PICK badge
                            if (isRecommended) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00687A,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00687A,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  'AI PICK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00687A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],

                            // Radio button
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? amazonOrange
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          color: amazonOrange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // ─── Info note for warehouse items ───
                if (_options.any((o) => o['key'] == 'ReturnToOrigin'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Warehouse return items may include Return to Origin when eligible.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Warehouse return items may include Return to Origin when eligible.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── Override recommendation button ───
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _overrideMode
                        ? null
                        : () => setState(() => _overrideMode = true),
                    icon: Icon(
                      Icons.tune,
                      size: 18,
                      color: _overrideMode ? Colors.grey.shade400 : textPrimary,
                    ),
                    label: Text(
                      _overrideMode
                          ? 'Override mode active'
                          : 'Override recommendation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _overrideMode
                            ? Colors.grey.shade400
                            : textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: _overrideMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade400,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Confirm & Continue button ───
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirming ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amazonOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: amazonOrange.withValues(
                        alpha: 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _confirming
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'CONFIRM & CONTINUE',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
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
}
