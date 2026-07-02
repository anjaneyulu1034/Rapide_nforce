import 'package:flutter/material.dart';

/// Inline API error banner — matches web red alert strips (no toast).
class ApiErrorBanner extends StatelessWidget {
  const ApiErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 20,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Friendly copy for permission-denied API responses.
String permissionDeniedMessage(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) {
    return 'You do not have permission to view this data.';
  }
  final lower = text.toLowerCase();
  if (lower.contains('insufficient permission') ||
      lower.contains('access forbidden') ||
      lower.contains('forbidden')) {
    return text;
  }
  return text;
}

bool isPermissionDeniedMessage(String? message, {int? statusCode}) {
  if (statusCode == 403) return true;
  final lower = message?.toLowerCase() ?? '';
  return lower.contains('insufficient permission') ||
      lower.contains('access forbidden') ||
      lower == 'forbidden';
}
