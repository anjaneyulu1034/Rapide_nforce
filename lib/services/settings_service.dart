import 'package:rapide_nforce/core/models/api_result.dart';

class AppSettings {
  const AppSettings({
    required this.pushNotifications,
    required this.emailAlerts,
    required this.locationTracking,
    required this.darkMode,
    required this.language,
  });

  final bool pushNotifications;
  final bool emailAlerts;
  final bool locationTracking;
  final bool darkMode;
  final String language;

  AppSettings copyWith({
    bool? pushNotifications,
    bool? emailAlerts,
    bool? locationTracking,
    bool? darkMode,
    String? language,
  }) {
    return AppSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailAlerts: emailAlerts ?? this.emailAlerts,
      locationTracking: locationTracking ?? this.locationTracking,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
    );
  }
}

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  AppSettings _settings = const AppSettings(
    pushNotifications: true,
    emailAlerts: true,
    locationTracking: true,
    darkMode: false,
    language: 'English',
  );

  Future<ApiResult<AppSettings>> fetchSettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return ApiResult.ok(_settings);
  }

  Future<ApiResult<AppSettings>> updateSettings(AppSettings settings) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _settings = settings;
    return ApiResult.ok(_settings);
  }
}
