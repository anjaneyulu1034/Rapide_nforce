import 'package:flutter/foundation.dart';

/// Debug-only API request/response logging (visible in `flutter run` console).
class ApiLogger {
  ApiLogger._();

  static void request(String method, String url, {Map<String, dynamic>? params}) {
    if (!kDebugMode) return;
    final query = params == null || params.isEmpty
        ? ''
        : ' params=${_truncate(params.toString(), 300)}';
    debugPrint('[API] → $method $url$query');
  }

  static void response(String method, String url, int statusCode, dynamic body) {
    if (!kDebugMode) return;
    final payload = body == null ? '(empty body)' : _truncate(body.toString(), 1200);
    debugPrint('[API] ← $method $statusCode $url\n$payload');
  }

  static void failure(String method, String url, int statusCode, String message) {
    if (!kDebugMode) return;
    debugPrint('[API] ✗ $method $statusCode $url — $message');
  }

  static String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }
}
