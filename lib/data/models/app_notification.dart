/// An in-app notification returned by GET /notifications.
class AppNotification {
  final String notificationId;
  final String type; // PURCHASE | RESERVATION | RESERVATION_EXPIRED
  final String title;
  final String body;
  final String? evaluationId;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.body,
    this.evaluationId,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      notificationId: (json['notificationId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      evaluationId: json['evaluationId'] as String?,
      read: json['read'] == true,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// Wrapper for the notifications response (list + unread count).
class NotificationsResult {
  final List<AppNotification> notifications;
  final int unreadCount;

  const NotificationsResult({
    this.notifications = const [],
    this.unreadCount = 0,
  });
}
