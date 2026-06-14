import 'package:flutter/material.dart';
import 'constants.dart';
import 'data/models/listing.dart';
import 'data/models/listing_detail.dart';
import 'data/repositories/grade_repository.dart';
import 'data/session.dart';
import 'data/sustainability.dart' as sustain;
import 'views/login_view.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  /// When this screen is opened for an item the user already bought (from the
  /// My Purchases tab), these carry the purchase state so we show a purchase
  /// summary instead of Buy/Reserve actions.
  final String? purchaseStatus;
  final DateTime? purchaseDate;
  const ListingDetailScreen({
    super.key,
    required this.listingId,
    this.purchaseStatus,
    this.purchaseDate,
  });

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final GradeRepository _repo = GradeRepository();
  late Future<ListingDetail> _future;
  int _heroIndex = 0;
  bool _busy = false;
  String? _outcome;
  bool _descExpanded = false;

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
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text('Item Detail',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _retry,
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
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
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── TOP SECTION: Gallery (left) + Product Info (right) ───
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Image gallery
                    Expanded(
                      flex: 5,
                      child: _buildGallery(detail.images),
                    ),
                    const SizedBox(width: 32),
                    // Right: Product info + buttons
                    Expanded(
                      flex: 4,
                      child: _buildProductInfo(l),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── MIDDLE SECTION: Return Insights (left) + Health Card (right) ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildReturnInsights(l),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: _buildHealthCard(detail.healthCard, l.evaluationId),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── BOTTOM SECTION: Product Description ───
              _buildProductDescription(l, detail.healthCard),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Gallery with hero image + thumbnail strip
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
        ),
      );
    }
    final hero = images[_heroIndex.clamp(0, images.length - 1)];
    return Column(
      children: [
        // Hero image
        Stack(
          children: [
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  hero,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                ),
              ),
            ),
            // Expand icon
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.open_in_full, size: 16, color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Thumbnail strip with arrows
        if (images.length > 1)
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_heroIndex > 0) setState(() => _heroIndex--);
                },
                child: Icon(Icons.chevron_left, color: Colors.grey.shade600, size: 24),
              ),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ListView.separated(
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
                              child: const Icon(Icons.broken_image, size: 18, color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_heroIndex < images.length - 1) setState(() => _heroIndex++);
                },
                child: Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 24),
              ),
            ],
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Product Info (right column of top section)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProductInfo(l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          l.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // Price
        Text(
          _money(l.price, l.currency),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFFB12704),
          ),
        ),
        const SizedBox(height: 14),
        // Badges row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (l.condition != null)
              _chipBadge(l.condition!, _conditionColor(l.condition!)),
            _chipBadge(
              l.sellerType == 'WAREHOUSE' ? 'Amazon Return' : 'Trade-in',
              amazonNavy,
            ),
            _chipBadge('AI graded', const Color(0xFF00687A), icon: Icons.verified),
          ],
        ),
        const SizedBox(height: 14),
        // Listed date
        Text(
          'Listed on ${l.createdAt ?? '—'}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 24),
        // If the user already owns this item (opened from My Purchases), show
        // a purchase summary instead of the Buy Now / Reserve actions.
        if (_ownedView)
          _buildPurchasedPanel()
        else ...[
          // Buy Now button
          SizedBox(
            width: double.infinity,
            child: _buildBuyNowButton(l.evaluationId),
          ),
          const SizedBox(height: 12),
          // Reserve button
          SizedBox(
            width: double.infinity,
            child: _buildReserveButton(l.evaluationId),
          ),
        ],
      ],
    );
  }

  /// True when this screen was opened for an item the buyer already purchased.
  bool get _ownedView => widget.purchaseStatus == 'SOLD' || _outcome == 'SOLD';

  String _formatPurchaseDate(DateTime? d) {
    if (d == null) return '—';
    final local = d.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '${hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} $ampm';
  }

  Widget _buildPurchasedPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchased',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.purchaseDate != null
                      ? 'Ordered on ${_formatPurchaseDate(widget.purchaseDate)}'
                      : 'This item is in your purchases.',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyNowButton(String evaluationId) {
    if (_outcome == 'SOLD') {
      return _statusButton('Purchased', Icons.check_circle, Colors.green.shade600);
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: amazonOrange,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _busy ? null : () => _handleBuy(evaluationId),
      child: _busy
          ? const SizedBox(
              height: 22, width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : const Text(
              'Buy Now',
              style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildReserveButton(String evaluationId) {
    if (_outcome == 'RESERVED') {
      return _statusButton('Reserved (held 24h)', Icons.lock_clock, Colors.grey.shade500);
    }
    if (_outcome == 'SOLD') return const SizedBox.shrink();
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(color: Colors.grey.shade400, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _busy ? null : () => _handleReserve(evaluationId),
      child: const Text(
        'Reserve',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Return Insights card (left of middle row)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildReturnInsights(l) {
    final risk = l.risk;
    Color riskColor;
    String riskLabel;
    String riskBody;

    switch (risk) {
      case 'LOW':
        riskColor = Colors.green.shade700;
        riskLabel = 'low return risk';
        riskBody = 'AI analysis based on condition, usage patterns and similar orders.';
        break;
      case 'HIGH':
        riskColor = Colors.red.shade700;
        riskLabel = 'high return risk';
        riskBody = 'This item has been frequently returned. Review Health Card carefully.';
        break;
      default:
        riskColor = Colors.amber.shade800;
        riskLabel = 'moderate return risk';
        riskBody = 'AI analysis based on condition, usage patterns and similar orders.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: amazonNavy, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Return Insights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: textPrimary, height: 1.5),
              children: [
                const TextSpan(text: 'This item has a '),
                TextSpan(
                  text: riskLabel,
                  style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            riskBody,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Learn more',
            style: TextStyle(color: amazonOrange, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Product Health Card (right of middle row)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHealthCard(HealthCard hc, String evaluationId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: amazonOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.health_and_safety, color: amazonOrange, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Product Health Card',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Metrics rows
          _healthRow('Overall Condition', hc.condition ?? '—', _conditionColor(hc.condition ?? '')),
          const SizedBox(height: 12),
          _healthRow(
            'Functional Score',
            hc.conditionScore != null ? '${(hc.conditionScore! * 100).toInt()} / 100' : '— / 100',
            const Color(0xFF00687A),
          ),
          const SizedBox(height: 12),
          _healthRow(
            'Cosmetic Score',
            hc.conditionScore != null ? '${((hc.conditionScore! * 100) - 3).clamp(0, 100).toInt()} / 100' : '— / 100',
            const Color(0xFF00687A),
          ),
          const SizedBox(height: 12),
          _healthRow(
            'Issues Noted',
            hc.issues.isEmpty ? 'None' : '${hc.issues.length} issue(s)',
            hc.issues.isEmpty ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const Divider(height: 28),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI inspected and verified',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00687A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00687A).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 12, color: const Color(0xFF00687A)),
                    const SizedBox(width: 4),
                    Text(
                      'AI graded',
                      style: TextStyle(
                        color: const Color(0xFF00687A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _healthRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Product Description card (full width bottom)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProductDescription(Listing l, HealthCard hc) {
    final condDesc = hc.conditionReason ?? 'Fully tested and verified by AI.';
    final issues = hc.issues;
    final routeReason = hc.routeReason;
    final scorePercent = hc.conditionScore != null
        ? ((hc.conditionScore!) * 100).toStringAsFixed(0)
        : null;
    final isWarehouse = l.sellerType == 'WAREHOUSE';
    final sellerLabel = isWarehouse ? 'Power Seller' : 'Verified Seller';
    final warehouseCity = _warehouseCity(l.nearestWarehouseId);
    final listedDate = _formatListedDate(l.createdAt);
    final co2 = hc.circularImpactKg;
    final reverseKm = hc.reverseShippingAvoidedKm;
    final transportCo2 = hc.co2SavedKg;
    final isUnusedAtHome = l.topReturnReason == 'Unused at home';
    final sustainabilitySummary = sustain.buildSustainabilityImpact(
      sourceReason: l.topReturnReason ?? '',
      disposition: hc.finalDisposition ?? '',
      reverseKm: (reverseKm ?? 0).toDouble(),
      transportCo2Kg: transportCo2 ?? 0,
      reuseCo2Kg: co2 ?? 0,
      ownersTotal: hc.owners + 1,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Title ──────────────────────────────────────────────────────
          const Text(
            'Product Description',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 14),

          // ── Overview paragraph ─────────────────────────────────────────
          Text(
            _buildOverviewText(l, hc, condDesc),
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade800, height: 1.65),
          ),

          // ── Key specs chips ─────────────────────────────────────────────
          if (_descExpanded) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (l.category != null)
                _tag(Icons.category_outlined, l.category!),
              _tag(
                Icons.shield_outlined,
                l.condition ?? '—',
                color: _conditionColor(l.condition),
              ),
              if (scorePercent != null)
                _tag(Icons.analytics_outlined, 'Score $scorePercent/100'),
              _tag(
                isWarehouse ? Icons.warehouse_outlined : Icons.verified_outlined,
                sellerLabel,
                color: isWarehouse ? amazonOrange : Colors.blue.shade700,
              ),
              if (warehouseCity != null)
                _tag(Icons.location_on_outlined, 'Ships from $warehouseCity'),
            ],
          ),

          // ── AI-observed issues ─────────────────────────────────────────
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'AI-observed details',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.9),
            ),
            const SizedBox(height: 8),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        issue,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Why this listing ───────────────────────────────────────────
          if ((routeReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: amazonOrange.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 16, color: amazonOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Why this listing',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          routeReason!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontStyle: FontStyle.italic,
                              height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Sustainability block ───────────────────────────────────────
          if (co2 != null && co2 > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sustainabilitySummary,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.green.shade900,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.eco_outlined,
                          size: 18, color: Colors.green.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'By buying this refurbished item you help avoid '
                          '${co2.toStringAsFixed(1)} kg of CO₂ emissions — '
                          'equivalent to not burning ${(co2 / 2.3).toStringAsFixed(1)} L of fuel.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                  if (reverseKm != null && reverseKm > 0 && !isUnusedAtHome) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            size: 18, color: Colors.green.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Reselling locally avoids about $reverseKm km of '
                            'reverse shipping'
                            '${(transportCo2 != null && transportCo2 > 0) ? ' — roughly ${transportCo2.toStringAsFixed(1)} kg CO₂ saved in transport' : ''}. '
                            '(Approximate estimate.)',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Footer meta ───────────────────────────────────────────────
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _meta('Owners', hc.owners <= 1 ? '1 (original)' : '${hc.owners} total'),
              if (listedDate != null) _meta('Listed', listedDate),
              _meta(
                'Warranty',
                (hc.warrantyMonthsRemaining == null ||
                        hc.warrantyMonthsRemaining == 0)
                    ? 'No warranty'
                    : '${hc.warrantyMonthsRemaining} months remaining',
              ),
              _meta('Return risk', l.risk),
            ],
          ),
          ], // end _descExpanded

          // ── Read more / Show less toggle ──────────────────────────────
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _descExpanded = !_descExpanded),
            child: Row(
              children: [
                Text(
                  _descExpanded ? 'Show less' : 'Read more',
                  style: TextStyle(
                      color: amazonOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(
                  _descExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: amazonOrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _buildOverviewText(Listing l, HealthCard hc, String condDesc) {
    final cond = l.condition ?? 'refurbished';
    final condLower = cond.toLowerCase();
    final category = l.category ?? 'item';

    String intro;
    if (condLower == 'like new') {
      intro =
          'This ${l.title} is in Like New condition — '
          'it shows virtually no signs of use and functions exactly as expected from a new unit.';
    } else if (condLower == 'good') {
      intro =
          'This ${l.title} is in Good condition with only minor cosmetic wear. '
          'All features and functions are fully working.';
    } else if (condLower == 'used') {
      intro =
          'This ${l.title} is a used $category that has been '
          'AI-graded and verified. It works as intended with visible signs of prior use.';
    } else {
      intro = 'This ${l.title} has been AI-graded and is listed for sale.';
    }

    return '$intro $condDesc';
  }

  String? _warehouseCity(String? id) {
    const map = {
      'BLR': 'Bengaluru', 'MUM': 'Mumbai', 'DEL': 'Delhi',
      'HYD': 'Hyderabad', 'MAA': 'Chennai', 'PNQ': 'Pune',
    };
    return id != null ? map[id] : null;
  }

  String? _formatListedDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _tag(IconData icon, String label, {Color? color}) {
    final c = color ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 11.5, color: c, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Color _conditionColor(String? c) {
    switch (c) {
      case 'Like New':
        return const Color(0xFF00875A);
      case 'Good':
        return amazonOrange;
      case 'Used':
        return Colors.purple.shade600;
      case 'Damaged':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions (Reserve / Buy)
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> _ensureCustomer(String verb) async {
    if (Session.isSignedIn && Session.role == 'customer') return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign in as a customer to $verb this item.')),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
    );
    return false;
  }

  Future<void> _handleReserve(String evaluationId) async {
    if (!await _ensureCustomer('reserve')) return;
    setState(() => _busy = true);
    try {
      final result = await _repo.reserveListing(evaluationId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _outcome = 'RESERVED';
      });
      final already = result['alreadyReserved'] == true;
      _snack(
        already ? 'You already reserved this item.' : 'Item reserved — held for 24h.',
        Colors.green.shade700,
      );
    } on PurchaseConflictException {
      if (!mounted) return;
      setState(() => _busy = false);
      _snackRefresh('Item was just reserved by another buyer. Please refresh.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red.shade700);
    }
  }

  Future<void> _handleBuy(String evaluationId) async {
    if (!await _ensureCustomer('buy')) return;
    setState(() => _busy = true);
    try {
      await _repo.buyListing(evaluationId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _outcome = 'SOLD';
      });
      _snack('Purchase confirmed.', Colors.green.shade700);
    } on PurchaseConflictException {
      if (!mounted) return;
      setState(() => _busy = false);
      _snackRefresh('This item is no longer available — another buyer claimed it. Please refresh.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red.shade700);
    }
  }

  void _snack(String message, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: bg, content: Text(message)),
    );
  }

  /// Conflict snackbar with a Refresh action that re-fetches the listing so
  /// the buyer immediately sees the item's updated (reserved/sold) status.
  void _snackRefresh(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
          content: Text(message),
          action: SnackBarAction(
            label: 'Refresh',
            textColor: Colors.white,
            onPressed: _retry,
          ),
        ),
      );
  }

  Widget _statusButton(String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: null,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────
  Widget _chipBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
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
