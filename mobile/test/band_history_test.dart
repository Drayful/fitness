import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/band/band_history.dart';

/// BCD `26 10 04 HH mm 00` stamp, as the SDK parsers read it.
List<int> stamp(int hour, int minute) => [
  0x26,
  0x10,
  0x04,
  ((hour ~/ 10) << 4) | (hour % 10),
  ((minute ~/ 10) << 4) | (minute % 10),
  0x00,
];

Uint8List packet(List<List<int>> records, {int? endCmd}) => Uint8List.fromList([
  for (final r in records) ...r,
  if (endCmd != null) ...[endCmd, 0xFF],
]);

void main() {
  test('history requests never use the erasing mode 0x99', () {
    expect(BandHistory.request(), [0x00]);
    expect(BandHistory.request(continuation: true), [0x02]);
  });

  test('end marker is the <cmd> FF suffix', () {
    expect(BandHistory.isEnd(0x54, Uint8List.fromList([0x54, 0xFF])), isTrue);
    expect(BandHistory.isEnd(0x54, Uint8List.fromList([0x55, 0xFF])), isFalse);
    expect(BandHistory.isEnd(0x54, Uint8List.fromList([0x54, 1, 2])), isFalse);
  });

  test('auto measurement payload: interval mode, all day, every day', () {
    expect(
      BandHistory.autoMeasurementPayload(
        type: BandHistory.autoHeartRate,
        intervalMinutes: 5,
      ),
      [2, 0x00, 0x00, 0x23, 0x59, 0x7F, 5, 0, 1],
    );
    expect(
      BandHistory.autoMeasurementPayload(
        type: BandHistory.autoSpo2,
        intervalMinutes: 300,
      ).sublist(6),
      [0x2C, 0x01, 2],
    );
  });

  test('dynamic heart rate: 15 per-minute values, gaps dropped', () {
    final values = [62, 64, 0, 66, 255, ...List.filled(10, 70)];
    final record = [0x54, 0, 0, ...stamp(23, 30), ...values];
    expect(record, hasLength(24));
    final samples = BandHistory.parse(0x54, [
      packet([record, record], endCmd: 0x54),
    ]);
    // Two identical records → duplicates are fine; 0 and 255 are gaps.
    expect(samples, hasLength(26));
    expect(samples.first.metric, BodyMetric.heartRate);
    expect(samples.first.at, DateTime(2026, 10, 4, 23, 30));
    expect(samples.first.value, 62);
    expect(samples[2].at, DateTime(2026, 10, 4, 23, 33)); // 0 at :32 skipped
  });

  test('static heart rate, SpO2 and temperature records', () {
    final hr = BandHistory.parse(0x55, [
      packet([
        [0x55, 0, 0, ...stamp(8, 15), 58],
        [0x55, 0, 0, ...stamp(8, 20), 0],
      ]),
    ]);
    expect(hr.single.value, 58);
    expect(hr.single.at, DateTime(2026, 10, 4, 8, 15));

    final spo2 = BandHistory.parse(0x66, [
      packet([
        [0x66, 0, 0, ...stamp(3, 0), 97],
      ], endCmd: 0x66),
    ]);
    expect(spo2.single.metric, BodyMetric.spo2);
    expect(spo2.single.value, 97);

    final temp = BandHistory.parse(0x62, [
      packet([
        [0x62, 0, 0, ...stamp(4, 0), 0x6C, 0x01], // 364 → 36.4
      ]),
    ]);
    expect(temp.single.metric, BodyMetric.temperature);
    expect(temp.single.value, closeTo(36.4, 0.001));
  });

  test('HRV record yields HRV, heart rate and stress', () {
    final samples = BandHistory.parse(0x56, [
      packet([
        [0x56, 0, 0, ...stamp(2, 10), 54, 30, 61, 22, 120, 80],
      ], endCmd: 0x56),
    ]);
    expect(
      {for (final s in samples) s.metric: s.value},
      {BodyMetric.hrv: 54, BodyMetric.heartRate: 61, BodyMetric.stress: 22},
    );
  });

  test('malformed records are skipped, not guessed', () {
    final badDate = [0x55, 0, 0, 0x26, 0x13, 0x04, 0x08, 0x15, 0x00, 60];
    final badBcd = [0x55, 0, 0, 0x26, 0x10, 0x04, 0x1A, 0x15, 0x00, 60];
    expect(BandHistory.parse(0x55, [packet([badDate, badBcd])]), isEmpty);
    // Length that is not a whole number of records.
    expect(
      BandHistory.parse(0x55, [Uint8List.fromList([0x55, 1, 2, 3])]),
      isEmpty,
    );
    // Bare end marker.
    expect(BandHistory.parse(0x55, [Uint8List.fromList([0x55, 0xFF])]), isEmpty);
  });

  List<int> dayRecord(int size, {required int steps}) {
    final r = List<int>.filled(size, 0);
    r[0] = 0x51;
    r.setRange(2, 5, [0x26, 0x10, 0x04]);
    void u32(int o, int v) => r.setRange(o, o + 4, [
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);
    u32(5, steps);
    u32(9, 42); // active minutes
    u32(13, 315); // 3.15 km
    u32(17, 18050); // 180.50 kcal
    return r;
  }

  test('daily totals for 26- and 27-byte firmware records', () {
    for (final size in [26, 27]) {
      final days = BandHistory.parseDailyTotals([
        packet([dayRecord(size, steps: 5230)], endCmd: 0x51),
      ]);
      final d = days.single;
      expect(d.date, DateTime(2026, 10, 4));
      expect(d.steps, 5230);
      expect(d.activeMinutes, 42);
      expect(d.distanceKm, closeTo(3.15, 0.001));
      expect(d.calories, closeTo(180.5, 0.001));
    }
  });
}
