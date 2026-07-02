import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/notification_helpers.dart';
import 'package:rapide_nforce/models/notification_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.onNavigate,
  });

  final ValueChanged<AppRoute>? onNavigate;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _activeTab = 'All';
  bool _loading = true;
  List<NotificationModel> _items = [];

  bool get _showFilterTabs =>
      canViewFleetExpiryNotifications(AuthService.instance.currentUser);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final result = await NotificationService.instance.fetchMergedNotifications();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = result.data ?? [];
    });
  }

  List<NotificationModel> get _filtered {
    switch (_activeTab) {
      case 'Critical':
        return _items.where((n) => n.type == NotificationType.critical).toList();
      case 'Warnings':
        return _items.where((n) => n.type == NotificationType.warning).toList();
      case 'Info':
        return _items.where((n) => n.type == NotificationType.info).toList();
      default:
        return _items;
    }
  }

  int get _unread => countUnreadNotifications(_items);

  Future<void> _markRead(String id) async {
    setState(() {
      _items = _items
          .map((n) => n.id == id ? n.copyWith(unread: false) : n)
          .toList();
    });
    await NotificationService.instance.markAsRead(id);
  }

  Future<void> _markAllRead() async {
    setState(() {
      _items = _items.map((n) => n.copyWith(unread: false)).toList();
    });
    final result = await NotificationService.instance
        .markAllAsRead(_items.map((n) => n.id).toList());
    if (!result.isSuccess) {
      AppToast.showError(result.message ?? 'Failed to mark all as read');
      _load();
    }
  }

  void _openNotification(NotificationModel item) {
    if (item.unread) _markRead(item.id);
    final route = _routeFor(item);
    if (route != null) {
      Navigator.pop(context);
      widget.onNavigate?.call(route);
    }
  }

  AppRoute? _routeFor(NotificationModel item) {
    final p = item.payload;
    if (p == null) return null;
    final type = (p['entityType'] ?? p['entity_type'] ?? '')
        .toString()
        .toLowerCase();
    if (type == 'truck' || type == 'powerunit') return AppRoute.powerUnit;
    if (type == 'trailer') return AppRoute.myTrailers;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final unreadLabel = _unread > 99 ? '99+' : '$_unread';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
            widget.onNavigate?.call(AppRoute.dashboard);
          },
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_unread > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE43D53),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unreadLabel unread',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showFilterTabs
                        ? 'Keep track of your fleet'
                        : 'Your recent alerts and messages',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _items.isEmpty ? null : _markAllRead,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6F4FF),
                  side: const BorderSide(color: Color(0xFFBFE3FF)),
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Mark all as read'),
              ),
            ),
          ),
          if (_showFilterTabs)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTertiary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: ['All', 'Critical', 'Warnings', 'Info']
                      .map(
                        (tab) => Expanded(
                          child: _FilterTab(
                            label: tab,
                            selected: _activeTab == tab,
                            onTap: () => setState(() => _activeTab = tab),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No notifications',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final n = _filtered[i];
                              return _NotificationCard(
                                item: n,
                                onTap: () => _openNotification(n),
                                onMarkRead: () => _markRead(n.id),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF5C6B82) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onMarkRead,
  });

  final NotificationModel item;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final style = _typeStyle(item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.unread
            ? (Theme.of(context).brightness == Brightness.light
                ? const Color(0xFFF4F8FD)
                : AppColors.primary.withValues(alpha: 0.12))
            : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.unread
              ? (Theme.of(context).brightness == Brightness.light
                  ? const Color(0xFFD6E4F8)
                  : AppColors.primary.withValues(alpha: 0.25))
              : AppColors.borderLight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: style.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_outlined, color: style.fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.unread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF3B82F6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: style.tagBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: style.tagBorder),
                            ),
                            child: Text(
                              item.type.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: style.tagFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (item.unread)
                        TextButton(
                          onPressed: onMarkRead,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Mark as read',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _TypeStyle _typeStyle(NotificationType type) {
    switch (type) {
      case NotificationType.warning:
        return const _TypeStyle(
          bg: Color(0xCCFEF3C7),
          fg: Color(0xFFF59E0B),
          tagBg: Color(0xFFFFFBEB),
          tagFg: Color(0xFFD97706),
          tagBorder: Color(0xFFFDE68A),
        );
      case NotificationType.critical:
        return const _TypeStyle(
          bg: Color(0xCCFEE2E2),
          fg: Color(0xFFEF4444),
          tagBg: Color(0xFFFEF2F2),
          tagFg: Color(0xFFDC2626),
          tagBorder: Color(0xFFFECACA),
        );
      case NotificationType.success:
        return const _TypeStyle(
          bg: Color(0xCCDCFCE7),
          fg: Color(0xFF22C55E),
          tagBg: Color(0xFFF0FDF4),
          tagFg: Color(0xFF16A34A),
          tagBorder: Color(0xFFBBF7D0),
        );
      case NotificationType.info:
        return const _TypeStyle(
          bg: Color(0xCCDBEAFE),
          fg: Color(0xFF3B82F6),
          tagBg: Color(0xFFEFF6FF),
          tagFg: Color(0xFF2563EB),
          tagBorder: Color(0xFFBFDBFE),
        );
    }
  }
}

class _TypeStyle {
  const _TypeStyle({
    required this.bg,
    required this.fg,
    required this.tagBg,
    required this.tagFg,
    required this.tagBorder,
  });

  final Color bg;
  final Color fg;
  final Color tagBg;
  final Color tagFg;
  final Color tagBorder;
}

void showNotificationsScreen(
  BuildContext context, {
  ValueChanged<AppRoute>? onNavigate,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NotificationsScreen(onNavigate: onNavigate),
    ),
  );
}
