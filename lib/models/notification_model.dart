enum NotificationType { warning, info, critical, success }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.type,
    required this.unread,
    this.createdAt,
    this.payload,
  });

  final String id;
  final String title;
  final String description;
  final String time;
  final NotificationType type;
  final bool unread;
  final String? createdAt;
  final Map<String, dynamic>? payload;

  NotificationModel copyWith({bool? unread}) {
    return NotificationModel(
      id: id,
      title: title,
      description: description,
      time: time,
      type: type,
      unread: unread ?? this.unread,
      createdAt: createdAt,
      payload: payload,
    );
  }

  static NotificationType parseType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'warning':
        return NotificationType.warning;
      case 'critical':
        return NotificationType.critical;
      case 'success':
        return NotificationType.success;
      default:
        return NotificationType.info;
    }
  }

  factory NotificationModel.fromApiJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: '${json['id']}',
      title: json['title'] as String? ?? 'Notification',
      description: json['message'] as String? ?? '',
      time: '',
      type: parseType(json['type'] as String?),
      unread: !(json['is_read'] as bool? ?? false),
      createdAt: json['created_at'] as String?,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
    );
  }
}
