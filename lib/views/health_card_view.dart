import 'package:flutter/material.dart';
import 'submit_item_view.dart';

class HealthCardView extends StatelessWidget {
  final Function(Widget)? onNavigate;
  const HealthCardView({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
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
                const Text('Digital Health Passport', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F1111), letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Attach this generated passport to the item. This guarantees authenticity and condition for the secondary market.', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
                  child: Column(
                    children: [
                      Container(height: 8, decoration: const BoxDecoration(color: Color(0xFFFF9900), borderRadius: BorderRadius.vertical(top: Radius.circular(10)))),
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF00687A), borderRadius: BorderRadius.circular(4)), child: const Text('GRADE A+ / LIKE NEW', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1))), const SizedBox(width: 16), Text('ID: AMZ-LOOP-403-123', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))]),
                                  const SizedBox(height: 24),
                                  const Text('Apple iPad Pro 11-inch (3rd Gen)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F1111))),
                                  const SizedBox(height: 8), Text('128GB • Space Gray • Wi-Fi Only', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.qr_code_2, size: 120, color: Color(0xFF0F1111)), const SizedBox(height: 16), const Text('SCAN TO VERIFY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 8), Text('amz.loop/403-123', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Label printed!'), backgroundColor: Color(0xFF00687A)));
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('PRINT PHYSICAL LABEL', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), foregroundColor: const Color(0xFF0F1111), side: BorderSide(color: Colors.grey.shade300, width: 2)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // THIS RESETS THE LOOP BACK TO THE STARTING FORM
                        if (onNavigate != null) {
                          onNavigate!(SubmitItemView(onNavigate: onNavigate));
                        }
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('FINISH & RETURN TO DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold)),
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
}