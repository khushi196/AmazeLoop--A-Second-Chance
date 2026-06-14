import 'package:flutter/material.dart';
import 'constants.dart';
import 'views/login_view.dart';

class SellerTypeScreen extends StatelessWidget {
  const SellerTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                    // ─── Mascot illustration ───
                    _buildMascot(),
                    const SizedBox(height: 24),

                    // ─── Logo text ───
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(text: 'Amaze', style: TextStyle(color: amazonNavy)),
                          TextSpan(text: 'Loop', style: TextStyle(color: amazonOrange)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Title ───
                    const Text(
                      'How are you selling today?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Orange underline ───
                    Container(
                      width: 50,
                      height: 3,
                      decoration: BoxDecoration(
                        color: amazonOrange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Subtitle ───
                    Text(
                      'Choose the option that best describes how you want to sell your item.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Two seller type cards side by side ───
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _HoverableSellerCard(
                              title: 'Warehouse /\nReturn Item',
                              subtitle: 'List items from your warehouse or returned stock.',
                              icon: Icons.warehouse_outlined,
                              iconBgColor: amazonNavy,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginView(entry: LoginEntry.warehouseSell),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _HoverableSellerCard(
                              title: 'Consumer\nTrade-in',
                              subtitle: 'List items from individual trade-in or pre-owned.',
                              icon: Icons.inventory_2_outlined,
                              iconBgColor: amazonOrange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginView(entry: LoginEntry.customerSell),
                                  ),
                                );
                              },
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
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mascot — cardboard box with recycle arrows, sparkles, and leaves
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMascot() {
    return SizedBox(
      height: 100,
      width: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sparkles (decorative dots)
          Positioned(
            top: 0,
            left: 20,
            child: Icon(Icons.auto_awesome, size: 14, color: amazonOrange.withValues(alpha: 0.7)),
          ),
          Positioned(
            top: 8,
            right: 15,
            child: Icon(Icons.auto_awesome, size: 10, color: amazonOrange.withValues(alpha: 0.5)),
          ),
          // Recycle arrows above box
          Positioned(
            top: 5,
            child: Icon(Icons.sync, size: 28, color: amazonNavy),
          ),
          // Box icon (main mascot)
          Positioned(
            bottom: 0,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFE8C99B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD4A76A), width: 2),
              ),
              child: Stack(
                children: [
                  // Tape strip
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A6572),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                  ),
                  // Face - eyes
                  Positioned(
                    top: 28,
                    left: 18,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF333333),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 28,
                    right: 18,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF333333),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Face - smile
                  Positioned(
                    bottom: 16,
                    left: 22,
                    right: 22,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: const Color(0xFF333333), width: 2),
                          left: BorderSide(color: const Color(0xFF333333), width: 2),
                          right: BorderSide(color: const Color(0xFF333333), width: 2),
                        ),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Leaf on right
          Positioned(
            bottom: 20,
            right: 0,
            child: Icon(Icons.eco, size: 24, color: Colors.green.shade400),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Hoverable seller card with orange border on hover
// ─────────────────────────────────────────────────────────────────────────
class _HoverableSellerCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _HoverableSellerCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  State<_HoverableSellerCard> createState() => _HoverableSellerCardState();
}

class _HoverableSellerCardState extends State<_HoverableSellerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? amazonOrange : Colors.grey.shade300,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? amazonOrange.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: widget.iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 24, color: Colors.white),
                  ),
                  // Arrow
                  Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
