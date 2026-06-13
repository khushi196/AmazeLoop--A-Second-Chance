import 'package:flutter/material.dart';
import 'constants.dart';
import 'views/login_view.dart';

/// Sits between the entry screen and login on the Sell / Trade-in path.
/// User picks whether they're an Individual seller or a Warehouse operator;
/// the choice locks the Cognito `custom:role` they'll sign up with and
/// determines the post-login destination.
class SellerTypeScreen extends StatefulWidget {
  const SellerTypeScreen({Key? key}) : super(key: key);

  @override
  State<SellerTypeScreen> createState() => _SellerTypeScreenState();
}

class _SellerTypeScreenState extends State<SellerTypeScreen> {
  String _selected = 'customer'; // matches Cognito custom:role values

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text(
          'Sell / Trade-in',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'How do you want to sell?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick the option that fits — your account role gets set accordingly.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 32),
                _buildOption(
                  value: 'customer',
                  title: 'Individual seller',
                  subtitle:
                      'I want to sell or trade in items I own personally — used phones, clothing, accessories.',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildOption(
                  value: 'warehouse',
                  title: 'Warehouse / Seller',
                  subtitle:
                      'I handle Amazon returns or inventory at scale. I want logistics-grade tools and history.',
                  icon: Icons.warehouse_outlined,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amazonOrange,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _continue,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  Widget _buildOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selected == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selected = value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? amazonOrange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: amazonOrange.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: amazonNavy.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: amazonNavy),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? amazonOrange : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _continue() {
    final entry = _selected == 'warehouse'
        ? LoginEntry.warehouseSell
        : LoginEntry.customerSell;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginView(entry: entry),
      ),
    );
  }
}
