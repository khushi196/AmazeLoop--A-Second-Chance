import 'package:flutter/material.dart';
import 'constants.dart';
import 'views/dashboard_layout.dart';

/// Customer-facing intro shown after login when the user came through
/// "Sell / Trade-in → Individual seller". Explains the three steps of the
/// AI grading pipeline before pushing them into the existing grading flow.
class SellIntroScreen extends StatelessWidget {
  const SellIntroScreen({Key? key}) : super(key: key);

  static const _steps = [
    {
      'icon': Icons.photo_camera_outlined,
      'title': 'Snap photos',
      'body': 'Take 2-4 clear photos of the item from different angles.',
    },
    {
      'icon': Icons.auto_awesome,
      'title': 'AI grades + Health Card',
      'body':
          'Our AI assesses condition, estimates a fair price, and generates a Product Health Card.',
    },
    {
      'icon': Icons.storefront_outlined,
      'title': 'Set price & publish',
      'body':
          'Confirm the recommended route. Resell items go straight to the marketplace.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text(
          'Sell an Item',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Give your item a second life',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Three quick steps and your item is ready to sell.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 28),
                ..._steps.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _stepCard(
                      stepNumber: e.key + 1,
                      icon: e.value['icon'] as IconData,
                      title: e.value['title'] as String,
                      body: e.value['body'] as String,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amazonOrange,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardLayout(),
                      ),
                    );
                  },
                  child: const Text(
                    'Start grading',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    // "Maybe later" takes the seller directly to their History
                    // tab so they can review past evaluations instead of
                    // dropping back to the login/intro screen.
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardLayout(
                          startOnHistory: true,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Maybe later',
                    style: TextStyle(color: amazonNavy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepCard({
    required int stepNumber,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: amazonOrange,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: amazonNavy, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
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
    );
  }
}
