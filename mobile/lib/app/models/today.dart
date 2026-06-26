class TodaySnapshot {
  const TodaySnapshot({
    required this.recoveryPct,
    required this.strain,
    required this.strainMax,
    required this.sleepPct,
    required this.restingHr,
    required this.hrvMs,
    required this.steps,
  });

  final int recoveryPct; // 0..100
  final double strain; // 0..strainMax
  final double strainMax;
  final int sleepPct; // 0..100
  final int restingHr;
  final int hrvMs;
  final int steps;
}

TodaySnapshot mockToday() {
  return const TodaySnapshot(
    recoveryPct: 72,
    strain: 12.8,
    strainMax: 21.0,
    sleepPct: 83,
    restingHr: 54,
    hrvMs: 78,
    steps: 8421,
  );
}

