import 'package:flutter/material.dart';
import 'constants.dart';
import 'MarketplaceTab.dart';
import 'PurchasesTab.dart';

/// Top-level shell for buyers and guest browsers. Two tabs only —
/// the Sell / Trade-in flow lives behind the entry screen, not in this
/// dashboard.
class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({Key? key}) : super(key: key);

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  int _currentIndex = 0;
  final GlobalKey<PurchasesTabState> _purchasesKey =
      GlobalKey<PurchasesTabState>();

  late final List<Widget> _views = [
    const MarketplaceTab(),
    PurchasesTab(key: _purchasesKey),
  ];

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

                _buildNavItem(
                  icon: Icons.storefront,
                  title: 'Marketplace',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.shopping_bag_outlined,
                  title: 'My Purchases',
                  index: 1,
                ),

                const Spacer(),

                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back, color: Colors.grey),
                        SizedBox(width: 16),
                        Text(
                          'Switch Role',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _views,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final bool isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        // Refresh purchases whenever the user opens that tab so a freshly
        // reserved item appears without a manual pull-to-refresh.
        if (index == 1) {
          _purchasesKey.currentState?.reload();
        }
      },
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
