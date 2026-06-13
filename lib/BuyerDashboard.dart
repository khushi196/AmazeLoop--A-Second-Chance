import 'package:flutter/material.dart';
import 'constants.dart';
import 'MarketplaceTab.dart';
import 'PurchasesTab.dart';
import 'views/login_view.dart'; // To force login if they click Grade Item

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({Key? key}) : super(key: key);

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _views = [
    const MarketplaceTab(),
    
    // Middle tab requires them to jump back into the Seller flow
    Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "Seller Login Required",
              style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Please log in to access the AI Grading tools.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: amazonOrange),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginView()));
              },
              child: const Text("Go to Login", style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    ),
    
    const PurchasesTab(),
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
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)
                      ),
                      SizedBox(height: 4),
                      Text(
                        'A Second Chance', 
                        style: TextStyle(fontSize: 14, color: Colors.grey)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildNavItem(icon: Icons.storefront, title: 'Marketplace', index: 0),
                _buildNavItem(icon: Icons.add_box, title: 'Grade New Item', index: 1),
                _buildNavItem(icon: Icons.history, title: 'History', index: 2),
                
                const Spacer(),
                
                InkWell(
                  onTap: () {
                    Navigator.pop(context); // Goes back to Role Selection
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Row(
                      children: const [
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

  Widget _buildNavItem({required IconData icon, required String title, required int index}) {
    final bool isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
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