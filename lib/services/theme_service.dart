import 'package:flutter/foundation.dart';
import 'package:rapide_nforce/core/theme/app_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { dark, light }

/// Global theme state — toggling rebuilds the whole app via [ListenableBuilder].
class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const _prefsKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;

  bool get isLight => _mode == AppThemeMode.light;

  AppPalette get palette =>
      _mode == AppThemeMode.light ? AppPalette.light : AppPalette.dark;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == AppThemeMode.light.name) {
      _mode = AppThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    _mode = isLight ? AppThemeMode.dark : AppThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _mode.name);
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _mode.name);
  }
}
