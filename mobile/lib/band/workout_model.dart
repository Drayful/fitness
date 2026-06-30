import 'package:flutter/material.dart';

enum ExerciseType {
  run(0),
  cycling(1),
  badminton(2),
  football(3),
  tennis(4),
  yoga(5),
  meditation(6),
  dance(7),
  basketball(8),
  walk(9),
  workout(10),
  cricket(11),
  hiking(12),
  aerobics(13),
  pingPong(14),
  ropeJump(15),
  sitUps(16),
  volleyball(17);

  const ExerciseType(this.bandCode);
  final int bandCode;

  static ExerciseType fromBandCode(int code) =>
      ExerciseType.values.firstWhere((e) => e.bandCode == code,
          orElse: () => ExerciseType.run);

  IconData get icon => switch (this) {
        ExerciseType.run => Icons.directions_run,
        ExerciseType.cycling => Icons.directions_bike,
        ExerciseType.walk => Icons.directions_walk,
        ExerciseType.workout => Icons.fitness_center,
        ExerciseType.yoga => Icons.self_improvement,
        ExerciseType.meditation => Icons.spa,
        ExerciseType.basketball => Icons.sports_basketball,
        ExerciseType.hiking => Icons.terrain,
        ExerciseType.dance => Icons.music_note,
        ExerciseType.badminton || ExerciseType.tennis => Icons.sports_tennis,
        ExerciseType.football => Icons.sports_soccer,
        ExerciseType.pingPong => Icons.sports_tennis,
        ExerciseType.ropeJump => Icons.loop,
        ExerciseType.sitUps => Icons.accessibility_new,
        ExerciseType.volleyball => Icons.sports_volleyball,
        ExerciseType.aerobics => Icons.directions_run,
        _ => Icons.sports,
      };

  Color get accentColor => switch (this) {
        ExerciseType.run => const Color(0xFF4ADE80),
        ExerciseType.cycling => const Color(0xFF36E0FF),
        ExerciseType.walk => const Color(0xFF8AA6FF),
        ExerciseType.workout => const Color(0xFFFFB23E),
        ExerciseType.yoga || ExerciseType.meditation => const Color(0xFF9B8CFF),
        ExerciseType.hiking => const Color(0xFF4ADE80),
        ExerciseType.basketball => const Color(0xFFFF7A59),
        ExerciseType.dance => const Color(0xFFFF5F9E),
        _ => const Color(0xFF36E0FF),
      };

  bool get showDistance => switch (this) {
        ExerciseType.run ||
        ExerciseType.cycling ||
        ExerciseType.walk ||
        ExerciseType.hiking =>
          true,
        _ => false,
      };
}

class WorkoutLive {
  const WorkoutLive({
    required this.heartRate,
    required this.steps,
    required this.calories,
    required this.durationSeconds,
    required this.distanceM,
  });

  final int heartRate;
  final int steps;
  final double calories;
  final int durationSeconds;
  final double distanceM;

  String get durationStr {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  String get distanceValueStr {
    if (distanceM >= 1000) return (distanceM / 1000).toStringAsFixed(2);
    return distanceM.round().toString();
  }

  String get distanceUnit => distanceM >= 1000 ? 'km' : 'm';

  String get paceStr {
    if (distanceM < 10 || durationSeconds <= 0) return '--:--';
    final secPerKm = durationSeconds / distanceM * 1000;
    final pm = secPerKm ~/ 60;
    final ps = secPerKm.round() % 60;
    return '$pm:${ps.toString().padLeft(2, '0')}';
  }

  String get caloriesStr => calories.toStringAsFixed(0);

  String get stepsStr {
    final s = steps.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.type,
    required this.startTime,
    required this.heartRate,
    required this.steps,
    required this.calories,
    required this.durationSeconds,
    required this.distanceM,
  });

  factory WorkoutSummary.fromLive(
    ExerciseType type,
    DateTime startTime,
    WorkoutLive live,
  ) =>
      WorkoutSummary(
        type: type,
        startTime: startTime,
        heartRate: live.heartRate,
        steps: live.steps,
        calories: live.calories,
        durationSeconds: live.durationSeconds,
        distanceM: live.distanceM,
      );

  final ExerciseType type;
  final DateTime startTime;
  final int heartRate;
  final int steps;
  final double calories;
  final int durationSeconds;
  final double distanceM;

  WorkoutLive get asLive => WorkoutLive(
        heartRate: heartRate,
        steps: steps,
        calories: calories,
        durationSeconds: durationSeconds,
        distanceM: distanceM,
      );
}
