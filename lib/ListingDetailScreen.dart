import 'package:flutter/material.dart';
import 'constants.dart';
import 'data/models/listing_detail.dart';
import 'data/repositories/grade_repository.dart';
import 'data/session.dart';
import 'views/login_view.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({Key? key, required this.listingId})
      : super(key: key);

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final GradeRepository _repo = GradeRepository();
  late Future<ListingDetail> _future;
  int _heroIndex = 0;
  bool _reserving = false;
  bool _reserved = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchListingDetail(widget.listingId);
  }

  Future<void> _retry() async {
    setState(() {
      _future = _repo.fetchListingDetail(widget.listingId);
    });
    await _future;
  }

  String _money(num value, String currency) {
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text('Item Detail', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<ListingDetail>(
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
          final detail = snapshot.data;
          if (detail == null) {
            return _buildError('No listing data.');
          }
          return _buildContent(detail);
        },
      ),
    );
  }

  Widget _buildContent(ListingDetail detail) {
    final l = detail.listing;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGallery(detail.images),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(l),
                    const SizedBox(height: 16),
                    _buildReturnInsights(l),
                    const SizedBox(height: 16),
                    _buildHealthCard(detail.healthCard, l.evaluationId),
                    const SizedBox(height: 24),
                    _buildBuyButton(l.evaluationId),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Gallery
  // -------------------------------------------------------------------------
  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        height: 280,
        color: Colors.white,
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
        ),
      );
    }
    final hero = images[_heroIndex.clamp(0, images.length - 1)];
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 280,
          color: Colors.white,
          child: Image.network(
            hero,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 76,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == _heroIndex;
                return GestureDetector(
                  onTap: () => setState(() => _heroIndex = i),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? amazonOrange : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Header (title, price, condition + seller pill)
  // -------------------------------------------------------------------------
  Widget _buildHeader(l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _money(l.price, l.currency),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (l.condition != null) _badge(l.condition!, _conditionColor(l.condition!)),
            _badge(
              l.sellerType == 'WAREHOUSE' ? 'Warehouse seller' : 'Customer seller',
              amazonNavy,
              icon: l.sellerType == 'WAREHOUSE' ? Icons.warehouse : Icons.person,
            ),
            _badge('AI graded', const Color(0xFF00687A), icon: Icons.verified),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Return insights
  // -------------------------------------------------------------------------
  Widget _buildReturnInsights(l) {
    final risk = l.risk;
    Color bg;
    Color border;
    Color fg;
    IconData icon;
    String headline;
    String body;

    switch (risk) {
      case 'LOW':
        bg = Colors.green.shade50;
        border = Colors.green.shade200;
        fg = Colors.green.shade800;
        icon = Icons.shield_outlined;
        headline = 'Low return rate';
        body = 'Buyers similar to you usually keep this item.';
        break;
      case 'HIGH':
        bg = Colors.red.shade50;
        border = Colors.red.shade200;
        fg = Colors.red.shade800;
        icon = Icons.warning_amber_rounded;
        final reason = (l.topReturnReason ?? 'condition concerns').toString();
        headline = 'Frequently returned';
        body = 'Mostly returned for "$reason". Please review the Health Card carefully before buying.';
        break;
      default:
        bg = Colors.amber.shade50;
        border = Colors.amber.shade200;
        fg = Colors.amber.shade900;
        icon = Icons.info_outline;
        headline = 'Typical return rate';
        body = 'Review the Health Card and details before buying.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: fg,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(color: fg, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Health Card
  // -------------------------------------------------------------------------
  Widget _buildHealthCard(HealthCard hc, String evaluationId) {
    final score = hc.conditionScore;
    final scoreLabel = score == null ? '—' : score.toStringAsFixed(2);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Orange accent bar to mirror seller HealthCard
          Container(
            height: 6,
            decoration: const BoxDecoration(
              color: amazonOrange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.health_and_safety, color: amazonNavy),
                    const SizedBox(width: 8),
                    const Text(
                      'Product Health Card',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: amazonNavy,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Score $scoreLabel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: $evaluationId',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                const Divider(height: 24),

                // Key metrics row
                Row(
                  children: [
                    Expanded(child: _metric('Condition', hc.condition ?? '—')),
                    Expanded(
                      child: _metric(
                        'Owners',
                        '${hc.owners}',
                      ),
                    ),
                    Expanded(
                      child: _metric(
                        'Warranty',
                        hc.warrantyMonthsRemaining == null || hc.warrantyMonthsRemaining == 0
                            ? '—'
                            : '${hc.warrantyMonthsRemaining} mo',
                      ),
                    ),
                    Expanded(
                      child: _metric(
                        'CO₂ saved',
                        hc.circularImpactKg == null
                            ? '—'
                            : '${hc.circularImpactKg!.toStringAsFixed(1)} kg',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Issues
                Text(
                  'Issues noted',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                if (hc.issues.isEmpty)
                  Text(
                    'No visible issues recorded.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  )
                else
                  ...hc.issues.map(
                    (issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 6, color: Colors.grey),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              issue,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if ((hc.routeReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Why this listing',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hc.routeReason!,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade800,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Buy button (wired to /purchase)
  // -------------------------------------------------------------------------
  Future<void> _handleBuy(String evaluationId) async {
    // Gate: must be a logged-in customer to reserve.
    if (!Session.isSignedIn || Session.role != 'customer') {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in as a customer to reserve this item.')),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
      );
      return;
    }

    setState(() => _reserving = true);
    try {
      final result = await _repo.reserveListing(evaluationId);
      if (!mounted) return;
      setState(() {
        _reserving = false;
        _reserved = true;
      });
      final alreadyReserved = result['alreadyReserved'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            alreadyReserved
                ? 'You already reserved this item.'
                : 'Item reserved successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _reserving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget _buildBuyButton(String evaluationId) {
    final disabled = _reserving || _reserved;
    final label = _reserved
        ? 'Reserved'
        : (_reserving ? 'Reserving…' : 'Reserve / Buy Now');
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _reserved ? Colors.grey.shade400 : amazonOrange,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: disabled ? null : () => _handleBuy(evaluationId),
        child: _reserving
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _conditionColor(String condition) {
    switch (condition) {
      case 'Like New':
        return const Color(0xFF00687A);
      case 'Good':
        return amazonOrange;
      case 'Used':
        return Colors.purple.shade700;
      case 'Damaged':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load this listing",
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
              onPressed: _retry,
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
    );
  }
}
