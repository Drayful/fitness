import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../band/workout_model.dart';
import '../../main.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'workout_screen.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final band = BandServiceScope.of(context);
    return ListenableBuilder(
      listenable: band,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final c = context.appColors;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Text(
              l.t('training'),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF2F6FF),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Quick start tiles
            _sectionLabel(c, l.t('quick_start')),
            const SizedBox(height: 11),
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
                const SizedBox(width: 10),
                _quickTile(
                  c,
                  ExerciseType.cycling.icon,
                  l.t('bike'),
                  ExerciseType.cycling.accentColor,
                  band.isConnected
                      ? () => _startWorkout(context, ExerciseType.cycling)
                      : null,
                ),
                const SizedBox(width: 10),
                _quickTile(
                  c,
                  ExerciseType.walk.icon,
                  l.t('walk'),
                  ExerciseType.walk.accentColor,
                  band.isConnected
                      ? () => _startWorkout(context, ExerciseType.walk)
                      : null,
                ),
                const SizedBox(width: 10),
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
              const SizedBox(height: 12),
              _ConnectHint(c: c, l: l),
            ],

            const SizedBox(height: 16),

            // Only recorded workouts are shown.
            _sectionLabel(c, l.t('recent')),
            const SizedBox(height: 11),
            if (band.workoutHistory.isNotEmpty)
              ...band.workoutHistory
                  .take(5)
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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
                    color: const Color(0xFF101924),
                    border: Border.all(color: const Color(0xFF1C2838)),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9FB0CC),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF101924),
        border: Border.all(color: const Color(0xFF1C2838)),
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
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeName(summary.type, l),
                  style: const TextStyle(
                    color: Color(0xFFEEF3FB),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(meta, style: TextStyle(color: c.subtext, fontSize: 12)),
              ],
            ),
          ),
          Text(
            when,
            style: GoogleFonts.spaceGrotesk(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF101420),
        border: Border.all(color: const Color(0xFF1C2838)),
      ),
      child: Row(
        children: [
          Icon(Icons.watch_outlined, color: c.subtext, size: 18),
          const SizedBox(width: 10),
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
