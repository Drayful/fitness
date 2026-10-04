import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../api/session_controller.dart';
import '../../band/v8_band_service.dart';
import '../../band/heart_rate_zones.dart';
import '../../band/workout_model.dart';
import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.type});

  final ExerciseType type;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool _starting = true;
  bool _startFailed = false;
  bool _showSummary = false;
  WorkoutSummary? _summary;
  bool _warningDialogOpen = false;
  bool _uploaded = false;

  /// Send the finished workout to the backend exactly once, with a SnackBar
  /// confirming success or failure. Called when the summary screen appears.
  Future<void> _uploadSummary(WorkoutSummary summary) async {
    final session = SessionScope.of(context);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await session.uploadWorkout(summary);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.t('sync_ok_workout'))));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.t('sync_failed')),
          action: SnackBarAction(
            label: l.t('retry'),
            onPressed: () {
              if (mounted) _uploadSummary(summary);
            },
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final band = BandServiceScope.of(context);
      final ok = await band.startWorkout(widget.type);
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startFailed = !ok;
      });
    });
  }

  void _onBandUpdate(V8BandService band) {
    // Band ended the workout automatically (no movement / timeout).
    if (band.workoutEndedByDevice && !_showSummary) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _summary = band.workoutHistory
              .where((w) => w.startTime == band.workoutStartTime)
              .firstOrNull;
          _showSummary = true;
          band.workoutEndedByDevice = false;
        });
      });
    }

    // Inactive warning dialog.
    if (band.workoutInactiveWarning != null && !_warningDialogOpen) {
      _warningDialogOpen = true;
      final level = band.workoutInactiveWarning!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showInactiveDialog(band, level);
      });
    }
  }

  void _showInactiveDialog(V8BandService band, int level) {
    final l = AppLocalizations.of(context);
    final minutes = level == 1 ? '10' : '20';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.t('workout_still_active'),
          style: TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l.t('workout_inactive_msg').replaceFirst('%m', minutes),
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              band.clearWorkoutWarning();
              _warningDialogOpen = false;
              Navigator.of(ctx).pop();
            },
            child: Text(
              l.t('workout_continue'),
              style: TextStyle(color: widget.type.accentColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              _warningDialogOpen = false;
              final summary = await band.endWorkout();
              if (mounted) {
                setState(() {
                  _summary = summary;
                  _showSummary = true;
                });
              }
            },
            child: Text(
              l.t('workout_end'),
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmEnd(V8BandService band) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.t('workout_end_confirm'),
          style: TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l.t('workout_end_confirm_sub'),
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l.t('workout_continue'),
              style: TextStyle(color: widget.type.accentColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.t('workout_end'),
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on light/dark switches: AppTheme getters are not inherited.
    AppTheme.watch(context);
    final band = BandServiceScope.of(context);
    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        _onBandUpdate(band);
        final l = AppLocalizations.of(context);
        final accent = widget.type.accentColor;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (_showSummary) {
              Navigator.of(context).pop();
              return;
            }
            if (_startFailed || _starting) {
              Navigator.of(context).pop();
              return;
            }
            final ok = await _confirmEnd(band);
            if (ok && mounted) {
              final summary = await band.endWorkout();
              if (mounted) {
                setState(() {
                  _summary = summary;
                  _showSummary = true;
                });
              }
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.bg,
            body: SafeArea(
              child: _starting
                  ? _buildStarting(l, accent)
                  : _startFailed
                  ? _buildFailed(l, accent)
                  : _showSummary
                  ? _buildSummary(l, band)
                  : _buildActive(l, band, accent),
            ),
          ),
        );
      },
    );
  }

  // ── Loading / Failed ────────────────────────────────────────────────────────

  Widget _buildStarting(AppLocalizations l, Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.type.icon, color: accent, size: 56),
          SizedBox(height: 20),
          Text(
            l.t('workout_starting'),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed(AppLocalizations l, Color accent) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppTheme.danger, size: 56),
          SizedBox(height: 16),
          Text(
            l.t('workout_start_failed'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            l.t('workout_start_failed_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.subtext, fontSize: 14),
          ),
          SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(backgroundColor: accent),
            child: Text(
              l.t('back'),
              style: TextStyle(
                color: Color(0xFF0D1014),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Workout ──────────────────────────────────────────────────────────

  Widget _buildActive(AppLocalizations l, V8BandService band, Color accent) {
    final live = band.workoutLive;
    final paused = band.isWorkoutPaused;
    final type = widget.type;

    return Column(
      children: [
        _ActiveHeader(
          type: type,
          durationStr: live?.durationStr ?? '00:00',
          accent: accent,
          onClose: () async {
            final ok = await _confirmEnd(band);
            if (ok && mounted) {
              final summary = await band.endWorkout();
              if (mounted) {
                setState(() {
                  _summary = summary;
                  _showSummary = true;
                });
              }
            }
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: 8),
                // Hero metric: distance (for outdoor types) or duration
                if (type.showDistance)
                  _HeroMetric(
                    value: (live?.distanceM ?? 0) > 0
                        ? live!.distanceValueStr
                        : '—',
                    unit: (live?.distanceM ?? 0) > 0 ? live!.distanceUnit : '',
                    label: l.t('workout_distance'),
                    accent: accent,
                  )
                else
                  _HeroMetric(
                    value: live?.durationStr ?? '00:00',
                    unit: '',
                    label: l.t('workout_duration'),
                    accent: accent,
                  ),
                SizedBox(height: 20),
                // 2×2 stats grid
                _StatsGrid(live: live, type: type, l: l, accent: accent),
                SizedBox(height: 28),
                // Pause / Resume
                if (paused)
                  _ControlButton(
                    icon: Icons.play_arrow_rounded,
                    label: l.t('workout_resume'),
                    color: accent,
                    onTap: () => band.resumeWorkout(),
                  )
                else
                  _ControlButton(
                    icon: Icons.pause_rounded,
                    label: l.t('workout_pause'),
                    color: accent,
                    onTap: () => band.pauseWorkout(),
                  ),
                SizedBox(height: 12),
                // End
                _ControlButton(
                  icon: Icons.stop_rounded,
                  label: l.t('workout_end'),
                  color: AppTheme.danger.withValues(alpha: 0.12),
                  textColor: AppTheme.danger,
                  border: AppTheme.danger.withValues(alpha: 0.4),
                  onTap: () async {
                    final ok = await _confirmEnd(band);
                    if (ok && mounted) {
                      final summary = await band.endWorkout();
                      if (mounted) {
                        setState(() {
                          _summary = summary;
                          _showSummary = true;
                        });
                      }
                    }
                  },
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary ─────────────────────────────────────────────────────────────────

  Widget _buildSummary(AppLocalizations l, V8BandService band) {
    final s = _summary;
    final accent = widget.type.accentColor;

    // Upload to the server once, when the summary is first shown.
    if (s != null && !_uploaded) {
      _uploaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _uploadSummary(s);
      });
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: AppTheme.subtext),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                // App-06-Workout header: time window, status, sport.
                if (s != null)
                  Text(
                    '${_clock(context, s.startTime)} — ${_clock(context, s.endTime)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.subtext,
                    ),
                  ),
                SizedBox(height: 4),
                Text(
                  l.t('workout_complete'),
                  style: AppTheme.numeric(fontSize: 26),
                ),
                SizedBox(height: 4),
                Text(
                  _exerciseName(widget.type, l),
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 20),
                if (s != null) ...[
                  _SummaryCard(summary: s, l: l, accent: accent),
                ] else ...[
                  Text(
                    l.t('workout_no_data'),
                    style: TextStyle(
                      color: AppTheme.subtext,
                      fontSize: 14,
                    ),
                  ),
                ],
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l.t('workout_done'),
                      style: TextStyle(
                        color: Color(0xFF0D1014),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _clock(BuildContext context, DateTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(t),
        alwaysUse24HourFormat: true,
      );

  static String _exerciseName(ExerciseType type, AppLocalizations l) {
    return switch (type) {
      ExerciseType.run => l.t('workout_type_run'),
      ExerciseType.cycling => l.t('workout_type_cycling'),
      ExerciseType.walk => l.t('workout_type_walk'),
      ExerciseType.workout => l.t('workout_type_workout'),
      ExerciseType.yoga => l.t('workout_type_yoga'),
      ExerciseType.hiking => l.t('workout_type_hiking'),
      ExerciseType.basketball => l.t('workout_type_basketball'),
      ExerciseType.dance => l.t('workout_type_dance'),
      ExerciseType.meditation => l.t('workout_type_meditation'),
      _ => type.name,
    };
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({
    required this.type,
    required this.durationStr,
    required this.accent,
    required this.onClose,
  });

  final ExerciseType type;
  final String durationStr;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.outline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.subtext, size: 22),
            onPressed: onClose,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(type.icon, color: accent, size: 18),
                SizedBox(width: 8),
                Text(
                  _labelFor(type, l),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            durationStr,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  static String _labelFor(ExerciseType type, AppLocalizations l) {
    return switch (type) {
      ExerciseType.run => l.t('workout_type_run'),
      ExerciseType.cycling => l.t('workout_type_cycling'),
      ExerciseType.walk => l.t('workout_type_walk'),
      ExerciseType.workout => l.t('workout_type_workout'),
      ExerciseType.yoga => l.t('workout_type_yoga'),
      ExerciseType.hiking => l.t('workout_type_hiking'),
      _ => type.name,
    };
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.unit,
    required this.label,
    required this.accent,
  });

  final String value;
  final String unit;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
                height: 1,
              ),
            ),
            if (unit.isNotEmpty) ...[
              SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  unit,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: accent.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.live,
    required this.type,
    required this.l,
    required this.accent,
  });

  final WorkoutLive? live;
  final ExerciseType type;
  final AppLocalizations l;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hrStr = live != null && live!.heartRate > 0
        ? '${live!.heartRate}'
        : '--';
    final stepsStr = live?.stepsStr ?? '--';
    final calStr = live?.caloriesStr ?? '--';
    final paceStr = live?.paceStr ?? '--:--';
    final distStr = type.showDistance
        ? (live != null
              ? '${live!.distanceValueStr} ${live!.distanceUnit}'
              : '--')
        : null;
    final durStr = live?.durationStr ?? '--:--';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCell(
                value: hrStr,
                unit: live?.heartRate != null ? l.t('bpm') : '',
                label: l.t('heart_rate'),
                icon: Icons.favorite_rounded,
                color: Color(0xFFFF5F9E),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatCell(
                value: stepsStr,
                unit: '',
                label: l.t('steps'),
                icon: Icons.directions_walk,
                color: accent,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCell(
                value: calStr,
                unit: l.t('kcal'),
                label: l.t('workout_calories'),
                icon: Icons.local_fire_department_rounded,
                color: Color(0xFFFFB23E),
              ),
            ),
            SizedBox(width: 12),
            if (type.showDistance)
              Expanded(
                child: _StatCell(
                  value: paceStr,
                  unit: '/km',
                  label: l.t('workout_pace'),
                  icon: Icons.speed_rounded,
                  color: Color(0xFF9B8CFF),
                ),
              )
            else
              Expanded(
                child: _StatCell(
                  value: distStr ?? durStr,
                  unit: '',
                  label: type.showDistance
                      ? l.t('workout_distance')
                      : l.t('workout_duration'),
                  icon: Icons.timer_rounded,
                  color: Color(0xFF36E0FF),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.unit,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String unit;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.subtext,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor,
    this.border,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? textColor;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? Color(0xFF0D1014);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color,
          border: border != null ? Border.all(color: border!) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 22),
            SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Finished-workout summary after App-06-Workout: four headline tiles, the
/// heart-rate chart recorded during the session, then the remaining details.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.l,
    required this.accent,
  });

  final WorkoutSummary summary;
  final AppLocalizations l;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final live = summary.asLive;
    final samples = summary.heartRateSamples
        .where((bpm) => bpm >= 30 && bpm <= 240)
        .toList();
    final avg = summary.averageHeartRate;
    final max = summary.maxHeartRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _tile(l.t('workout_duration'), live.durationStr)),
            SizedBox(width: 10),
            Expanded(
              child: _tile(
                l.t('workout_avg_hr'),
                avg?.toString() ?? '—',
                unit: avg == null ? null : l.t('bpm'),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _tile(
                l.t('workout_max_hr'),
                max?.toString() ?? '—',
                unit: max == null ? null : l.t('bpm'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _tile(
                l.t('workout_calories'),
                live.caloriesStr,
                unit: l.t('kcal'),
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.t('workout_hr_chart'), style: _overline),
              SizedBox(height: 12),
              if (samples.length >= 2)
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _HeartRatePainter(samples, color: accent),
                  ),
                )
              else
                Text(
                  l.t('workout_hr_chart_empty'),
                  style: TextStyle(fontSize: 13, color: AppTheme.subtext),
                ),
            ],
          ),
        ),
        if (samples.isNotEmpty) ...[
          SizedBox(height: 14),
          _zonesCard(context, samples),
        ],
        SizedBox(height: 14),
        Text(l.t('workout_details'), style: _overline),
        SizedBox(height: 8),
        _card(
          Column(
            children: [
              _row(l.t('steps'), live.stepsStr),
              if (summary.type.showDistance) ...[
                _divider(),
                _row(
                  l.t('workout_distance'),
                  live.distanceM > 0
                      ? '${live.distanceValueStr} ${live.distanceUnit}'
                      : '—',
                ),
              ],
              if (summary.type.showDistance && live.distanceM >= 10) ...[
                _divider(),
                _row(l.t('workout_pace'), '${live.paceStr} /km'),
              ],
              _divider(),
              _row(
                l.t('workout_last_hr'),
                live.heartRate > 0 ? '${live.heartRate} ${l.t('bpm')}' : '—',
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ],
    );
  }

  static TextStyle get _overline => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.9,
    color: AppTheme.subtext,
  );

  /// TZ §11: time and share of the workout in each heart-rate zone.
  Widget _zonesCard(BuildContext context, List<int> samples) {
    final age = SessionScope.of(context).bodyProfile.age;
    final maxHr = HeartRateZones.maxHeartRate(age);
    final seconds = HeartRateZones.secondsInZones(
      samples,
      WorkoutSummary.heartRateSampleSeconds,
      maxHr,
    );
    final total = samples.length * WorkoutSummary.heartRateSampleSeconds;
    final lower = HeartRateZones.lowerBpm(maxHr);
    final colors = [
      AppTheme.subtext,
      AppTheme.info,
      AppTheme.good,
      AppTheme.warn,
      AppTheme.danger,
    ];
    String mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('workout_zones'), style: _overline),
          SizedBox(height: 10),
          for (var z = HeartRateZones.zoneCount - 1; z >= 0; z--)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      'Z${z + 1} · ${lower[z]}+',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : seconds[z] / total,
                        minHeight: 8,
                        color: colors[z],
                        backgroundColor: AppTheme.surfaceAlt,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 74,
                    child: Text(
                      '${mmss(seconds[z])} · '
                      '${total == 0 ? 0 : (seconds[z] * 100 / total).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: AppTheme.text),
                    ),
                  ),
                ],
              ),
            ),
          if (age == null) ...[
            SizedBox(height: 6),
            Text(
              l.t('workout_zones_no_age'),
              style: TextStyle(fontSize: 12, color: AppTheme.subtext),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(Widget child, {EdgeInsets padding = const EdgeInsets.all(15)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: child,
    );
  }

  Widget _tile(String label, String value, {String? unit}) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _overline,
          ),
          SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: AppTheme.numeric(fontSize: 24)),
                if (unit != null)
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
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: AppTheme.numeric(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1);
}

/// Heart-rate line with a faint fill and min/max guides.
class _HeartRatePainter extends CustomPainter {
  _HeartRatePainter(this.samples, {required this.color});

  final List<int> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = samples.first;
    var hi = samples.first;
    for (final v in samples) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    // Pad the range so a flat line does not sit on the border.
    final pad = ((hi - lo) * 0.15).clamp(5, 30).toDouble();
    final bottom = lo - pad;
    final range = (hi + pad) - bottom;

    final dx = size.width / (samples.length - 1);
    double y(int v) => size.height - (v - bottom) / range * size.height;

    final line = Path()..moveTo(0, y(samples.first));
    for (var i = 1; i < samples.length; i++) {
      line.lineTo(i * dx, y(samples[i]));
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final guide = Paint()
      ..color = AppTheme.outline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(hi)), Offset(size.width, y(hi)), guide);
    canvas.drawLine(Offset(0, y(lo)), Offset(size.width, y(lo)), guide);

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HeartRatePainter old) =>
      old.samples != samples || old.color != color;
}
