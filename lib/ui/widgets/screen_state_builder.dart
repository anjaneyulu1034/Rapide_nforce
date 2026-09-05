import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/brand_loading_indicator.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';

class ScreenStateBuilder extends StatefulWidget {
  const ScreenStateBuilder({
    super.key,
    required this.loading,
    required this.child,
    this.error,
    this.onRetry,
    this.isEmpty = false,
    this.emptyMessage = 'No data',
    this.emptyIcon = Icons.inbox_outlined,
    this.toastOnError = false,
    this.onRefresh,
  });

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final bool isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool toastOnError;
  final Widget child;

  /// Lets the error/empty states be pulled-to-refresh too — otherwise a
  /// screen with zero items (or a failed first load) has no scrollable
  /// content for `RefreshIndicator` to attach to, leaving no way to retry
  /// short of leaving and re-opening the screen.
  final Future<void> Function()? onRefresh;

  @override
  State<ScreenStateBuilder> createState() => _ScreenStateBuilderState();
}

class _ScreenStateBuilderState extends State<ScreenStateBuilder> {
  String? _lastToastedError;

  @override
  void didUpdateWidget(ScreenStateBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeToastError(widget.error);
  }

  @override
  void initState() {
    super.initState();
    _maybeToastError(widget.error);
  }

  void _maybeToastError(String? error) {
    if (!widget.toastOnError || error == null) {
      if (error == null) _lastToastedError = null;
      return;
    }
    if (isPermissionDeniedMessage(error)) return;
    if (error == _lastToastedError) return;

    _lastToastedError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppToast.showError(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: BrandLoadingIndicator());
    }

    if (widget.error != null) {
      return _refreshable(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              ApiErrorBanner(
                message: permissionDeniedMessage(widget.error),
                onRetry: widget.onRetry,
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isEmpty) {
      return _refreshable(
        ListEmptyState(message: widget.emptyMessage, icon: widget.emptyIcon),
      );
    }

    return widget.child;
  }

  Widget _refreshable(Widget content) {
    if (widget.onRefresh == null) return Center(child: content);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: widget.onRefresh!,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Center(child: content),
          ),
        ],
      ),
    );
  }
}
