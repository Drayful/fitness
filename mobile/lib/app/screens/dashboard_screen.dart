import 'package:flutter/material.dart';

import '../../api/session_controller.dart';
import '../../band/band_history.dart';
import '../../band/v8_band_service.dart';
import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/ring_gauge.dart';
import 'band_connect_screen.dart';
import 'sleep_screen.dart';

/// Home screen after the YUMN design (App-02-Home / State-01-NoBand).
///
/// The design's Energy / Recovery / Strain / Stress scores are server-side
/// formulas that do not exist yet (Spec-05: "the band has no readiness or
/// strain"). Instead of placeholder numbers the screen shows what the watch
/// really reports, plus the calibration card from App-01-Onboarding.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// Daily step target for the hero ring until goals are configurable.
  static const stepGoal = 10000;

  @override
  Widget build(BuildContext context) {
    // Rebuild on light/dark switches: AppTheme getters are not inherited.
    AppTheme.watch(context);
    final band = BandServiceScope.of(context);
    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final session = SessionScope.of(context);
        final vitals = band.liveVitals;
        final connected = band.isConnected;

        return RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          onRefresh: () => Future.wait([
            band.refresh().catchError((_) {}),
            if (session.isAuthenticated)
              session.synchronize().catchError((_) {}),
          ]),
          child: ListView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _Header(name: session.userName, l: l),
              SizedBox(height: 14),
              if (band.isSyncStale) ...[
                _StaleSyncBanner(lastSync: band.lastSyncAt!, l: l),
                SizedBox(height: 10),
              ],
              if (connected)
                _BandBanner(band: band, l: l)
              else
                _NoBandCard(band: band, l: l),
              SizedBox(height: 18),
              if (connected) ...[
                Center(child: _StepsRing(steps: vitals?.steps, l: l)),
                SizedBox(height: 14),
              ],
              _ActivityRow(band: band, session: session, l: l),
              SizedBox(height: 14),
              _MetricsGrid(band: band, l: l),
              if (session.averageHeartRate != null) ...[
                SizedBox(height: 10),
                Text(
                  '${l.t('avg_last_10_hr')}: '
                  '${session.averageHeartRate!.toStringAsFixed(0)} '
                  '${l.t('bpm')} (${session.heartRateSampleCount}/10)',
                  style: TextStyle(color: AppTheme.subtext, fontSize: 12),
                ),
              ],
              SizedBox(height: 14),
              _CalibrationCard(band: band, l: l),
            ],
          ),
        );
      },
    );
  }
}

String _fill(String template, Map<String, Object> values) {
  var out = template;
  values.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
  return out;
}

/// "today 14:05" style for today, otherwise date + time.
String _fmtWhen(BuildContext context, DateTime t) {
  final loc = MaterialLocalizations.of(context);
  final time = loc.formatTimeOfDay(
    TimeOfDay.fromDateTime(t),
    alwaysUse24HourFormat: true,
  );
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  return sameDay ? time : '${loc.formatMediumDate(t)}, $time';
}

/// Spec-06: yellow strip when the watch has not synced for three days —
/// past that the band may start overwriting history it could not hand over.
class _StaleSyncBanner extends StatelessWidget {
  const _StaleSyncBanner({required this.lastSync, required this.l});

  final DateTime lastSync;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(lastSync).inDays;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.warn.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.warn.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppTheme.warn,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              _fill(l.t('home_sync_stale'), {'d': days}),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.l});

  final String? name;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 5
        ? l.t('greet_night')
        : now.hour < 12
        ? l.t('greet_morning')
        : now.hour < 18
        ? l.t('greet_day')
        : now.hour < 23
        ? l.t('greet_evening')
        : l.t('greet_night');
    final firstName = name?.trim().split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MaterialLocalizations.of(context).formatFullDate(now),
          style: TextStyle(fontSize: 13, color: AppTheme.subtext),
        ),
        SizedBox(height: 2),
        Text(
          firstName == null || firstName.isEmpty
              ? greeting
              : '$greeting, $firstName',
          style: AppTheme.numeric(fontSize: 23),
        ),
      ],
    );
  }
}

/// Tinted status strip, the slot the design uses for its top banner.
class _BandBanner extends StatelessWidget {
  const _BandBanner({required this.band, required this.l});

  final V8BandService band;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final battery = band.deviceInfo?.batteryPercent;
    final at = band.liveVitalsAt;
    final parts = <String>[
      if (battery != null) _fill(l.t('home_band_battery'), {'n': battery}),
      if (at != null)
        DateTime.now().difference(at).inMinutes < 1
            ? l.t('home_band_updated_now')
            : _fill(l.t('home_band_updated_min'), {
                'n': DateTime.now().difference(at).inMinutes,
              }),
    ];
    final lowBattery = battery != null && battery < 20;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.accentSoft,
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            lowBattery ? Icons.battery_alert_outlined : Icons.watch_outlined,
            size: 18,
            color: lowBattery ? AppTheme.danger : AppTheme.accent,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  band.deviceInfo?.name ?? l.t('home_band_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                if (parts.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    parts.join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.subtext,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (band.isLiveHrActive)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.good,
              ),
            ),
        ],
      ),
    );
  }
}

/// State-01-NoBand: watch remembered but out of reach, or never connected.
class _NoBandCard extends StatelessWidget {
  const _NoBandCard({required this.band, required this.l});

  final V8BandService band;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final reconnecting =
        band.isAutoReconnecting ||
        band.state == BandConnectionState.connecting;
    final remembered = band.hasRememberedDevice;
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceAlt,
                ),
                child: reconnecting
                    ? Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.watch_outlined,
                        size: 20,
                        color: AppTheme.subtext,
                      ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  reconnecting
                      ? l.t('home_band_reconnecting')
                      : l.t('home_noband_title'),
                  style: AppTheme.numeric(fontSize: 17),
                ),
              ),
            ],
          ),
          if (band.lastSyncAt != null) ...[
            SizedBox(height: 10),
            Text(
              _fill(l.t('home_last_sync'), {
                'when': _fmtWhen(context, band.lastSyncAt!),
              }),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
              ),
            ),
          ],
          SizedBox(height: 10),
          Text(
            remembered ? l.t('home_noband_sub') : l.t('home_noband_none_sub'),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BandConnectScreen(service: band),
                ),
              ),
              child: Text(l.t('home_find_band')),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsRing extends StatelessWidget {
  const _StepsRing({required this.steps, required this.l});

  final int? steps;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final fmt = MaterialLocalizations.of(context);
    return RingGauge(
      value: (steps ?? 0).toDouble(),
      max: DashboardScreen.stepGoal.toDouble(),
      colors: [AppTheme.accent, AppTheme.accentBorder],
      size: 168,
      strokeWidth: 14,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            steps == null ? '—' : fmt.formatDecimal(steps!),
            style: AppTheme.numeric(fontSize: steps == null ? 40 : 30),
          ),
          SizedBox(height: 2),
          Text(
            l.t('steps'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppTheme.subtext,
            ),
          ),
          Text(
            _fill(l.t('home_steps_goal'), {
              'goal': fmt.formatDecimal(DashboardScreen.stepGoal),
            }),
            style: TextStyle(fontSize: 11, color: AppTheme.subtext),
          ),
        ],
      ),
    );
  }
}

/// Distance · calories · active time for today (TZ §20–21): live packet
/// first, then today's totals from the band memory or the server.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.band,
    required this.session,
    required this.l,
  });

  final V8BandService band;
  final SessionController session;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final live = band.liveVitals;
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    DailyActivity? stored;
    for (final d in band.dailyActivity) {
      if (isToday(d.date)) stored = d;
    }
    Map<String, dynamic>? server;
    for (final row in session.savedDailyActivity) {
      final date = DateTime.tryParse('${row['date']}');
      if (date != null && isToday(date)) server = row;
    }

    final distance =
        live?.distanceKm ??
        stored?.distanceKm ??
        ((server?['distance_m'] as num?)?.toDouble() ?? -1) / 1000;
    final calories =
        live?.caloriesKcal ??
        stored?.calories ??
        (server?['calories'] as num?)?.toDouble();
    final active =
        live?.exerciseMinutes ??
        stored?.activeMinutes ??
        (server?['active_minutes'] as num?)?.toInt();
    if ((distance < 0) && calories == null && active == null) {
      return SizedBox.shrink();
    }

    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.accent),
          SizedBox(height: 4),
          Text(value, style: AppTheme.numeric(fontSize: 17)),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.subtext),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          stat(
            Icons.route_outlined,
            distance < 0 ? '—' : distance.toStringAsFixed(2),
            l.t('act_distance_km'),
          ),
          stat(
            Icons.local_fire_department_outlined,
            calories == null ? '—' : calories.round().toString(),
            l.t('kcal'),
          ),
          stat(
            Icons.timer_outlined,
            active == null ? '—' : '$active',
            l.t('act_active_min'),
          ),
        ],
      ),
    );
  }
}

/// 2×2 tiles in the design's style: small caps label, big Manrope number.
class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.band, required this.l});

  final V8BandService band;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final v = band.liveVitals;
    final sleep = band.sleepSummary;

    String? sleepValue;
    String? sleepUnit;
    if (sleep != null && sleep.hasValidatedStages) {
      sleepValue = '${sleep.score}';
      sleepUnit = '/ 100';
    } else if (sleep != null && sleep.hasData) {
      final m = sleep.observedMinutes;
      sleepValue = '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
    }

    // Without a live reading (watch away), fall back to the last value from
    // the band's memory, then to the server's 24 h summary.
    final session = SessionScope.of(context);
    double? recorded(BodyMetric metric) {
      final fromBand = band.latestHistory(metric);
      if (fromBand != null) return fromBand.value;
      final fromServer = session.sampleSummary[metric.apiName];
      return (fromServer?['latest'] as num?)?.toDouble();
    }

    final hrRecorded = v?.heartRate == null
        ? recorded(BodyMetric.heartRate)
        : null;
    final spo2Recorded = v?.spo2 == null ? recorded(BodyMetric.spo2) : null;
    final tempRecorded = v?.temperatureC == null
        ? recorded(BodyMetric.temperature)
        : null;
    final memoryCaption = l.t('from_band_memory');

    final tiles = <Widget>[
      _Tile(
        label: l.t('heart_rate'),
        value: v?.heartRate?.toString() ?? hrRecorded?.round().toString(),
        unit: l.t('bpm'),
        color: AppTheme.accent,
        caption: hrRecorded != null ? memoryCaption : null,
      ),
      _Tile(
        label: l.t('spo2'),
        value: v?.spo2?.toString() ?? spo2Recorded?.round().toString(),
        unit: '%',
        color: AppTheme.good,
        caption: spo2Recorded != null ? memoryCaption : null,
      ),
      _Tile(
        label: l.t('sleep'),
        value: sleepValue,
        unit: sleepUnit,
        color: AppTheme.good,
        busy: band.isSleepSyncing,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SleepScreen()),
        ),
      ),
      _Tile(
        label: l.t('temp_label'),
        value:
            v?.temperatureC?.toStringAsFixed(1) ??
            tempRecorded?.toStringAsFixed(1),
        unit: '°C',
        color: AppTheme.accent,
        caption: tempRecorded != null ? memoryCaption : null,
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            SizedBox(width: 10),
            Expanded(child: tiles[1]),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: tiles[2]),
            SizedBox(width: 10),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.color,
    this.unit,
    this.busy = false,
    this.onTap,
    this.caption,
  });

  /// Shown under the value, e.g. when it comes from the band memory.
  final String? caption;
  final String label;
  final String? value;
  final String? unit;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(15, 14, 15, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                        color: AppTheme.subtext,
                      ),
                    ),
                  ),
                  if (busy)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  else if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppTheme.subtext,
                    ),
                ],
              ),
              SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value ?? '—',
                      style: AppTheme.numeric(
                        fontSize: 28,
                        color: value == null ? AppTheme.subtext : color,
                      ),
                    ),
                    if (value != null && unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.subtext,
                        ),
                      ),
                  ],
                ),
              ),
              if (caption != null) ...[
                SizedBox(height: 2),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.subtext),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// App-01-Onboarding: why scores are missing and what is already collected.
class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.band, required this.l});

  final V8BandService band;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final v = band.liveVitals;
    final sleep = band.sleepSummary;
    final rows = <(String, bool)>[
      (l.t('heart_rate'), v?.heartRate != null),
      (l.t('spo2'), v?.spo2 != null),
      (l.t('sleep'), sleep != null && sleep.hasData),
      (l.t('temp_label'), v?.temperatureC != null),
    ];

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('calib_title'), style: AppTheme.numeric(fontSize: 17)),
          SizedBox(height: 8),
          Text(
            l.t('calib_sub'),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 14),
          Text(
            l.t('calib_collected'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
              color: AppTheme.subtext,
            ),
          ),
          SizedBox(height: 6),
          for (final (label, ok) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    ok ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: ok ? AppTheme.good : AppTheme.outline,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  if (!ok)
                    Text(
                      l.t('calib_collecting'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtext,
                      ),
                    ),
                ],
              ),
            ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.accentSoft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('calib_why_title'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: AppTheme.accent,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  l.t('calib_why'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
