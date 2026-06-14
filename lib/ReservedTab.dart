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
    return '$symbol${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
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
          'Reserved',
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
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                    // Header
                    const Text(
                      'Your active reservations',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Items you\'ve reserved are shown here. Complete your purchase before the timer runs out.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cards
                    ...reserved.map((p) => _buildCard(p)),

                    // Footer note
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Having trouble? Pull down to refresh.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
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
    final expiry = p.reservationExpiresAt;
    final expired = expiry != null && expiry.toLocal().isBefore(DateTime.now());
    final isBuying = _buyingId == p.evaluationId;
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
                const SizedBox(height: 10),

                // Timer pill
                _timePill(expiry, expired),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Price and actions
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
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listingId: p.evaluationId),
                      ),
                    ),
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
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (isBuying || expired) ? null : () => _buy(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amazonOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: amazonOrange.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isBuying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Buy now',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
        _maybeLoad();
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

  Widget _timePill(DateTime? expiry, bool expired) {
    final bg = expired ? Colors.red.shade50 : amazonOrange.withValues(alpha: 0.1);
    final fg = expired ? Colors.red.shade700 : amazonOrange;
    final borderColor = expired ? Colors.red.shade200 : amazonOrange.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            _timeLeft(expiry),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
              Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 20),
              const Text(
                'No active reservations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Reserve an item from the marketplace to hold it for 24 hours.',
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
                "Couldn't load your reservations",
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
