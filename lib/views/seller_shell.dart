import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:go_router/go_router.dart';
import '../data/session.dart';

/// Seller dashboard chrome (left sidebar + top bar) that wraps the routed
/// content (`/seller/grade`, `/seller/history`, and the wizard steps). Hosting
/// the steps as routes means the browser back/forward arrows move between
/// Grade → Result → Route → Health Card and History.
class SellerShell extends StatelessWidget {
  final Widget child;
  const SellerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final onHistory = location.startsWith('/seller/history');
    final onGrade = !onHistory; // grade + its wizard steps

    return Scaffold(
      body: Row(
        children: [
          // --- Left Sidebar ---
          Container(
            width: 250,
            color: const Color(0xFF232F3E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AmazeLoop', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('A Second Chance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _navItem(context, 'Grade New Item', Icons.add_box, onGrade, '/seller/grade'),
                _navItem(context, 'History', Icons.history, onHistory, '/seller/history'),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    try {
                      await Amplify.Auth.signOut();
                    } catch (_) {}
                    Session.clear();
                    if (!context.mounted) return;
                    context.go('/');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.grey.shade400, size: 20),
                        const SizedBox(width: 16),
                        Text('Logout', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // --- Right Main Content Area ---
          Expanded(
            child: Column(
              children: [
                // Top Navigation Bar
                Container(
                  height: 64,
                  color: const Color(0xFF232F3E),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Spacer(),
                      SizedBox(
                        width: 250,
                        height: 36,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: const TextStyle(fontSize: 14),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.white70),
                        tooltip: 'History',
                        onPressed: () => context.go('/seller/history'),
                      ),
                      const SizedBox(width: 16),
                      const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFF9900), child: Icon(Icons.person, size: 18, color: Colors.white)),
                    ],
                  ),
                ),

                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, String title, IconData icon, bool isSelected, String route) {
    return InkWell(
      onTap: () => context.go(route),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF131A22) : Colors.transparent,
          border: Border(left: BorderSide(color: isSelected ? const Color(0xFFFF9900) : Colors.transparent, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFF9900) : Colors.grey.shade400, size: 20),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade400, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
