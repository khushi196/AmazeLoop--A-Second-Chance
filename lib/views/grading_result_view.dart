import 'package:flutter/material.dart';
import 'routing_decision_view.dart';

class GradingResultView extends StatelessWidget {
  final Function(Widget)? onNavigate;
  const GradingResultView({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
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
                    Text('Graded automatically from images in under 2 seconds', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    const SizedBox(height: 32),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF00687A).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 16, color: Color(0xFF00687A)), SizedBox(width: 8), Text('LIKE NEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00687A), letterSpacing: 1.2))])),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: Column(children: [Text('Estimated resale value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)), const SizedBox(height: 8), const Text('₹2500 – ₹3000', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F1111)))]),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // PASSING NAVIGATION TO NEXT SCREEN
                          if (onNavigate != null) {
                            onNavigate!(RoutingDecisionView(onNavigate: onNavigate));
                          }
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), elevation: 0),
                        child: const Text('FIND BEST ROUTE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(onPressed: () {}, child: const Text('View detailed report')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}