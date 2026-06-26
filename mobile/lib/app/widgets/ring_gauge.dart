import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A circular progress ring with a sweep-gradient stroke + soft glow.
/// Put any widget in [center] (big number, label, etc).
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.value,
    required this.max,
    required this.colors,
    this.size = 148,
    this.strokeWidth = 15,
    this.center,
    this.trackColor = const Color(0xFF1C2838),
  });

  final double value;
  final double max;
  final List<Color> colors;
  final double size;
  final double strokeWidth;
  final Widget? center;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final pct = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              pct: pct,
              colors: colors.length >= 2 ? colors : [colors.first, colors.first],
              strokeWidth: strokeWidth,
              trackColor: trackColor,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.pct,
    required this.colors,
    required this.strokeWidth,
    required this.trackColor,
  });

  final double pct;
  final List<Color> colors;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;
    final sweep = math.pi * 2 * pct;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, start, math.pi * 2, false, track);

    if (pct <= 0) return;

    final shader = SweepGradient(
      startAngle: 0,
      endAngle: sweep,
      colors: colors,
      transform: const GradientRotation(start),
    ).createShader(rect);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round
      ..shader = shader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawArc(rect, start, sweep, false, glow);

    final prog = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawArc(rect, start, sweep, false, prog);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.colors != colors || old.strokeWidth != strokeWidth;
}
