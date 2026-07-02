import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/services/theme_service.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final isLight = ThemeService.instance.isLight;
        return IconButton(
          tooltip: isLight ? 'Switch to dark theme' : 'Switch to light theme',
          onPressed: ThemeService.instance.toggle,
          icon: Icon(
            isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: AppColors.textPrimary,
          ),
        );
      },
    );
  }
}
