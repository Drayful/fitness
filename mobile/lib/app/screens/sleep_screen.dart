import 'package:flutter/material.dart';

import '../../api/session_controller.dart';
import '../../band/sleep_model.dart';
import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Sleep screen after the YUMN design (App-04-Sleep).
///
/// Shows last night from the watch, or — when the watch is out of reach —
/// the last night saved on the server. Duration and timing are always shown;
/// the phase strip only when the stages are verified for this watch model.
/// The personal norm and the coach advice are derived from saved nights.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key, this.embedded = false});

  /// True when shown as a bottom-nav tab: no back button.
  final bool embedded;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

/// Sleep need used for debt and bedtime advice until it is personalised.
const _needMinutes = 8 * 60;

/// Saved nights needed before showing a norm or advice.
const _minNightsForAdvice = 3;

const _deepColor = Color(0xFF5D6CE6);
const _remColor = Color(0xFF8E9AF2);
const _lightColor = Color(0xFFC3C9F7);
const _awakeColor = AppTheme.outline;

class _SleepScreenState extends State<SleepScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final band = BandServiceScope.of(context);
      if (band.isConnected &&
          !band.isSleepSyncing &&
          band.sleepSummary == null) {
        band.syncSleepData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final band = BandServiceScope.of(context);
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final saved = _SavedNight.parseAll(session.savedSleepObservations);
        final summary = band.sleepSummary;
        final night = summary != null && summary.hasData
            ? _Night.fromSummary(summary)
            : saved.isNotEmpty
            ? _Night.fromSaved(saved.first)
            : null;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: widget.embedded
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppTheme.subtext,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
            title: Text(l.t('sleep_title')),
            actions: [
              if (band.isConnected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: band.isSleepSyncing
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.sync,
                            color: AppTheme.subtext,
                            size: 22,
                          ),
                          onPressed: () => band.syncSleepData(),
                        ),
                ),
            ],
          ),
          body: RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surface,
            onRefresh: () => Future.wait([
              if (band.isConnected) band.syncSleepData(),
              session.refreshSleep().catchError((_) {}),
            ]),
            child: night == null
                ? _EmptyState(
                    syncing: band.isSleepSyncing,
                    connected: band.isConnected,
                    error: band.sleepSyncError != null,
                    onRetry: band.isConnected ? band.syncSleepData : null,
                    l: l,
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: [
                      _NightHeader(night: night, saved: saved, l: l),
                      const SizedBox(height: 18),
                      if (night.summary != null &&
                          night.summary!.hasValidatedStages) ...[
                        _PhaseStrip(summary: night.summary!, l: l),
                        const SizedBox(height: 14),
                        _StageTiles(summary: night.summary!, l: l),
                      ] else
                        _InfoNote(text: l.t('sleep_stages_note')),
                      const SizedBox(height: 14),
                      _CoachCard(saved: saved, l: l),
                      ...() {
                        // Earlier nights only: drop the one shown above.
                        final history = saved
                            .where(
                              (n) =>
                                  n.end.difference(night.end).inMinutes.abs() >
                                  60,
                            )
                            .take(7)
                            .toList();
                        return history.isEmpty
                            ? const <Widget>[]
                            : [
                                const SizedBox(height: 22),
                                _History(nights: history, l: l),
                              ];
                      }(),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Data ───────────────────────────────────────────

class _SavedNight {
  const _SavedNight({
    required this.start,
    required this.end,
    required this.minutes,
    required this.validated,
  });

  final DateTime start;
  final DateTime end;
  final int minutes;
  final bool validated;

  /// Server observations, newest first; malformed rows are skipped.
  static List<_SavedNight> parseAll(List<Map<String, dynamic>> rows) {
    final nights = <_SavedNight>[];
    for (final row in rows) {
      final start = DateTime.tryParse('${row['started_at']}');
      final end = DateTime.tryParse('${row['ended_at']}');
      final minutes = (row['observed_minutes'] as num?)?.toInt();
      if (start == null || end == null || minutes == null || minutes <= 0) {
        continue;
      }
      nights.add(
        _SavedNight(
          start: start.toLocal(),
          end: end.toLocal(),
          minutes: minutes,
          validated: row['stages_validated'] == true,
        ),
      );
    }
    nights.sort((a, b) => b.end.compareTo(a.end));
    return nights;
  }
}

class _Night {
  const _Night({
    required this.start,
    required this.end,
    required this.asleepMinutes,
    required this.fromServer,
    this.summary,
  });

  factory _Night.fromSummary(SleepSummary s) => _Night(
    start: s.bedTime!,
    end: s.wakeTime!,
    asleepMinutes: s.hasValidatedStages ? s.sleepMinutes : s.observedMinutes,
    fromServer: false,
    summary: s,
  );

  factory _Night.fromSaved(_SavedNight n) => _Night(
    start: n.start,
    end: n.end,
    asleepMinutes: n.minutes,
    fromServer: true,
  );

  final DateTime start;
  final DateTime end;
  final int asleepMinutes;
  final bool fromServer;
  final SleepSummary? summary;

  int get inBedMinutes => end.difference(start).inMinutes;
}

String _fmtDur(AppLocalizations l, int minutes) => l
    .t('dur_hm')
    .replaceAll('{h}', '${minutes ~/ 60}')
    .replaceAll('{m}', '${minutes % 60}');

String _fmtHm(int minutes) =>
    '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

String _fmtClock(BuildContext context, DateTime t) => MaterialLocalizations.of(
  context,
).formatTimeOfDay(TimeOfDay.fromDateTime(t), alwaysUse24HourFormat: true);

String _fmtClockMinutes(BuildContext context, int minuteOfDay) {
  final m = ((minuteOfDay % 1440) + 1440) % 1440;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: m ~/ 60, minute: m % 60),
    alwaysUse24HourFormat: true,
  );
}

const _overline = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.9,
  color: AppTheme.subtext,
);

// ─────────────────────────── Header ─────────────────────────────────────────

class _NightHeader extends StatelessWidget {
  const _NightHeader({
    required this.night,
    required this.saved,
    required this.l,
  });

  final _Night night;
  final List<_SavedNight> saved;
  final AppLocalizations l;

  /// Personal norm: average of earlier saved nights, excluding this one.
  int? get _norm {
    final earlier = saved
        .where((n) => n.end.difference(night.end).inMinutes.abs() > 60)
        .take(14)
        .toList();
    if (earlier.length < _minNightsForAdvice) return null;
    return earlier.fold<int>(0, (s, n) => s + n.minutes) ~/ earlier.length;
  }

  @override
  Widget build(BuildContext context) {
    final summary = night.summary;
    final validated = summary != null && summary.hasValidatedStages;
    final norm = _norm;
    final delta = norm == null ? null : night.asleepMinutes - norm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                night.fromServer
                    ? l.t('sleep_saved_night')
                    : l.t('sleep_last_night'),
                style: _overline,
              ),
            ),
            if (validated)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${summary!.score}',
                      style: AppTheme.numeric(
                        fontSize: 20,
                        color: AppTheme.good,
                      ),
                    ),
                    const TextSpan(
                      text: ' / 100',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.subtext,
                      ),
                    ),
                  ],
                ),
              )
            else
              _Chip(text: l.t('sleep_stages_chip'), color: AppTheme.subtext),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _fmtDur(l, night.asleepMinutes),
          style: AppTheme.numeric(fontSize: 34),
        ),
        const SizedBox(height: 4),
        Text(
          '${_fmtClock(context, night.start)} — ${_fmtClock(context, night.end)}'
          ' · ${l.t('sleep_in_bed').replaceAll('{d}', _fmtDur(l, night.inBedMinutes))}',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        if (delta != null) ...[
          const SizedBox(height: 10),
          _Chip(
            text: l
                .t(delta >= 0 ? 'sleep_vs_norm_more' : 'sleep_vs_norm_less')
                .replaceAll('{d}', _fmtDur(l, delta.abs())),
            color: delta >= 0 ? AppTheme.good : AppTheme.warn,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────── Phases ─────────────────────────────────────────

class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip({required this.summary, required this.l});

  final SleepSummary summary;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final legend = [
      (l.t('deep_sleep'), _deepColor),
      (l.t('rem_sleep'), _remColor),
      (l.t('light_sleep'), _lightColor),
      (l.t('awake_stage'), _awakeColor),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 34,
              width: double.infinity,
              child: CustomPaint(
                painter: _PhasePainter(summary.timeline),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (label, color) in legend)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhasePainter extends CustomPainter {
  _PhasePainter(this.timeline);

  final List<SleepStage> timeline;

  static Color _color(SleepStage s) => switch (s) {
    SleepStage.deep => _deepColor,
    SleepStage.rem => _remColor,
    SleepStage.light => _lightColor,
    SleepStage.awake || SleepStage.unknown => _awakeColor,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (timeline.isEmpty) return;
    final step = size.width / timeline.length;
    var start = 0;
    // Merge runs of the same stage into one rect.
    for (var i = 1; i <= timeline.length; i++) {
      if (i < timeline.length && timeline[i] == timeline[start]) continue;
      canvas.drawRect(
        Rect.fromLTWH(start * step, 0, (i - start) * step + 0.5, size.height),
        Paint()..color = _color(timeline[start]),
      );
      start = i;
    }
  }

  @override
  bool shouldRepaint(_PhasePainter old) => old.timeline != timeline;
}

class _StageTiles extends StatelessWidget {
  const _StageTiles({required this.summary, required this.l});

  final SleepSummary summary;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, {String? unit}) => Expanded(
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _overline,
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: AppTheme.numeric(fontSize: 22),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtext,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        tile(l.t('deep_sleep'), _fmtHm(summary.deepMinutes)),
        const SizedBox(width: 10),
        tile(l.t('rem_sleep'), _fmtHm(summary.remMinutes)),
        const SizedBox(width: 10),
        tile(
          l.t('sleep_efficiency'),
          summary.efficiencyStr.replaceAll('%', ''),
          unit: summary.totalMinutes == 0 ? null : '%',
        ),
      ],
    );
  }
}

// ─────────────────────────── Coach ──────────────────────────────────────────

/// Debt and bedtime from saved nights. Needs [_minNightsForAdvice] nights in
/// the last week; otherwise explains when advice will appear.
class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.saved, required this.l});

  final List<_SavedNight> saved;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final week = saved.where((n) => n.end.isAfter(weekAgo)).toList();

    String body;
    if (week.length < _minNightsForAdvice) {
      body = l.t('sleep_coach_need');
    } else {
      final debt = week.fold<int>(
        0,
        (s, n) => s + (n.minutes < _needMinutes ? _needMinutes - n.minutes : 0),
      );
      final wake =
          week.fold<int>(0, (s, n) => s + n.end.hour * 60 + n.end.minute) ~/
          week.length;
      final bed = wake - _needMinutes;
      body = l
          .t(debt > 0 ? 'sleep_coach_debt' : 'sleep_coach_ok')
          .replaceAll('{d}', _fmtDur(l, debt))
          .replaceAll('{wake}', _fmtClockMinutes(context, wake))
          .replaceAll('{bed}', _fmtClockMinutes(context, bed));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.accentSoft,
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 15,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 7),
              Text(
                l.t('sleep_coach_title'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.text,
            ),
          ),
          if (week.length >= _minNightsForAdvice) ...[
            const SizedBox(height: 6),
            Text(
              l.t('sleep_coach_basis'),
              style: const TextStyle(fontSize: 12, color: AppTheme.subtext),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── History ────────────────────────────────────────

class _History extends StatelessWidget {
  const _History({required this.nights, required this.l});

  final List<_SavedNight> nights;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final fmt = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.t('sleep_history'), style: _overline),
        const SizedBox(height: 8),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < nights.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fmt.formatMediumDate(nights[i].end),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      Text(
                        _fmtDur(l, nights[i].minutes),
                        style: AppTheme.numeric(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: nights[i].minutes >= _needMinutes
                              ? AppTheme.good
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Shared bits ────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: child,
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.subtext),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.syncing,
    required this.connected,
    required this.error,
    required this.onRetry,
    required this.l,
  });

  final bool syncing;
  final bool connected;
  final bool error;
  final VoidCallback? onRetry;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // A ListView so pull-to-refresh works on the empty state too.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: [
        Icon(
          error ? Icons.error_outline : Icons.bedtime_outlined,
          size: 56,
          color: error ? AppTheme.danger : AppTheme.accent,
        ),
        const SizedBox(height: 18),
        Text(
          syncing
              ? l.t('syncing')
              : error
              ? l.t('sleep_sync_error')
              : l.t('no_sleep_data'),
          textAlign: TextAlign.center,
          style: AppTheme.numeric(fontSize: 20),
        ),
        const SizedBox(height: 10),
        Text(
          syncing
              ? l.t('syncing_sub')
              : connected
              ? l.t('no_sleep_sub_connected')
              : l.t('no_sleep_sub'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.subtext,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        if (error && onRetry != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton(
              onPressed: onRetry,
              child: Text(l.t('sleep_retry')),
            ),
          ),
        ],
      ],
    );
  }
}
