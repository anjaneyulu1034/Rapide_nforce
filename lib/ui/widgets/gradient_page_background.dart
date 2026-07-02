import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';

/// Full-screen red-to-black gradient used behind every page.
class GradientPageBackground extends StatelessWidget {
  const GradientPageBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.pageBackground),
      child: child,
    );
  }
}
