import 'package:flutter/material.dart';
import 'constants.dart';
import 'BuyerDashboard.dart';
import 'SellerTypeScreen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
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
                    const SizedBox(height: 8),
                    const Text(
                      'A Second Chance for Great Tech',
                      style: TextStyle(
                        fontSize: 15,
                        color: amazonNavy,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Divider ───
                    Divider(color: Colors.grey.shade300, thickness: 1),
                    const SizedBox(height: 20),

                    // ─── Subtitle ───
                    Text(
                      'Choose how you want to use AmazeLoop',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Two role cards side by side (equal size) ───
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildRoleCard(
                              index: 0,
                              title: 'Shop\nMarketplace',
                              subtitle: 'Browse and buy quality pre-owned tech',
                              icon: Icons.shopping_cart_outlined,
                              iconBgColor: amazonNavy,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const BuyerDashboard()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRoleCard(
                              index: 1,
                              title: 'Sell /\nTrade-in',
                              subtitle: 'Sell or trade in your used tech',
                              icon: Icons.inventory_2_outlined,
                              iconBgColor: amazonOrange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SellerTypeScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ─── Trust badges ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 18, color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Text(
                          'Secure',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 16),
                        Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(width: 16),
                        Text(
                          'Transparent',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 16),
                        Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(width: 16),
                        Text(
                          'Trusted',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
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

  // ─────────────────────────────────────────────────────────────────────────
  // Role card — white card with circular icon, title, subtitle, arrow
  // Border highlights on hover
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRoleCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return _HoverableRoleCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconBgColor: iconBgColor,
      onTap: onTap,
    );
  }
}

class _HoverableRoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _HoverableRoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  State<_HoverableRoleCard> createState() => _HoverableRoleCardState();
}

class _HoverableRoleCardState extends State<_HoverableRoleCard> {
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
