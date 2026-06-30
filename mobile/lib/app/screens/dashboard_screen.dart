import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../models/today.dart';
import '../theme.dart';
import '../widgets/metric_tile.dart';
import '../widgets/ring_gauge.dart';
import 'sleep_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final band = BandServiceScope.of(context);
    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final t = Theme.of(context);
        final c = context.appColors;
        final today = mockToday();
        final recColors = _recoveryColors(c, today.recoveryPct);
        final sleep = band.sleepSummary;
        final sleepPct = sleep != null && sleep.hasData ? sleep.score : today.sleepPct;
        final sleepDurStr = sleep != null && sleep.hasData ? sleep.durationStr : l.t('sleep_dur');
        final vitals = band.liveVitals;
        final connected = band.isConnected;
        final battery = band.deviceInfo?.batteryPercent;

        final stepsStr = vitals != null ? _formatSteps(vitals.steps) : '--';
        final hrStr = vitals?.heartRate != null ? '${vitals!.heartRate}' : '--';
        final spo2Str = vitals?.spo2 != null ? '${vitals!.spo2}' : '--';
        final tempStr = vitals?.temperatureC != null
            ? vitals!.temperatureC!.toStringAsFixed(1)
            : '--';
        final battStr = battery != null ? '$battery' : '--';

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('date'),
                        style: TextStyle(
                            color: c.subtext,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(l.t('greeting'),
                          style: t.textTheme.titleLarge?.copyWith(fontSize: 23)),
                    ],
                  ),
                ),
                if (connected && battery != null)
                  _BatteryChip(percent: battery, accent: c.accent),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF121A25),
                    border: Border.all(color: const Color(0xFF1F2C3D)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 20, color: c.subtext),
                      Positioned(
                        top: 9,
                        right: 10,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.accent,
                            border: Border.all(
                                color: const Color(0xFF121A25), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hero recovery
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1F2C3D)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF13202C), Color(0xFF0E1822)],
                ),
              ),
              child: Row(
                children: [
                  RingGauge(
                    value: today.recoveryPct.toDouble(),
                    max: 100,
                    colors: recColors,
                    size: 138,
                    strokeWidth: 14,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '${today.recoveryPct}',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF2F6FF)),
                            ),
                            TextSpan(
                              text: '%',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: c.subtext),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.t('ready'),
                          style: TextStyle(
                              color: recColors.first,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.t('recovery'),
                            style: TextStyle(
                                color: c.subtext,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 9),
                        Text(l.t('recovery_msg'),
                            style: const TextStyle(
                                color: Color(0xFFC3CEE0),
                                fontSize: 13.5,
                                height: 1.35)),
                        const SizedBox(height: 10),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: c.accent.withValues(alpha: 0.12),
                          ),
                          child: Text(l.t('vs_yesterday'),
                              style: TextStyle(
                                  color: c.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),

            // Strain + Sleep ring cards
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MiniRingCard(
                    label: l.t('strain'),
                    line1: l.t('moderate'),
                    line2: l.t('of_strain'),
                    value: today.strain,
                    max: today.strainMax,
                    valueText: today.strain.toStringAsFixed(1),
                    colors: [c.warn, c.warnEnd],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SleepScreen()),
                    ),
                    child: _MiniRingCard(
                      label: l.t('sleep'),
                      line1: sleepDurStr,
                      line2: band.isSleepSyncing ? l.t('syncing') : l.t('great'),
                      value: sleepPct.toDouble(),
                      max: 100,
                      valueText: '$sleepPct',
                      colors: [c.sleep, c.sleepEnd],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),

            // Live metrics header
            _LiveHeader(connected: connected, live: band.isLiveHrActive, l: l, c: c),
            const SizedBox(height: 10),

            // Live metric tiles — row 1: Steps | Heart Rate | SpO2
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: l.t('steps'),
                    value: stepsStr,
                    icon: Icons.directions_walk,
                    color: c.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    label: l.t('heart_rate'),
                    value: hrStr,
                    unit: vitals?.heartRate != null ? l.t('bpm') : null,
                    icon: Icons.favorite,
                    color: c.warnEnd,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    label: l.t('spo2'),
                    value: spo2Str,
                    unit: vitals?.spo2 != null ? l.t('pct') : null,
                    icon: Icons.water_drop_outlined,
                    color: const Color(0xFF5BA3FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live metric tiles — row 2: Temperature | HRV | Battery
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: l.t('temp_label'),
                    value: tempStr,
                    unit: vitals?.temperatureC != null ? l.t('celsius') : null,
                    icon: Icons.thermostat_outlined,
                    color: const Color(0xFFFF9F5A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    label: l.t('hrv'),
                    value: '${today.hrvMs}',
                    unit: l.t('ms'),
                    icon: Icons.monitor_heart_outlined,
                    color: c.accent2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    label: l.t('battery'),
                    value: battStr,
                    unit: battery != null ? l.t('pct') : null,
                    icon: Icons.battery_charging_full_outlined,
                    color: battery != null && battery < 20
                        ? c.danger
                        : c.accent,
                  ),
                ),
              ],
            ),

            // Not-connected prompt
            if (!connected) ...[
              const SizedBox(height: 16),
              _ConnectPrompt(l: l, c: c),
            ],
          ],
        );
      },
    );
  }

  static List<Color> _recoveryColors(AppColors c, int pct) {
    if (pct >= 67) return [c.accent, c.accent2];
    if (pct >= 34) return [c.warn, c.warnEnd];
    return [c.danger, c.warnEnd];
  }

  static String _formatSteps(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({
    required this.connected,
    required this.live,
    required this.l,
    required this.c,
  });

  final bool connected;
  final bool live;
  final AppLocalizations l;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (live) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent),
          ),
          const SizedBox(width: 6),
          Text(
            l.t('live'),
            style: TextStyle(
              color: c.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ] else
          Text(
            'METRICS',
            style: TextStyle(
              color: c.subtext,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
      ],
    );
  }
}

class _BatteryChip extends StatelessWidget {
  const _BatteryChip({required this.percent, required this.accent});

  final int percent;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = percent < 20 ? const Color(0xFFFF5F5F) : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            percent < 20
                ? Icons.battery_alert_outlined
                : Icons.battery_charging_full_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$percent%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  const _ConnectPrompt({required this.l, required this.c});

  final AppLocalizations l;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF101924),
        border: Border.all(color: const Color(0xFF1C2838)),
      ),
      child: Row(
        children: [
          Icon(Icons.watch_outlined, color: c.subtext, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('connect_band'),
                  style: const TextStyle(
                    color: Color(0xFFEEF3FB),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.t('connect_band_sub'),
                  style: TextStyle(color: c.subtext, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRingCard extends StatelessWidget {
  const _MiniRingCard({
    required this.label,
    required this.line1,
    required this.line2,
    required this.value,
    required this.max,
    required this.valueText,
    required this.colors,
  });

  final String label;
  final String line1;
  final String line2;
  final double value;
  final double max;
  final String valueText;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF101924),
        border: Border.all(color: const Color(0xFF1C2838)),
      ),
      child: Row(
        children: [
          RingGauge(
            value: value,
            max: max,
            colors: colors,
            size: 60,
            strokeWidth: 9,
            center: Text(
              valueText,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.first,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        color: c.subtext,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 3),
                Text(line1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFDBE3F0),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(line2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.subtext, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
