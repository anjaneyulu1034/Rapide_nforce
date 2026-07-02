import 'package:flutter/widgets.dart';

/// Small responsive helpers used by shared widgets to adapt sizes across
/// phone / tablet / web layouts.
class Responsive {
  const Responsive._();

  static bool isSmall(BuildContext c) => MediaQuery.of(c).size.width < 600;
  static bool isMedium(BuildContext c) =>
      MediaQuery.of(c).size.width >= 600 && MediaQuery.of(c).size.width < 1024;
  static bool isLarge(BuildContext c) => MediaQuery.of(c).size.width >= 1024;

  /// Scale a base size according to screen width. Keeps sizes reasonable
  /// across breakpoints.
  static double scale(BuildContext c, double base) {
    final w = MediaQuery.of(c).size.width;
    if (w >= 1400) return base * 1.25;
    if (w >= 1024) return base * 1.1;
    if (w >= 600) return base * 1.0;
    return base * 0.95;
  }
}
