import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

/// Global scaffold messenger for app-wide toast messages.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

enum _ToastType { error, success, info }

/// Floating toast-style messages shown across the app.
class AppToast {
  AppToast._();

  static void showError(String message) => _show(message, _ToastType.error);

  static void showSuccess(String message) => _show(message, _ToastType.success);

  static void showInfo(String message) => _show(message, _ToastType.info);

  static void _show(String message, _ToastType type) {
    final text = message.trim();
    if (text.isEmpty) return;

    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();

    final (icon, background, foreground) = switch (type) {
      _ToastType.error => (
          Icons.error_outline_rounded,
          const Color(0xFFB91C1C),
          AppColors.white,
        ),
      _ToastType.success => (
          Icons.check_circle_outline_rounded,
          AppColors.primary,
          AppColors.white,
        ),
      _ToastType.info => (
          Icons.info_outline_rounded,
          AppColors.black,
          AppColors.white,
        ),
    };

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: type == _ToastType.error ? 4 : 3),
        content: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
