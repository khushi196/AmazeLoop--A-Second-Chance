import 'package:flutter/material.dart';
import 'constants.dart';
import 'views/dashboard_layout.dart';

class SellIntroScreen extends StatelessWidget {
  const SellIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
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
                    // ─── Logo ───
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(text: 'Amaze', style: TextStyle(color: amazonNavy)),
                          TextSpan(text: 'Loop', style: TextStyle(color: amazonOrange)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Hero section: Title + Illustration ───
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Text content
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sell or trade in your device',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Get an AI-powered valuation in minutes.\nQuick, easy, and designed for a second chance.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right: Illustration
                        Expanded(
                          flex: 2,
                          child: _buildIllustration(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // ─── How it works title ───
                    const Text(
                      'How it works',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Three step cards in a row ───
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildStepCard(
                            stepNumber: '1',
                            icon: Icons.camera_alt_outlined,
                            iconBgColor: amazonNavy,
                            badgeColor: amazonOrange,
                            badgeIcon: Icons.add,
                            title: 'Upload photos',
                            subtitle: 'Take clear photos of your device from all sides.',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
                        ),
                        Expanded(
                          child: _buildStepCard(
                            stepNumber: '2',
                            icon: Icons.memory,
                            iconBgColor: amazonOrange,
                            badgeColor: const Color(0xFF00687A),
                            badgeIcon: Icons.check,
                            title: 'AI grades condition',
                            subtitle: 'Our AI analyzes the condition and checks key factors.',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
                        ),
                        Expanded(
                          child: _buildStepCard(
                            stepNumber: '3',
                            icon: Icons.currency_rupee,
                            iconBgColor: amazonNavy,
                            badgeColor: amazonOrange,
                            badgeIcon: Icons.check,
                            title: 'Get route and value',
                            subtitle: 'Choose to Resell, Refurbish, or Recycle—get your value.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // ─── Grade item now button ───
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const DashboardLayout()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: amazonOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Grade item now',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Maybe later button ───
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DashboardLayout(startOnHistory: true),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Maybe later',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
  // Illustration: Phone dropping into box with recycle arrow and leaf
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildIllustration() {
    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sparkles
          Positioned(
            top: 0,
            left: 10,
            child: Icon(Icons.auto_awesome, size: 12, color: amazonOrange.withValues(alpha: 0.6)),
          ),
          Positioned(
            top: 10,
            right: 20,
            child: Icon(Icons.auto_awesome, size: 8, color: amazonOrange.withValues(alpha: 0.4)),
          ),
          // Recycle arrow
          Positioned(
            top: 5,
            right: 40,
            child: Icon(Icons.sync, size: 24, color: amazonNavy),
          ),
          // Phone icon (dropping)
          Positioned(
            top: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.smartphone, size: 32, color: amazonNavy),
            ),
          ),
          // Box
          Positioned(
            bottom: 0,
            child: Container(
              width: 90,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFE8C99B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD4A76A), width: 2),
              ),
              child: Stack(
                children: [
                  // Box flaps (open)
                  Positioned(
                    top: -8,
                    left: 10,
                    child: Transform.rotate(
                      angle: -0.3,
                      child: Container(
                        width: 25,
                        height: 15,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A76A),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: 10,
                    child: Transform.rotate(
                      angle: 0.3,
                      child: Container(
                        width: 25,
                        height: 15,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A76A),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  // Face - eyes
                  Positioned(
                    top: 20,
                    left: 25,
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
                    top: 20,
                    right: 25,
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
                    bottom: 18,
                    left: 30,
                    right: 30,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: const Color(0xFF333333), width: 2),
                          left: BorderSide(color: const Color(0xFF333333), width: 2),
                          right: BorderSide(color: const Color(0xFF333333), width: 2),
                        ),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Leaf on right
          Positioned(
            bottom: 25,
            right: 5,
            child: Icon(Icons.eco, size: 22, color: Colors.green.shade400),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step card with number badge, icon with mini badge, title, subtitle
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStepCard({
    required String stepNumber,
    required IconData icon,
    required Color iconBgColor,
    required Color badgeColor,
    required IconData badgeIcon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Step number badge (top left aligned)
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: amazonNavy,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stepNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Icon with mini badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconBgColor.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(icon, size: 26, color: iconBgColor),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(badgeIcon, size: 10, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          // Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
