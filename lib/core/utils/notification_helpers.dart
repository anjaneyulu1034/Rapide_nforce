import 'package:rapide_nforce/models/notification_model.dart';
import 'package:rapide_nforce/models/user_model.dart';

bool canViewFleetExpiryNotifications(UserModel? user) {
  if (user == null) return false;
  final role = user.role.toUpperCase();
  return role.contains('SUPER') ||
      role.contains('ADMIN') ||
      role.contains('COMPANY ADMIN');
}

String notificationRelativeTime(String? value) {
  if (value == null || value.isEmpty) return 'Recently';
  final date = DateTime.tryParse(value);
  if (date == null) return 'Recently';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final signedDiff = target.difference(today).inDays;
  final diff = signedDiff.abs();

  if (diff == 0) return 'Today';
  if (signedDiff > 0) {
    return diff == 1 ? 'in 1 day' : 'in $diff days';
  }
  return diff == 1 ? '1 day ago' : '$diff days ago';
}

int notificationSortTimeMs(NotificationModel item) {
  final created = item.createdAt;
  if (created != null) {
    final parsed = DateTime.tryParse(created);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return 0;
}

List<NotificationModel> sortNotificationsNewestFirst(
  List<NotificationModel> items,
) {
  final copy = [...items];
  copy.sort(
    (a, b) => notificationSortTimeMs(b).compareTo(notificationSortTimeMs(a)),
  );
  return copy;
}

int countUnreadNotifications(List<NotificationModel> items) {
  return items.where((n) => n.unread).length;
}

bool isSyntheticNotificationId(String id) {
  return id.startsWith('doc-critical-') ||
      id.startsWith('doc-warning-') ||
      id.startsWith('vehicle-critical-') ||
      id.startsWith('vehicle-warning-');
}
