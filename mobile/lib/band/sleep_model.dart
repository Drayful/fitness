enum SleepStage { deep, light, rem, awake }

class SleepRecord {
  const SleepRecord({required this.start, required this.stages});
  final DateTime start;
  final List<SleepStage> stages; // one entry per minute
}

class SleepSummary {
  const SleepSummary({
    required this.bedTime,
    required this.wakeTime,
    required this.deepMinutes,
    required this.lightMinutes,
    required this.remMinutes,
    required this.awakeMinutes,
    required this.timeline,
    required this.score,
  });

  const SleepSummary.empty()
      : bedTime = null,
        wakeTime = null,
        deepMinutes = 0,
        lightMinutes = 0,
        remMinutes = 0,
        awakeMinutes = 0,
        timeline = const <SleepStage>[],
        score = 0;

  factory SleepSummary.fromRecords(List<SleepRecord> records) {
    if (records.isEmpty) return const SleepSummary.empty();

    final sorted = [...records]..sort((a, b) => a.start.compareTo(b.start));
    final timeline = <SleepStage>[];
    for (final r in sorted) {
      timeline.addAll(r.stages);
    }

    var deep = 0, light = 0, rem = 0, awake = 0;
    for (final s in timeline) {
      switch (s) {
        case SleepStage.deep:
          deep++;
        case SleepStage.light:
          light++;
        case SleepStage.rem:
          rem++;
        case SleepStage.awake:
          awake++;
      }
    }

    final total = timeline.length;
    final score = total == 0
        ? 0
        : ((deep * 2.5 + rem * 2.0 + light * 1.0) / (total * 2.5) * 100)
            .round()
            .clamp(0, 100);

    final wakeTime = sorted.last.start.add(
      Duration(minutes: sorted.last.stages.length),
    );

    return SleepSummary(
      bedTime: sorted.first.start,
      wakeTime: wakeTime,
      deepMinutes: deep,
      lightMinutes: light,
      remMinutes: rem,
      awakeMinutes: awake,
      timeline: timeline,
      score: score,
    );
  }

  final DateTime? bedTime;
  final DateTime? wakeTime;
  final int deepMinutes;
  final int lightMinutes;
  final int remMinutes;
  final int awakeMinutes;
  final List<SleepStage> timeline;
  final int score;

  bool get hasData => timeline.isNotEmpty;
  int get totalMinutes => deepMinutes + lightMinutes + remMinutes + awakeMinutes;
  int get sleepMinutes => deepMinutes + lightMinutes + remMinutes;

  String get durationStr {
    final h = sleepMinutes ~/ 60;
    final m = sleepMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String get efficiencyStr {
    if (totalMinutes == 0) return '—';
    return '${(sleepMinutes / totalMinutes * 100).round()}%';
  }
}
