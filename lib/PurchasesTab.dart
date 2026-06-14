import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'constants.dart';
import 'data/models/purchase.dart';
import 'data/repositories/grade_repository.dart';
import 'data/session.dart';

class PurchasesTab extends StatefulWidget {
  const PurchasesTab({super.key});

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

  void reload() {
    if (!mounted) return;
    setState(_maybeLoad);
  }

  void _maybeLoad() {
    if (Session.isSignedIn) {
      _future = _repo.fetchPurchases(status: 'SOLD');
    } else {
      _future = null;
    }
  }

  Future<void> _refresh() async {
    setState(_maybeLoad);
    if (_future != null) {
      try {
        await _future;
      } catch (_) {}
    }
  }

  String _formatPrice(num value, String currency) {
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final local = d.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Ordered ${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  Color _getConditionColor(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'like new':
        return const Color(0xFF00687A);
      case 'good':
        return const Color(0xFF00875A);
      case 'fair':
      case 'used':
        return Colors.purple.shade700;
      case 'poor':
      case 'damaged':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text(
          'My Purchases',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
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
            Text(
              'Items you buy from the marketplace will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
              style: ElevatedButton.styleFrom(
                backgroundColor: amazonOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => context.push('/login'),
            ),
          ],
        ),
      ),
    );
  }

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
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cards
                    ...purchases.map((p) => _buildCard(p)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(Purchase p) {
    final conditionColor = _getConditionColor(p.condition);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _thumb(p.coverImage),
            ),
          ),
          const SizedBox(width: 20),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  p.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Condition
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Condition: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      p.condition ?? '—',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: conditionColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status pill
                _statusPill(p.purchaseStatus),
                const SizedBox(height: 10),

                // Order date
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(p.purchaseTimestamp),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Price and action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Price
              Text(
                _formatPrice(p.price, p.currency),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 40),

              // View Health Card button
              OutlinedButton(
                onPressed: () => _viewHealthCard(p),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Health Card',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewHealthCard(Purchase p) {
    context.push('/listing/${p.evaluationId}', extra: {
      'purchaseStatus': p.purchaseStatus,
      'purchaseDate': p.purchaseTimestamp,
    });
  }

  Widget _thumb(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Icon(Icons.inventory_2, color: Colors.grey, size: 32),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[100],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'DELIVERED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
      case 'SHIPPED':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        icon = Icons.local_shipping_outlined;
        break;
      case 'SOLD':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
      case 'CANCELLED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 20),
              const Text(
                'No purchases yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Browse the marketplace and buy items you want.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 20),
              const Text(
                "Couldn't load your purchases",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: amazonOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
