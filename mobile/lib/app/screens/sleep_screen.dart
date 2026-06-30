import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../band/sleep_model.dart';
import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/ring_gauge.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final band = BandServiceScope.of(context);
      if (band.isConnected && !band.isSleepSyncing && band.sleepSummary == null) {
        band.syncSleepData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final band = BandServiceScope.of(context);
    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final c = context.appColors;
        final summary = band.sleepSummary;
        final syncing = band.isSleepSyncing;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E13),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0A0E13),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left, color: c.subtext, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l.t('sleep_analysis'),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF2F6FF),
              ),
            ),
            actions: [
              if (band.isConnected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: syncing
                      ? Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.accent,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.sync, color: c.subtext, size: 22),
                          onPressed: () => band.syncSleepData(),
                        ),
                ),
            ],
          ),
          body: (summary == null || !summary.hasData)
              ? _EmptyState(syncing: syncing, connected: band.isConnected, l: l, c: c)
              : _SleepContent(summary: summary, l: l, c: c),
        );
      },
    );
  }
}

// ─────────────────────────── Empty State ────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.syncing,
    required this.connected,
    required this.l,
    required this.c,
  });

  final bool syncing;
  final bool connected;
  final AppLocalizations l;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bedtime_outlined, size: 64, color: c.sleep),
            const SizedBox(height: 18),
            Text(
              syncing ? l.t('syncing') : l.t('no_sleep_data'),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF2F6FF),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              syncing
                  ? l.t('syncing_sub')
                  : connected
                      ? l.t('no_sleep_sub_connected')
                      : l.t('no_sleep_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.subtext, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Main Content ───────────────────────────────────

class _SleepContent extends StatelessWidget {
  const _SleepContent({
    required this.summary,
    required this.l,
    required this.c,
  });

  final SleepSummary summary;
  final AppLocalizations l;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        _SummaryCard(summary: summary, l: l, c: c),
        const SizedBox(height: 14),
        _HypnogramCard(summary: summary, l: l, c: c),
        const SizedBox(height: 14),
        _BreakdownCard(summary: summary, l: l, c: c),
        const SizedBox(height: 14),
        _StatsRow(summary: summary, l: l, c: c),
      ],
    );
  }
}

// ─────────────────────────── Summary Card ───────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.l, required this.c});

  final SleepSummary summary;
  final AppLocalizations l;
  final AppColors c;

  List<Color> get _scoreColors {
    final s = summary.score;
    if (s >= 85) return [c.accent, c.accent2];
    if (s >= 70) return [c.sleep, c.sleepEnd];
    if (s >= 50) return [c.warn, c.warnEnd];
    return [c.danger, c.warnEnd];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _scoreColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F2C3D)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13202C), Color(0xFF0E1822)],
        ),
      ),
      child: Row(
        children: [
          RingGauge(
            value: summary.score.toDouble(),
            max: 100,
            colors: colors,
            size: 120,
            strokeWidth: 12,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${summary.score}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF2F6FF),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.t('sleep_score'),
                  style: TextStyle(
                    color: colors.first,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('sleep_duration'),
                  style: TextStyle(
                    color: c.subtext,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.durationStr,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF2F6FF),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                if (summary.bedTime != null)
                  _timeRow(Icons.bedtime_outlined, l.t('bedtime'), summary.bedTime!),
                const SizedBox(height: 6),
                if (summary.wakeTime != null)
                  _timeRow(Icons.wb_sunny_outlined, l.t('wake_time'), summary.wakeTime!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(IconData icon, String label, DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mn = time.minute.toString().padLeft(2, '0');
    return Row(
      children: [
        Icon(icon, size: 13, color: c.subtext),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c.subtext, fontSize: 11)),
        const SizedBox(width: 8),
        Text(
          '$hh:$mn',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFDBE3F0),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Hypnogram Card ─────────────────────────────────

class _HypnogramCard extends StatelessWidget {
  const _HypnogramCard({required this.summary, required this.l, required this.c});

  final SleepSummary summary;
  final AppLocalizations l;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final stages = [
      (l.t('awake_stage'), _stageColor(SleepStage.awake)),
      (l.t('rem_sleep'), _stageColor(SleepStage.rem)),
      (l.t('light_sleep'), _stageColor(SleepStage.light)),
      (l.t('deep_sleep'), _stageColor(SleepStage.deep)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('hypnogram'),
            style: TextStyle(
              color: c.subtext,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          // Stage labels + chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Y-axis labels
              SizedBox(
                width: 48,
                height: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: stages.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        s.$1,
                        style: TextStyle(
                          color: s.$2.withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Chart
              Expanded(
                child: SizedBox(
                  height: 120,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _HypnogramPainter(timeline: summary.timeline),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // X-axis time labels
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: _TimeLabels(summary: summary, subtext: c.subtext),
          ),
        ],
      ),
    );
  }
}

Color _stageColor(SleepStage stage) => switch (stage) {
      SleepStage.deep => const Color(0xFF4A6CF7),
      SleepStage.light => const Color(0xFF9B8CFF),
      SleepStage.rem => const Color(0xFF36E0FF),
      SleepStage.awake => const Color(0xFF475569),
    };

class _TimeLabels extends StatelessWidget {
  const _TimeLabels({required this.summary, required this.subtext});

  final SleepSummary summary;
  final Color subtext;

  @override
  Widget build(BuildContext context) {
    final bed = summary.bedTime;
    if (bed == null || summary.timeline.isEmpty) return const SizedBox.shrink();

    final total = summary.timeline.length;
    const labelCount = 4;
    final labels = <String>[];
    final positions = <double>[];

    for (var i = 0; i <= labelCount; i++) {
      final frac = i / labelCount;
      final minuteOffset = (frac * total).round();
      final t = bed.add(Duration(minutes: minuteOffset));
      labels.add('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      positions.add(frac);
    }

    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        height: 14,
        child: Stack(
          children: List.generate(labels.length, (i) {
            return Positioned(
              left: positions[i] * constraints.maxWidth - 16,
              child: Text(
                labels[i],
                style: TextStyle(color: subtext, fontSize: 9, fontWeight: FontWeight.w600),
              ),
            );
          }),
        ),
      );
    });
  }
}

class _HypnogramPainter extends CustomPainter {
  const _HypnogramPainter({required this.timeline});

  final List<SleepStage> timeline;

  double _stageY(SleepStage stage, double height) => switch (stage) {
        SleepStage.awake => 0.0,
        SleepStage.rem => height * 0.33,
        SleepStage.light => height * 0.66,
        SleepStage.deep => height,
      };

  @override
  void paint(Canvas canvas, Size size) {
    if (timeline.isEmpty) return;

    final n = timeline.length;
    final dx = size.width / n;

    // Draw faint horizontal grid bands
    final gridPaint = Paint()
      ..color = const Color(0xFF1C2838)
      ..strokeWidth = 0.5;
    for (final frac in [0.0, 0.33, 0.66, 1.0]) {
      final y = frac * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw filled stage rectangles
    for (var i = 0; i < n; i++) {
      final stage = timeline[i];
      final x = i * dx;
      final y = _stageY(stage, size.height);
      canvas.drawRect(
        Rect.fromLTWH(x, y, dx + 0.5, size.height - y),
        Paint()..color = _stageColor(stage).withValues(alpha: 0.12),
      );
    }

    // Draw step-function hypnogram line
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.square;

    var i = 0;
    while (i < n) {
      // Find a run of the same stage
      final stage = timeline[i];
      var j = i;
      while (j < n && timeline[j] == stage) {
        j++;
      }
      final x0 = i * dx;
      final x1 = j * dx;
      final y = _stageY(stage, size.height);

      linePaint.color = _stageColor(stage);
      // Horizontal segment for this run
      canvas.drawLine(Offset(x0, y), Offset(x1, y), linePaint);

      // Vertical drop to next stage
      if (j < n) {
        final nextY = _stageY(timeline[j], size.height);
        // Use next stage color for the vertical
        linePaint.color = _stageColor(timeline[j]);
        canvas.drawLine(Offset(x1, y), Offset(x1, nextY), linePaint);
      }

      i = j;
    }
  }

  @override
  bool shouldRepaint(_HypnogramPainter old) => old.timeline != timeline;
}

// ─────────────────────────── Breakdown Card ─────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.summary, required this.l, required this.c});

  final SleepSummary summary;
  final AppLocalizations l;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final total = summary.totalMinutes;
    final stages = [
      (l.t('deep_sleep'), SleepStage.deep, summary.deepMinutes),
      (l.t('light_sleep'), SleepStage.light, summary.lightMinutes),
      (l.t('rem_sleep'), SleepStage.rem, summary.remMinutes),
      (l.t('awake_stage'), SleepStage.awake, summary.awakeMinutes),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('stage_breakdown'),
            style: TextStyle(
              color: c.subtext,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          ...stages.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StageRow(
                label: s.$1,
                stage: s.$2,
                minutes: s.$3,
                total: total,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.stage,
    required this.minutes,
    required this.total,
  });

  final String label;
  final SleepStage stage;
  final int minutes;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = _stageColor(stage);
    final frac = total > 0 ? minutes / total : 0.0;
    final pct = (frac * 100).round();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final durStr = h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDBE3F0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: const Color(0xFF1C2838),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            durStr,
            textAlign: TextAlign.right,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFDBE3F0),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 30,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.subtext,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Stats Row ──────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary, required this.l, required this.c});

  final SleepSummary summary;
  final AppLocalizations l;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: l.t('sleep_efficiency'),
            value: summary.efficiencyStr,
            color: c.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: l.t('total_time'),
            value: () {
              final h = summary.totalMinutes ~/ 60;
              final m = summary.totalMinutes % 60;
              return '${h}h ${m.toString().padLeft(2, '0')}m';
            }(),
            color: c.sleep,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.subtext,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Shared Decoration ──────────────────────────────

const _cardDecor = BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(20)),
  color: Color(0xFF101924),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFF1C2838))),
);
