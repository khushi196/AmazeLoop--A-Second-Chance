import 'package:flutter/material.dart';
import 'health_card_view.dart';

class RoutingDecisionView extends StatelessWidget {
  final Function(Widget)? onNavigate;
  const RoutingDecisionView({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF00687A).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00687A).withOpacity(0.3))), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 16, color: Color(0xFF00687A)), SizedBox(width: 8), Text('LIKE NEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00687A), letterSpacing: 1.2))])),
                const SizedBox(height: 16),
                const Text('Best next life for this product', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F1111), letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text("Based on our visual analysis and functional checks, we've determined the optimal disposition path to maximize recovery value.", style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [Icon(Icons.route, color: Color(0xFFFF9900)), SizedBox(width: 12), Expanded(child: Text('Recommended route: Resell via Amazon (open box)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F1111))))]),
                            const SizedBox(height: 16),
                            RichText(text: TextSpan(style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5), children: const [TextSpan(text: 'The device exhibits zero cosmetic defects and complete functionality. Bypassing refurbishment and routing directly to high-tier secondary markets will yield the highest margin. Estimated margin increase: '), TextSpan(text: '+24%', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00687A))), TextSpan(text: ' compared to standard wholesale.')])),
                            const SizedBox(height: 24),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('AI Confidence Score', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const Text('98%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F1111)))]),
                            const SizedBox(height: 8),
                            ClipRRect(borderRadius: BorderRadius.circular(4), child: const LinearProgressIndicator(value: 0.98, minHeight: 8, backgroundColor: Color(0xFFEAEDED), valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9900)))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // PASSING NAVIGATION TO NEXT SCREEN
                                if (onNavigate != null) {
                                  onNavigate!(HealthCardView(onNavigate: onNavigate));
                                }
                              },
                              icon: const Icon(Icons.assignment_turned_in),
                              label: const Text('GENERATE HEALTH CARD', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit, size: 18), label: const Text('Override Recommendation'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade300))),
                          ],
                        ),
                      ),
                    ],
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