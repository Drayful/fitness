import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../band/v8_band_service.dart';
import '../../band/workout_model.dart';
import '../../main.dart';
import '../l10n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
          _summary = band.workoutHistory.firstOrNull;
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
        backgroundColor: const Color(0xFF13202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.t('workout_still_active'),
          style: const TextStyle(
              color: Color(0xFFF2F6FF), fontWeight: FontWeight.w700),
        ),
        content: Text(
          l.t('workout_inactive_msg').replaceFirst('%m', minutes),
          style: const TextStyle(color: Color(0xFF9FB0CC), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              band.clearWorkoutWarning();
              _warningDialogOpen = false;
              Navigator.of(ctx).pop();
            },
            child: Text(l.t('workout_continue'),
                style: TextStyle(color: widget.type.accentColor)),
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
            child: Text(l.t('workout_end'),
                style: const TextStyle(color: Color(0xFFFF5F5F))),
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
        backgroundColor: const Color(0xFF13202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.t('workout_end_confirm'),
            style: const TextStyle(
                color: Color(0xFFF2F6FF), fontWeight: FontWeight.w700)),
        content: Text(l.t('workout_end_confirm_sub'),
            style: const TextStyle(color: Color(0xFF9FB0CC))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.t('workout_continue'),
                style: TextStyle(color: widget.type.accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.t('workout_end'),
                style: const TextStyle(color: Color(0xFFFF5F5F))),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: const Color(0xFF090F17),
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
          const SizedBox(height: 20),
          Text(l.t('workout_starting'),
              style: const TextStyle(
                  color: Color(0xFFDBE3F0),
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 3, valueColor: AlwaysStoppedAnimation(accent))),
        ],
      ),
    );
  }

  Widget _buildFailed(AppLocalizations l, Color accent) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5F5F), size: 56),
          const SizedBox(height: 16),
          Text(l.t('workout_start_failed'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFDBE3F0),
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(l.t('workout_start_failed_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7E96), fontSize: 14)),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(backgroundColor: accent),
            child: Text(l.t('back'),
                style: const TextStyle(
                    color: Color(0xFF090F17), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Active Workout ──────────────────────────────────────────────────────────

  Widget _buildActive(
      AppLocalizations l, V8BandService band, Color accent) {
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Hero metric: distance (for outdoor types) or duration
                if (type.showDistance)
                  _HeroMetric(
                    value: live?.distanceValueStr ?? '0.00',
                    unit: live?.distanceUnit ?? 'km',
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
                const SizedBox(height: 20),
                // 2×2 stats grid
                _StatsGrid(live: live, type: type, l: l, accent: accent),
                const SizedBox(height: 28),
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
                const SizedBox(height: 12),
                // End
                _ControlButton(
                  icon: Icons.stop_rounded,
                  label: l.t('workout_end'),
                  color: const Color(0xFF3A2020),
                  textColor: const Color(0xFFFF5F5F),
                  border: const Color(0xFF5C2626),
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
                const SizedBox(height: 20),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF6B7E96)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.check_rounded, color: accent, size: 44),
                ),
                const SizedBox(height: 16),
                Text(
                  l.t('workout_complete'),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF2F6FF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _exerciseName(widget.type, l),
                  style: TextStyle(color: accent, fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 28),
                if (s != null) ...[
                  _SummaryCard(summary: s, l: l, accent: accent),
                ] else ...[
                  Text(
                    l.t('workout_no_data'),
                    style: const TextStyle(
                        color: Color(0xFF6B7E96), fontSize: 14),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      l.t('workout_done'),
                      style: const TextStyle(
                          color: Color(0xFF090F17),
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFF1A2535))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF6B7E96), size: 22),
            onPressed: onClose,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(type.icon, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  _labelFor(type, l),
                  style: const TextStyle(
                    color: Color(0xFFDBE3F0),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            durationStr,
            style: GoogleFonts.spaceGrotesk(
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
              style: GoogleFonts.spaceGrotesk(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF2F6FF),
                height: 1,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  unit,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
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
                color: const Color(0xFFFF5F9E),
              ),
            ),
            const SizedBox(width: 12),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCell(
                value: calStr,
                unit: l.t('kcal'),
                label: l.t('workout_calories'),
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFFFB23E),
              ),
            ),
            const SizedBox(width: 12),
            if (type.showDistance)
              Expanded(
                child: _StatCell(
                  value: paceStr,
                  unit: '/km',
                  label: l.t('workout_pace'),
                  icon: Icons.speed_rounded,
                  color: const Color(0xFF9B8CFF),
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
                  color: const Color(0xFF36E0FF),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF101924),
        border: Border.all(color: const Color(0xFF1C2838)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF2F6FF),
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFF6B7E96),
                fontSize: 11,
                fontWeight: FontWeight.w600),
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
    final fg = textColor ?? const Color(0xFF090F17);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color,
          border: border != null ? Border.all(color: border!) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF101924),
        border: Border.all(color: const Color(0xFF1C2838)),
      ),
      child: Column(
        children: [
          _row(Icons.timer_rounded, l.t('workout_duration'),
              live.durationStr, accent),
          if (summary.type.showDistance) ...[
            _divider(),
            _row(Icons.route_rounded, l.t('workout_distance'),
                '${live.distanceValueStr} ${live.distanceUnit}', accent),
          ],
          _divider(),
          _row(Icons.local_fire_department_rounded, l.t('workout_calories'),
              '${live.caloriesStr} ${l.t('kcal')}',
              const Color(0xFFFFB23E)),
          _divider(),
          _row(Icons.favorite_rounded, l.t('workout_avg_hr'),
              live.heartRate > 0 ? '${live.heartRate} ${l.t('bpm')}' : '--',
              const Color(0xFFFF5F9E)),
          _divider(),
          _row(Icons.directions_walk, l.t('steps'), live.stepsStr, accent),
          if (summary.type.showDistance && live.distanceM >= 10) ...[
            _divider(),
            _row(Icons.speed_rounded, l.t('workout_pace'),
                '${live.paceStr} /km', const Color(0xFF9B8CFF)),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9FB0CC), fontSize: 14)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFFF2F6FF),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(color: Color(0xFF1C2838), height: 1, thickness: 1);
}
