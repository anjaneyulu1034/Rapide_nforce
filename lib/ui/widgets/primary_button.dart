import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/responsive.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final height = Responsive.scale(context, 48);
    final spinnerSize = Responsive.scale(context, 20);
    final fontSize = Responsive.scale(context, 15);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? SizedBox(
                width: spinnerSize,
                height: spinnerSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
