import 'package:flutter/material.dart';
import 'constants.dart';
import 'data/models/listing.dart';
import 'data/repositories/grade_repository.dart';
import 'data/session.dart';
import 'ListingDetailScreen.dart';

class MarketplaceTab extends StatefulWidget {
  final VoidCallback? onNotificationsTap;
  const MarketplaceTab({Key? key, this.onNotificationsTap}) : super(key: key);

  @override
  State<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<MarketplaceTab> {
  final GradeRepository _repo = GradeRepository();
  static const int _pageSize = 50;
  final List<Listing> _listings = [];
  bool _loading = true; // initial load in progress
  bool _loadingMore = false; // "Load more" request in flight
  bool _hasMore = false;
  int _nextOffset = 0;
  String? _error;
  String _selectedFilter = 'All';
  final Set<String> _wishlisted = {};
  int _unreadCount = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnread();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    if (!Session.isSignedIn) return;
    try {
      final result = await _repo.fetchNotifications();
      if (mounted) setState(() => _unreadCount = result.unreadCount);
    } catch (_) {}
  }

  /// Initial load (and refresh) — resets to the first page.
  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _repo.fetchListingsPage(limit: _pageSize, offset: 0);
      if (!mounted) return;
      setState(() {
        _listings
          ..clear()
          ..addAll(page.listings);
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Appends the next page of listings.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page =
          await _repo.fetchListingsPage(limit: _pageSize, offset: _nextOffset);
      if (!mounted) return;
      setState(() {
        _listings.addAll(page.listings);
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
              'Could not load more: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    _loadUnread();
    await _load();
  }

  String _formatPrice(num value, String currency) {
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol${value.toStringAsFixed(0)}';
  }

  // User initials from email stored in userId (falls back to first 2 chars).
  String get _initials {
    final id = Session.userId ?? '';
    if (id.isEmpty) return 'G'; // guest
    return id.substring(0, 2).toUpperCase();
  }

  List<Listing> _filter(List<Listing> all) {
    var list = _selectedFilter == 'All'
        ? all
        : all.where((l) => l.condition == _selectedFilter).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((l) =>
              l.title.toLowerCase().contains(q) ||
              (l.category?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          _buildTopBar(),
          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? _buildShimmer()
                : _error != null
                    ? _buildError(_error!)
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  // ── Listings + Load more ───────────────────────────────────────────────────
  Widget _buildList() {
    final listings = _filter(_listings);
    return RefreshIndicator(
      onRefresh: _refresh,
      color: amazonOrange,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip('All'),
                          const SizedBox(width: 8),
                          _chip('Like New'),
                          const SizedBox(width: 8),
                          _chip('Good'),
                          const SizedBox(width: 8),
                          _chip('Used'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${listings.length} items found',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Featured Listings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Quality products. Second chance.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (listings.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmpty(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  childAspectRatio: 0.64,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCard(listings[index]),
                  childCount: listings.length,
                ),
              ),
            ),
          if (_hasMore && listings.isNotEmpty)
            SliverToBoxAdapter(child: _buildLoadMore()),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Center(
        child: _loadingMore
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: amazonOrange),
                ),
              )
            : OutlinedButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more, size: 20),
                label: const Text(
                  'Load more',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 64,
      color: amazonNavy,
      padding: const EdgeInsets.only(left: 4, right: 20),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search products or brands',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 16, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Refresh button
          InkWell(
            onTap: _refresh,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: const [
                  Icon(Icons.refresh, color: Colors.white70, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Refresh',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Notification bell with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none,
                    color: Colors.white70, size: 22),
                onPressed: widget.onNotificationsTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: amazonOrange,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: amazonNavy, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Avatar with initials + chevron
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade600,
                child: Text(
                  _initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white70, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  // ── Filter chip ──────────────────────────────────────────────────────────
  Widget _chip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? amazonOrange : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? amazonOrange : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: amazonOrange.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── Product card ─────────────────────────────────────────────────────────
  Widget _buildCard(Listing listing) {
    final isWishlisted = _wishlisted.contains(listing.listingId);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ListingDetailScreen(listingId: listing.listingId),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image area with AI badge overlay ────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.1,
                    child: _coverImage(listing),
                  ),
                ),
                // "AI graded" badge — bottom-left of image
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: amazonNavy.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_outlined,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'AI graded',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Card body ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + wishlist
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            if (isWishlisted) {
                              _wishlisted.remove(listing.listingId);
                            } else {
                              _wishlisted.add(listing.listingId);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, top: 2),
                            child: Icon(
                              isWishlisted
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: isWishlisted
                                  ? Colors.red
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Price in orange
                    Text(
                      _formatPrice(listing.price, listing.currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: amazonOrange,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Condition
                    if (listing.condition != null)
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 11.5),
                          children: [
                            TextSpan(
                              text: 'Condition: ',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            TextSpan(
                              text: listing.condition,
                              style: TextStyle(
                                color: _conditionColor(listing.condition),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),

                    // Seller
                    _sellerRow(listing),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seller row ───────────────────────────────────────────────────────────
  Widget _sellerRow(Listing listing) {
    final isWarehouse = listing.sellerType == 'WAREHOUSE';
    final label = isWarehouse ? 'Power Seller' : 'Verified Seller';
    final color = isWarehouse ? amazonOrange : Colors.blue.shade600;
    final icon = isWarehouse ? Icons.bolt : Icons.check_circle;

    return Row(
      children: [
        Text(
          'Seller: ',
          style:
              TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Icon(icon, size: 13, color: color),
      ],
    );
  }

  // ── Image with loading + error ───────────────────────────────────────────
  Widget _coverImage(Listing listing) {
    if (listing.coverImage == null || listing.coverImage!.isEmpty) {
      return _imgPlaceholder();
    }
    return Image.network(
      listing.coverImage!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _imgPlaceholder(loading: true);
      },
      errorBuilder: (_, __, ___) => _imgPlaceholder(),
    );
  }

  Widget _imgPlaceholder({bool loading = false}) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: amazonOrange),
              )
            : Icon(Icons.image_not_supported,
                size: 32, color: Colors.grey.shade400),
      ),
    );
  }

  // ── Condition colours ────────────────────────────────────────────────────
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

  // ── Loading shimmer ──────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              childAspectRatio: 0.64,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 12, width: 120,
                                color: Colors.grey.shade200),
                            const SizedBox(height: 8),
                            Container(height: 16, width: 80,
                                color: Colors.grey.shade200),
                            const SizedBox(height: 8),
                            Container(height: 10, width: 100,
                                color: Colors.grey.shade200),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              childCount: 8,
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty / error ────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 56,
                color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No listings yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'AI-graded items routed for resale will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
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
            Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load the marketplace",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
    );
  }
}
