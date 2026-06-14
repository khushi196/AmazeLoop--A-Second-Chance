import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:go_router/go_router.dart';
import 'constants.dart';
import 'data/session.dart';

/// Top-level shell for buyers and guest browsers. Hosts the four tab branches
/// (Marketplace / Reserved / My Purchases / Notifications) via a
/// [StatefulNavigationShell], so each tab is its own URL and the browser
/// back/forward arrows move between them. The Sell / Trade-in flow lives behind
/// the entry screen, not in this dashboard.
class BuyerDashboard extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const BuyerDashboard({super.key, required this.navigationShell});

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: Row(
        children: [
          Container(
            width: 256,
            color: amazonNavy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AmazeLoop',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'A Second Chance',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildNavItem(icon: Icons.storefront, title: 'Marketplace', index: 0),
                _buildNavItem(icon: Icons.bookmark_outline, title: 'Reserved', index: 1),
                _buildNavItem(icon: Icons.shopping_bag_outlined, title: 'My Purchases', index: 2),
                _buildNavItem(icon: Icons.notifications_none, title: 'Notifications', index: 3),

                const Spacer(),

                if (Session.isSignedIn)
                  InkWell(
                    onTap: () async {
                      try {
                        await Amplify.Auth.signOut();
                      } catch (_) {}
                      Session.clear();
                      if (!context.mounted) return;
                      context.go('/');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.grey),
                          SizedBox(width: 16),
                          Text('Logout', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () => context.go('/'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back, color: Colors.grey),
                          SizedBox(width: 16),
                          Text('Switch Role', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final bool isSelected = navigationShell.currentIndex == index;

    return InkWell(
      onTap: () => _goBranch(index),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF131A22) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? amazonOrange : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? amazonOrange : Colors.grey),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
