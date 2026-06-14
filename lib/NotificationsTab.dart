import 'package:flutter/material.dart';
import 'constants.dart';
import 'data/models/app_notification.dart';
import 'data/repositories/grade_repository.dart';
import 'data/session.dart';
import 'views/login_view.dart';

/// In-app notifications feed: purchase confirmations, reservation holds, and
/// reservation-expiry notices. Backed by GET /notifications.
class NotificationsTab extends StatefulWidget {
  const NotificationsTab({Key? key}) : super(key: key);

  @override
  State<NotificationsTab> createState() => NotificationsTabState();
}

class NotificationsTabState extends State<NotificationsTab> {
  final GradeRepository _repo = GradeRepository();
  Future<NotificationsResult>? _future;

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
    _future = Session.isSignedIn ? _repo.fetchNotifications() : null;
  }

  Future<void> _refresh() async {
    setState(_maybeLoad);
    if (_future != null) {
      try {
        await _future;
      } catch (_) {}
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'PURCHASE':
        return Icons.shopping_cart_checkout;
      case 'RESERVATION':
        return Icons.bookmark_added;
      case 'RESERVATION_EXPIRED':
        return Icons.schedule;
      case 'ITEM_SOLD':
        return Icons.check_circle_outline;
      case 'ITEM_RESERVED':
        return Icons.person_outline;
      case 'LISTING_RELISTED':
        return Icons.refresh;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _bgColorFor(String type) {
    switch (type) {
      case 'PURCHASE':
        return const Color(0xFF00875A); // Green
      case 'ITEM_SOLD':
        return const Color(0xFF00875A); // Green
      case 'RESERVATION':
        return amazonOrange;
      case 'ITEM_RESERVED':
        return amazonOrange;
      case 'RESERVATION_EXPIRED':
        return Colors.red.shade500;
      case 'LISTING_RELISTED':
        return amazonNavy;
      default:
        return amazonNavy;
    }
  }

  String _ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text(
          'Notifications',
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
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'Sign in to see notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Purchase and reservation updates will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
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
      child: FutureBuilder<NotificationsResult>(
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
          final notes = snapshot.data?.notifications ?? const <AppNotification>[];
          if (notes.isEmpty) {
            return _buildEmpty();
          }
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ...notes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final n = entry.value;
                        final isLast = index == notes.length - 1;
                        return _buildNotificationRow(n, isLast);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationRow(AppNotification n, bool isLast) {
    final bgColor = _bgColorFor(n.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(n.type),
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  n.body,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Time ago
          Text(
            _ago(n.createdAt),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
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
              Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 20),
              const Text(
                "You're all caught up",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Purchase and reservation updates will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
                "Couldn't load notifications",
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
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
