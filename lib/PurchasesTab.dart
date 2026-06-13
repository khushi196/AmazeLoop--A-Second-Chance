import 'package:flutter/material.dart';
import 'constants.dart';
import 'data/models/purchase.dart';
import 'data/repositories/grade_repository.dart';
import 'data/session.dart';
import 'ListingDetailScreen.dart';
import 'views/login_view.dart';

class PurchasesTab extends StatefulWidget {
  const PurchasesTab({Key? key}) : super(key: key);

  @override
  State<PurchasesTab> createState() => PurchasesTabState();
}

class PurchasesTabState extends State<PurchasesTab> {
  final GradeRepository _repo = GradeRepository();
  Future<List<Purchase>>? _future;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  /// Public entry-point so a parent (e.g. BuyerDashboard) can force a refresh
  /// when this tab becomes visible — ensures a just-reserved item shows up.
  void reload() {
    if (!mounted) return;
    setState(_maybeLoad);
  }

  void _maybeLoad() {
    if (Session.isSignedIn) {
      _future = _repo.fetchPurchases();
    } else {
      _future = null;
    }
  }

  Future<void> _refresh() async {
    setState(_maybeLoad);
    if (_future != null) {
      try {
        await _future;
      } catch (_) {
        // Errors are surfaced through the FutureBuilder error state.
      }
    }
  }

  String _formatPrice(num value, String currency) {
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${value.toStringAsFixed(0)}';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final local = d.toLocal();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return 'Ordered ${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text('My Purchases', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        actions: [
          if (Session.isSignedIn)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh',
              onPressed: _refresh,
            ),
        ],
      ),
      body: !Session.isSignedIn ? _buildLoginGate() : _buildList(),
    );
  }

  // -------------------------------------------------------------------------
  // Auth gate
  // -------------------------------------------------------------------------
  Widget _buildLoginGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Sign in to view your purchases',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Items you reserve from the marketplace will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
              style: ElevatedButton.styleFrom(
                backgroundColor: amazonOrange,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginView()),
                );
                if (mounted) setState(_maybeLoad);
              },
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // List
  // -------------------------------------------------------------------------
  Widget _buildList() {
    return RefreshIndicator(
      color: amazonOrange,
      onRefresh: _refresh,
      child: FutureBuilder<List<Purchase>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: amazonOrange),
            );
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }
          final purchases = snapshot.data ?? const <Purchase>[];
          if (purchases.isEmpty) {
            return _buildEmpty();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: purchases.length,
            itemBuilder: (_, i) => _buildCard(purchases[i]),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Card
  // -------------------------------------------------------------------------
  Widget _buildCard(Purchase p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: _thumb(p.coverImage),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (p.condition != null)
                        Text(
                          'Condition: ${p.condition}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(p.purchaseTimestamp),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      _statusPill(p.purchaseStatus),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatPrice(p.price, p.currency),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.health_and_safety_outlined, size: 16),
                  label: const Text('View Health Card'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: amazonNavy,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  onPressed: () => _viewHealthCard(p),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // View Health Card — reuses the buyer-side listing detail screen, which
  // already renders the full Product Health Card section.
  // -------------------------------------------------------------------------
  void _viewHealthCard(Purchase p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingDetailScreen(listingId: p.evaluationId),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Visual helpers
  // -------------------------------------------------------------------------
  Widget _thumb(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: const Icon(Icons.inventory_2, color: Colors.grey, size: 32),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[100],
        child: const Icon(Icons.broken_image, color: Colors.grey, size: 28),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'SOLD':
      case 'DELIVERED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'SHIPPED':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'CANCELLED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'RESERVED':
      default:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Empty / error states
  // -------------------------------------------------------------------------
  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No purchases yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse the marketplace and reserve items you want.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "Couldn't load your purchases",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: amazonOrange,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
