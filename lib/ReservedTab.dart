import 'package:flutter/material.dart';
import 'constants.dart';
import 'data/models/purchase.dart';
import 'data/repositories/grade_repository.dart';
import 'data/session.dart';
import 'ListingDetailScreen.dart';
import 'views/login_view.dart';

/// Shows the buyer's active reservations (24h holds) with a Buy action and a
/// time-remaining indicator. Items not bought before expiry are released by
/// the backend sweep and disappear from this list.
class ReservedTab extends StatefulWidget {
  const ReservedTab({Key? key}) : super(key: key);

  @override
  State<ReservedTab> createState() => ReservedTabState();
}

class ReservedTabState extends State<ReservedTab> {
  final GradeRepository _repo = GradeRepository();
  Future<List<Purchase>>? _future;
  String? _buyingId;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  /// Public so BuyerDashboard can refresh when this tab becomes visible.
  void reload() {
    if (!mounted) return;
    setState(_maybeLoad);
  }

  void _maybeLoad() {
    _future = Session.isSignedIn
        ? _repo.fetchPurchases(status: 'RESERVED')
        : null;
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
    return '$symbol${value.toStringAsFixed(0)}';
  }

  String _timeLeft(DateTime? expiry) {
    if (expiry == null) return 'No expiry';
    final diff = expiry.toLocal().difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m left';
    return '${m}m left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text('Reserved', style: TextStyle(color: Colors.white)),
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
              'Sign in to view your reservations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
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
          final reserved = snapshot.data ?? const <Purchase>[];
          if (reserved.isEmpty) {
            return _buildEmpty();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reserved.length,
            itemBuilder: (_, i) => _buildCard(reserved[i]),
          );
        },
      ),
    );
  }

  Widget _buildCard(Purchase p) {
    final expiry = p.reservationExpiresAt;
    final expired = expiry != null && expiry.toLocal().isBefore(DateTime.now());
    final isBuying = _buyingId == p.evaluationId;

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
                      const SizedBox(height: 6),
                      _timePill(expiry, expired),
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ListingDetailScreen(listingId: p.evaluationId),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: isBuying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.shopping_cart_checkout, size: 16),
                  label: const Text('Buy now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amazonOrange,
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  onPressed: (isBuying || expired) ? null : () => _buy(p),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buy(Purchase p) async {
    setState(() => _buyingId = p.evaluationId);
    try {
      await _repo.buyListing(p.evaluationId);
      if (!mounted) return;
      setState(() {
        _buyingId = null;
        _maybeLoad(); // refresh — item leaves the reserved list
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('Purchased "${p.title}".'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _buyingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

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

  Widget _timePill(DateTime? expiry, bool expired) {
    final bg = expired ? Colors.red.shade50 : Colors.amber.shade50;
    final fg = expired ? Colors.red.shade800 : Colors.amber.shade900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            _timeLeft(expiry),
            style: TextStyle(
              color: fg,
              fontSize: 10,
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'No active reservations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reserve an item from the marketplace to hold it for 24 hours.',
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
                "Couldn't load your reservations",
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
