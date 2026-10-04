import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../api/session_controller.dart';
import '../../band/heart_rate_zones.dart';
import '../../band/workout_model.dart';
import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'workout_screen.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild on light/dark switches: AppTheme getters are not inherited.
    AppTheme.watch(context);
    final band = BandServiceScope.of(context);
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final c = context.appColors;

        return ListView(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Text(
              l.t('training'),
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 10),
            // TZ §22: a workout can also be added by hand.
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: session.isAuthenticated
                    ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (_) => _ManualWorkoutSheet(session: session),
                      )
                    : null,
                icon: Icon(Icons.edit_calendar_outlined),
                label: Text(l.t('workout_add_manual')),
              ),
            ),
            SizedBox(height: 16),

            // Quick start tiles
            _sectionLabel(c, l.t('quick_start')),
            SizedBox(height: 11),
            Row(
              children: [
                _quickTile(
                  c,
                  ExerciseType.run.icon,
                  l.t('run'),
                  ExerciseType.run.accentColor,
                  band.isConnected
                      ? () => _startWorkout(context, ExerciseType.run)
                      : null,
                ),
                SizedBox(width: 10),
                _quickTile(
                  c,
                  ExerciseType.cycling.icon,
                  l.t('bike'),
                  ExerciseType.cycling.accentColor,
                  band.isConnected
                      ? () => _startWorkout(context, ExerciseType.cycling)
                      : null,
                ),
                SizedBox(width: 10),
                _quickTile(
                  c,
                  ExerciseType.walk.icon,
                  l.t('walk'),
                  ExerciseType.walk.accentColor,
                  band.isConnected
                      ? () => _startWorkout(context, ExerciseType.walk)
                      : null,
                ),
                SizedBox(width: 10),
                _quickTile(
                  c,
                  ExerciseType.workout.icon,
                  l.t('strength'),
                  ExerciseType.workout.accentColor,
                  band.isConnected
                      ? () => _startWorkout(context, ExerciseType.workout)
                      : null,
                ),
              ],
            ),

            // Not-connected hint
            if (!band.isConnected) ...[
              SizedBox(height: 12),
              _ConnectHint(c: c, l: l),
            ],

            SizedBox(height: 16),

            _WeeklyZones(
              workouts: [
                ...band.workoutHistory,
                ...session.savedWorkouts,
              ],
              age: session.bodyProfile.age,
              l: l,
            ),

            // Only recorded workouts are shown.
            _sectionLabel(c, l.t('recent')),
            SizedBox(height: 11),
            if (session.savedWorkouts.isNotEmpty ||
                band.workoutHistory.isNotEmpty)
              ...(session.savedWorkouts.isNotEmpty
                      ? session.savedWorkouts
                      : band.workoutHistory)
                  .take(5)
                  .map(
                    (w) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _WorkoutHistoryRow(summary: w, c: c, l: l),
                    ),
                  )
            else
              Text(l.t('no_workouts'), style: TextStyle(color: c.subtext)),
          ],
        );
      },
    );
  }

  static void _startWorkout(BuildContext context, ExerciseType type) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => WorkoutScreen(type: type),
      ),
    );
  }

  Widget _sectionLabel(AppColors c, String text) => Text(
    text,
    style: TextStyle(
      color: c.subtext,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );

  Widget _quickTile(
    AppColors c,
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.outline),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutHistoryRow extends StatelessWidget {
  const _WorkoutHistoryRow({
    required this.summary,
    required this.c,
    required this.l,
  });

  final WorkoutSummary summary;
  final AppColors c;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final live = summary.asLive;
    final color = summary.type.accentColor;
    final metaParts = <String>[live.durationStr];
    if (summary.type.showDistance && live.distanceM >= 10) {
      metaParts.add('${live.distanceValueStr} ${live.distanceUnit}');
    }
    if (live.calories > 0) {
      metaParts.add('${live.caloriesStr} ${l.t('kcal')}');
    }
    final meta = metaParts.join(' · ');

    final now = DateTime.now();
    final diff = now.difference(summary.startTime);
    final String when;
    if (diff.inMinutes < 60) {
      when = '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      when = '${diff.inHours}h';
    } else {
      when =
          '${summary.startTime.day.toString().padLeft(2, '0')}.${summary.startTime.month.toString().padLeft(2, '0')}.${summary.startTime.year}';
    }

    return Container(
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(summary.type.icon, color: color, size: 22),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeName(summary.type, l),
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(meta, style: TextStyle(color: c.subtext, fontSize: 12)),
              ],
            ),
          ),
          Text(
            when,
            style: GoogleFonts.manrope(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _typeName(ExerciseType type, AppLocalizations l) {
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

class _ConnectHint extends StatelessWidget {
  const _ConnectHint({required this.c, required this.l});

  final AppColors c;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.watch_outlined, color: c.subtext, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              l.t('workout_connect_hint'),
              style: TextStyle(color: c.subtext, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// TZ §11: weekly time in easy (Z1–3) vs hard (Z4–5) zones, from workouts of
/// the last 7 days that carry a heart-rate series.
class _WeeklyZones extends StatelessWidget {
  const _WeeklyZones({
    required this.workouts,
    required this.age,
    required this.l,
  });

  final List<WorkoutSummary> workouts;
  final int? age;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final weekAgo = DateTime.now().subtract(Duration(days: 7));
    final maxHr = HeartRateZones.maxHeartRate(age);
    final seen = <String>{};
    var easy = 0;
    var hard = 0;
    for (final w in workouts) {
      // The same workout can be both in memory and on the server.
      final key = '${w.type.name}-${w.startTime.toUtc().millisecondsSinceEpoch}';
      if (!seen.add(key) ||
          w.startTime.isBefore(weekAgo) ||
          w.heartRateSamples.isEmpty) {
        continue;
      }
      final s = HeartRateZones.secondsInZones(
        w.heartRateSamples,
        WorkoutSummary.heartRateSampleSeconds,
        maxHr,
      );
      easy += s[0] + s[1] + s[2];
      hard += s[3] + s[4];
    }
    if (easy + hard == 0) return SizedBox.shrink();

    Widget block(String label, int seconds, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.subtext),
          ),
          SizedBox(height: 4),
          Text(
            '${seconds ~/ 60} ${l.t('minutes_short')}',
            style: AppTheme.numeric(fontSize: 22, color: color),
          ),
        ],
      ),
    );

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('week_zones'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
              color: AppTheme.subtext,
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              block(l.t('zones_easy'), easy, AppTheme.good),
              block(l.t('zones_hard'), hard, AppTheme.warn),
            ],
          ),
        ],
      ),
    );
  }
}

/// TZ §22: add a workout by hand — sport, start, duration, intensity,
/// optional calories. Goes through the same offline-safe upload queue.
class _ManualWorkoutSheet extends StatefulWidget {
  const _ManualWorkoutSheet({required this.session});

  final SessionController session;

  @override
  State<_ManualWorkoutSheet> createState() => _ManualWorkoutSheetState();
}

class _ManualWorkoutSheetState extends State<_ManualWorkoutSheet> {
  static const _types = [
    ExerciseType.run,
    ExerciseType.walk,
    ExerciseType.cycling,
    ExerciseType.workout,
    ExerciseType.yoga,
    ExerciseType.dance,
    ExerciseType.basketball,
    ExerciseType.hiking,
  ];

  ExerciseType _type = ExerciseType.workout;
  late DateTime _start = DateTime.now().subtract(Duration(hours: 1));
  final _duration = TextEditingController(text: '60');
  final _calories = TextEditingController();
  double _intensity = 5;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _duration.dispose();
    _calories.dispose();
    super.dispose();
  }

  String _typeName(ExerciseType t, AppLocalizations l) => switch (t) {
    ExerciseType.run => l.t('workout_type_run'),
    ExerciseType.cycling => l.t('workout_type_cycling'),
    ExerciseType.walk => l.t('workout_type_walk'),
    ExerciseType.workout => l.t('workout_type_workout'),
    ExerciseType.yoga => l.t('workout_type_yoga'),
    ExerciseType.hiking => l.t('workout_type_hiking'),
    ExerciseType.basketball => l.t('workout_type_basketball'),
    ExerciseType.dance => l.t('workout_type_dance'),
    _ => t.name,
  };

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: now.subtract(Duration(days: 60)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(
      () => _start = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final minutes = int.tryParse(_duration.text.trim());
    final calories = _calories.text.trim().isEmpty
        ? 0.0
        : double.tryParse(_calories.text.trim().replaceAll(',', '.'));
    if (minutes == null || minutes < 1 || minutes > 600 || calories == null) {
      setState(() => _error = l.t('workout_manual_invalid'));
      return;
    }
    if (_start.add(Duration(minutes: minutes)).isAfter(DateTime.now())) {
      setState(() => _error = l.t('workout_manual_future'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final summary = WorkoutSummary(
      type: _type,
      startTime: _start,
      heartRate: 0,
      steps: 0,
      calories: calories,
      durationSeconds: minutes * 60,
      distanceM: 0,
    );
    try {
      await widget.session.uploadWorkout(
        summary,
        intensity: _intensity.round(),
      );
      messenger.showSnackBar(SnackBar(content: Text(l.t('sync_ok_workout'))));
    } catch (_) {
      // Already stored in the upload queue; it is retried automatically.
      messenger.showSnackBar(
        SnackBar(content: Text(l.t('workout_manual_queued'))),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('workout_add_manual'),
              style: AppTheme.numeric(fontSize: 18),
            ),
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _types)
                  ChoiceChip(
                    label: Text(_typeName(t, l)),
                    selected: t == _type,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickStart,
              icon: Icon(Icons.schedule),
              label: Text(
                '${loc.formatMediumDate(_start)}, '
                '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(_start), alwaysUse24HourFormat: true)}',
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.t('workout_manual_minutes'),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _calories,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l.t('workout_manual_kcal'),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              '${l.t('workout_manual_intensity')}: ${_intensity.round()} / 10',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            Slider(
              value: _intensity,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => setState(() => _intensity = v),
            ),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: AppTheme.danger)),
              SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.t('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
