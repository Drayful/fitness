enum SleepStage { deep, light, rem, awake, unknown }

class SleepRecord {
  const SleepRecord({
    required this.start,
    required this.stages,
    this.unitMinutes = 1,
    this.rawValues = const [],
  });

  final DateTime start;
  final List<SleepStage> stages;

  /// Vendor values retained without inventing a physiological stage mapping.
  final List<int> rawValues;

  /// Minutes covered by each entry in [stages]. Legacy firmware reports one
  /// minute per entry; 2208A uses five in its packed 34-byte records.
  final int unitMinutes;

  int get durationMinutes => stages.length * unitMinutes;

  /// [stages] flattened to one entry per minute.
  Iterable<SleepStage> get perMinuteStages => unitMinutes == 1
      ? stages
      : stages.expand((s) => List.filled(unitMinutes, s));
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
    required this.observedMinutes,
  });

  const SleepSummary.empty()
    : bedTime = null,
      wakeTime = null,
      deepMinutes = 0,
      lightMinutes = 0,
      remMinutes = 0,
      awakeMinutes = 0,
      timeline = const <SleepStage>[],
      score = 0,
      observedMinutes = 0;

  factory SleepSummary.fromRecords(List<SleepRecord> records) {
    if (records.isEmpty) return const SleepSummary.empty();

    final sorted = [...records]..sort((a, b) => a.start.compareTo(b.start));
    // Select the most recent episode, preserving gaps and deduplicating retries.
    final minutes = <int, SleepStage>{};
    for (final r in sorted) {
      var t = r.start.millisecondsSinceEpoch ~/ 60000;
      for (final stage in r.perMinuteStages) {
        minutes[t++] = stage;
      }
    }
    if (minutes.isEmpty) return const SleepSummary.empty();
    final timestamps = minutes.keys.toList()..sort();
    var first = timestamps.first;
    for (var i = 1; i < timestamps.length; i++) {
      if (timestamps[i] - timestamps[i - 1] > 180) first = timestamps[i];
    }
    final last = timestamps.last;
    final timeline = [
      for (var t = first; t <= last; t++) minutes[t] ?? SleepStage.unknown,
    ];

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
        case SleepStage.unknown:
          break;
      }
    }

    final total = timeline.length;
    final score = total == 0
        ? 0
        : ((deep * 2.5 + rem * 2.0 + light * 1.0) / (total * 2.5) * 100)
              .round()
              .clamp(0, 100);

    final wakeTime = DateTime.fromMillisecondsSinceEpoch((last + 1) * 60000);

    return SleepSummary(
      bedTime: DateTime.fromMillisecondsSinceEpoch(first * 60000),
      wakeTime: wakeTime,
      deepMinutes: deep,
      lightMinutes: light,
      remMinutes: rem,
      awakeMinutes: awake,
      timeline: timeline,
      score: score,
      observedMinutes: minutes.length,
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

  /// Minutes backed by records from the band, excluding gaps in the timeline.
  final int observedMinutes;

  bool get hasData => timeline.isNotEmpty;
  bool get hasValidatedStages =>
      hasData && !timeline.contains(SleepStage.unknown);
  int get totalMinutes =>
      deepMinutes + lightMinutes + remMinutes + awakeMinutes;
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
