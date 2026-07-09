import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/services/theme_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';

/// Page header — bold white title on dark gradient pages.
class WebPageHeader extends StatelessWidget {
  const WebPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Gradient stat card — bronze panels with gold/orange accents.
class WebStatCard extends StatelessWidget {
  const WebStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.linkLabel,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.borderColor,
    required this.labelColor,
    required this.valueColor,
    required this.iconBg,
    required this.linkColor,
    this.onTap,
  });

  final String label;
  final String value;
  final String linkLabel;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
  final Color borderColor;
  final Color labelColor;
  final Color valueColor;
  final Color iconBg;
  final Color linkColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: valueColor,
                            letterSpacing: -0.5,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(icon, color: labelColor, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '$linkLabel →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: linkColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark bronze section card with header bar.
class WebSectionCard extends StatelessWidget {
  const WebSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppGradients.cardHeader,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Dark search field with subtle border.
class WebSearchField extends StatelessWidget {
  const WebSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search…',
    this.onClear,
    this.showClear = false,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
        suffixIcon: showClear
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Pill tab bar — dark track with gradient selected pills.
class WebTabPills extends StatelessWidget {
  const WebTabPills({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Orange-red gradient CTA button.
class WebPrimaryButton extends StatelessWidget {
  const WebPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isLight = ThemeService.instance.isLight;
    final shadowColor = isLight ? const Color(0x1F000000) : const Color(0x66FF4500);

    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: onPressed == null && !loading
                ? null
                : AppGradients.primaryButton,
            color: onPressed == null && !loading ? AppColors.textMuted : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: onPressed == null
                ? null
                : [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: expand ? 20 : 20,
            vertical: expand ? 14 : 12,
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            child: IconTheme(
              data: const IconThemeData(color: AppColors.white, size: 20),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Page body with red-black gradient background.
class WebPageBody extends StatelessWidget {
  const WebPageBody({super.key, required this.child, this.onRefresh});

  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final content = GradientPageBackground(child: child);

    if (onRefresh == null) return content;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: onRefresh!,
      child: content,
    );
  }
}

/// Standard list page — gradient background, header, optional toolbar.
class WebListPage extends StatelessWidget {
  const WebListPage({
    super.key,
    required this.title,
    this.subtitle,
    this.toolbar,
    required this.sliver,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final Widget? toolbar;
  final Widget sliver;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return WebPageBody(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: WebPageHeader(title: title, subtitle: subtitle),
          ),
          if (toolbar != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: toolbar,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            sliver: sliver,
          ),
        ],
      ),
    );
  }
}

/// Gradient pill for selected tab labels.
class WebTabPill extends StatelessWidget {
  const WebTabPill({
    super.key,
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.selectedTab : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
