import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/core/utils/notification_helpers.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/notification_service.dart';
import 'package:rapide_nforce/ui/widgets/notifications_panel.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    this.onNavigate,
    this.reloadKey,
  });

  final ValueChanged<AppRoute>? onNavigate;
  final Object? reloadKey;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  @override
  void didUpdateWidget(covariant NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) {
      _loadCount();
    }
  }

  Future<void> _loadCount() async {
    if (!AuthService.instance.isLoggedIn) return;
    setState(() => _loading = true);
    final result = await NotificationService.instance.fetchMergedNotifications();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _unreadCount = countUnreadNotifications(result.data ?? []);
    });
  }

  Future<void> _openPanel() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(onNavigate: widget.onNavigate),
      ),
    );
    if (mounted) _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    final badge = _unreadCount > 99 ? '99+' : '$_unreadCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _loading ? null : _openPanel,
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_outlined, size: 22),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE43D53),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              child: Text(
                badge,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
