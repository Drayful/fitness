/// Heart-rate zones (TZ §11) as percentages of maximum heart rate:
/// Z1 50–60 %, Z2 60–70 %, Z3 70–80 %, Z4 80–90 %, Z5 90 %+.
/// Readings below 50 % count as rest and belong to no zone.
class HeartRateZones {
  HeartRateZones._();

  static const zoneCount = 5;
  static const _lowerBounds = [0.5, 0.6, 0.7, 0.8, 0.9];

  /// Used when the birth date is unknown; the UI says so.
  static const fallbackMaxHeartRate = 190;

  /// Common age estimate (220 − age). Null age → [fallbackMaxHeartRate].
  static int maxHeartRate(int? age) =>
      age == null || age <= 0 ? fallbackMaxHeartRate : 220 - age;

  /// Zone index 0..4 for [bpm], or null below Z1.
  static int? zoneOf(int bpm, int maxHr) {
    final pct = bpm / maxHr;
    for (var z = zoneCount - 1; z >= 0; z--) {
      if (pct >= _lowerBounds[z]) return z;
    }
    return null;
  }

  /// Lowest bpm of each zone, for labels like "Z3 · 133+".
  static List<int> lowerBpm(int maxHr) => [
    for (final b in _lowerBounds) (b * maxHr).round(),
  ];

  /// Seconds spent in each zone, from evenly spaced samples.
  static List<int> secondsInZones(
    List<int> samples,
    int sampleSeconds,
    int maxHr,
  ) {
    final seconds = List<int>.filled(zoneCount, 0);
    for (final bpm in samples) {
      final z = zoneOf(bpm, maxHr);
      if (z != null) seconds[z] += sampleSeconds;
    }
    return seconds;
  }
}
