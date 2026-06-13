import 'package:flutter/material.dart';
import 'submit_item_view.dart';
import 'history_view.dart';

class DashboardLayout extends StatefulWidget {
  const DashboardLayout({super.key});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  int _selectedIndex = 0;
  Widget? _currentCustomView; // Holds screens like Grading Result, Routing, etc.

  // A method to swap the main content area from any child screen
  void _changeView(Widget newView) {
    setState(() {
      _currentCustomView = newView;
    });
  }

  // Navigates back to the History tab and clears any custom view
  void _goToHistory() {
    setState(() {
      _selectedIndex = 1;
      _currentCustomView = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine what to show in the main area
    Widget mainContent;
    if (_currentCustomView != null) {
      mainContent = _currentCustomView!;
    } else {
      mainContent = _selectedIndex == 0 
          ? SubmitItemView(onNavigate: _changeView, onFinishToHistory: _goToHistory) 
          : HistoryView(onNavigate: _changeView);
    }

    return Scaffold(
      body: Row(
        children: [
          // --- Left Sidebar ---
          Container(
            width: 250,
            color: const Color(0xFF232F3E), // Amazon Squid Ink
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
                _buildNavItem(0, 'Grade New Item', Icons.add_box),
                _buildNavItem(1, 'History', Icons.history),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                      IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white70), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white70), onPressed: () {}),
                      const SizedBox(width: 16),
                      const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFF9900), child: Text('EV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
                    ],
                  ),
                ),
                
                // Dynamic Page Content (This is what changes!)
                Expanded(
                  child: mainContent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index && _currentCustomView == null;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _currentCustomView = null; // Reset any custom view when clicking the sidebar
        });
      },
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