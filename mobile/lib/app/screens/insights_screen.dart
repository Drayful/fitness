import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static const _recovery = [0.59, 0.44, 0.51, 0.32, 0.39, 0.20, 0.25];
  static const _bars = [46.0, 64.0, 38.0, 72.0, 54.0, 42.0, 88.0];
  static const _barPeak = [true, true, false, true, false, false, true];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final days = [
      l.t('day_mon'), l.t('day_tue'), l.t('day_wed'), l.t('day_thu'),
      l.t('day_fri'), l.t('day_sat'), l.t('day_sun'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(l.t('trends'),
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF2F6FF),
                      letterSpacing: -0.5)),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF101924),
                border: Border.all(color: const Color(0xFF1C2838)),
              ),
              child: Row(
                children: [
                  _seg(context, l.t('week'), true),
                  _seg(context, l.t('month'), false),
                  _seg(context, l.t('year'), false),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Recovery area chart
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _caption(c, l.t('recovery')),
                  Text(l.t('avg_recovery_cap'),
                      style: TextStyle(
                          color: c.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 118,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _AreaChartPainter(points: _recovery, color: c.accent),
                ),
              ),
              const SizedBox(height: 8),
              _dayRow(days, c),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Daily strain bars
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _caption(c, l.t('daily_strain')),
                  Text(l.t('peak_cap'),
                      style: TextStyle(
                          color: c.warn,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 6 ? 0 : 9),
                        child: Container(
                          height: _bars[i],
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: _barPeak[i]
                                ? LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [c.warn, c.warnEnd])
                                : null,
                            color: _barPeak[i] ? null : const Color(0xFF26303F),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),
              _dayRow(days, c),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Summary stat cards
        Row(
          children: [
            Expanded(child: _stat(context, l.t('avg_sleep'), '7h 18m', c.sleep)),
            const SizedBox(width: 11),
            Expanded(child: _stat(context, l.t('avg_hrv'), '74 ms', c.accent2)),
          ],
        ),
      ],
    );
  }

  Widget _seg(BuildContext context, String label, bool active) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: active ? c.accent : Colors.transparent,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? const Color(0xFF06120C) : c.subtext)),
    );
  }

  Widget _caption(AppColors c, String text) => Text(text,
      style: TextStyle(
          color: c.subtext,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8));

  Widget _dayRow(List<String> days, AppColors c) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days
            .map((d) => Text(d,
                style: TextStyle(
                    color: c.subtext, fontSize: 10, fontWeight: FontWeight.w600)))
            .toList(),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF101924),
          border: Border.all(color: const Color(0xFF1C2838)),
        ),
        child: child,
      );

  Widget _stat(BuildContext context, String label, String value, Color color) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF101924),
        border: Border.all(color: const Color(0xFF1C2838)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: c.subtext, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final grid = Paint()
      ..color = const Color(0xFF1C2838)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * 0.28),
        Offset(size.width, size.height * 0.28), grid);
    canvas.drawLine(Offset(0, size.height * 0.64),
        Offset(size.width, size.height * 0.64), grid);

    final dx = size.width / (points.length - 1);
    final pts = <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset(i * dx, points[i] * size.height),
    ];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      line.lineTo(pts[i].dx, pts[i].dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    var peak = pts.first;
    for (final p in pts) {
      if (p.dy < peak.dy) peak = p;
    }
    canvas.drawCircle(peak, 4.5, Paint()..color = const Color(0xFF0A0E13));
    canvas.drawCircle(
      peak,
      4.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      old.points != points || old.color != color;
}
