import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rapide_nforce/ui/widgets/brand_logo.dart';

/// Web parity for `Loading.tsx` — a rotating gradient ring around the brand
/// logo. Drop-in replacement for a bare `CircularProgressIndicator` anywhere
/// the app blocks on data (post-login bootstrap, `ScreenStateBuilder`'s
/// loading state, etc.), independent of whatever background sits behind it.
class BrandLoadingIndicator extends StatefulWidget {
  const BrandLoadingIndicator({super.key, this.size = 96});

  final double size;

  @override
  State<BrandLoadingIndicator> createState() => _BrandLoadingIndicatorState();
}

class _BrandLoadingIndicatorState extends State<BrandLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: const _SpinnerRingPainter(),
            ),
          ),
          BrandLogo(height: widget.size * 0.58),
        ],
      ),
    );
  }
}

class _SpinnerRingPainter extends CustomPainter {
  const _SpinnerRingPainter();

  // Ports web's SVG ring: viewBox 100x100, r=46, strokeWidth=4,
  // strokeDasharray "92 220" — a single visible arc of length 92, radius 46,
  // so its sweep angle in radians is simply arcLength / radius.
  static const double _sweepRadians = 92 / 46;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.46;
    final strokeWidth = size.width * 0.04;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0x1A0A0A0A);
    canvas.drawCircle(center, radius, track);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFC10007), Color(0xEBC10007), Color(0xE60A0A0A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, _sweepRadians, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerRingPainter oldDelegate) => false;
}
