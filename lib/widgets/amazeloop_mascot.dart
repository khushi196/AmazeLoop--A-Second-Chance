import 'package:flutter/material.dart';
import '../constants.dart';

/// The AmazeLoop mascot — a friendly cardboard box with recycle arrows,
/// sparkles, and a leaf. Shared by the entry screens (role selection, seller
/// type, login) so the illustration lives in exactly one place.
///
/// Purely presentational and stateless; rendering is identical to the previous
/// per-screen `_buildMascot()` copies it replaced.
class AmazeLoopMascot extends StatelessWidget {
  const AmazeLoopMascot({super.key});

  @override
  Widget build(BuildContext context) {
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
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: amazonOrange.withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            top: 8,
            right: 15,
            child: Icon(
              Icons.auto_awesome,
              size: 10,
              color: amazonOrange.withValues(alpha: 0.5),
            ),
          ),
          // Recycle arrows above box
          const Positioned(
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
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
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
                          bottom: BorderSide(
                            color: const Color(0xFF333333),
                            width: 2,
                          ),
                          left: BorderSide(
                            color: const Color(0xFF333333),
                            width: 2,
                          ),
                          right: BorderSide(
                            color: const Color(0xFF333333),
                            width: 2,
                          ),
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
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
