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

  /// Public so BuyerDashboard can refresh when this tab becomes visible.
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
        return Icons.check_circle;
      case 'RESERVATION':
        return Icons.bookmark_added;
      case 'RESERVATION_EXPIRED':
        return Icons.timer_off;
      case 'ITEM_SOLD':
        return Icons.sell;
      case 'ITEM_RESERVED':
        return Icons.bookmark_outline;
      case 'LISTING_RELISTED':
        return Icons.refresh;
      default:
        return Icons.notifications;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'PURCHASE':
      case 'ITEM_SOLD':
        return Colors.green.shade700;
      case 'RESERVATION':
      case 'ITEM_RESERVED':
        return amazonOrange;
      case 'RESERVATION_EXPIRED':
        return Colors.red.shade700;
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
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
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
            Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Sign in to see notifications',
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
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildCard(notes[i]),
          );
        },
      ),
    );
  }

  Widget _buildCard(AppNotification n) {
    final color = _colorFor(n.type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(n.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _ago(n.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.body,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
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
              Icon(Icons.notifications_none, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "You're all caught up",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Purchase and reservation updates will show up here.',
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
                "Couldn't load notifications",
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
