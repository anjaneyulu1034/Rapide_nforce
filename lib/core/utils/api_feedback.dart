import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';

/// Shared helpers for surfacing API failures to the user.
class ApiFeedback {
  ApiFeedback._();

  static bool isPermissionDenied(ApiResult<dynamic> result) {
    return isPermissionDeniedMessage(result.message, statusCode: result.statusCode);
  }

  static String errorMessage(
    ApiResult<dynamic> result, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final message = result.message?.trim();
    if (message != null && message.isNotEmpty) {
      if (isPermissionDenied(result)) {
        return permissionDeniedMessage(message);
      }
      return message;
    }
    return fallback;
  }

  static void showError(
    ApiResult<dynamic> result, {
    String fallback = 'Something went wrong. Please try again.',
    bool toast = true,
  }) {
    if (!toast || isPermissionDenied(result)) return;
    AppToast.showError(errorMessage(result, fallback: fallback));
  }
}
