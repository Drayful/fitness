import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/band/band_variant.dart';
import 'package:fitness_app/band/sleep_model.dart';
import 'package:fitness_app/band/v8_protocol.dart';

// Fixtures follow the supplied SDK layouts, without using packet builders.
Uint8List sleepPacket({int size = 34, int length = 24}) {
  final p = Uint8List(size);
  p.setRange(0, 10, [0x53, 0xFF, 0, 0x26, 0x09, 0x18, 0x01, 0x30, 0, length]);
  return p;
}

void main() {
  test('measurement duration occupies bytes 4 and 5 in V8 only', () {
    final p = V8Protocol.buildPacket(
      0x28,
      V8Protocol.measurePayload(mode: 2, start: true, durationSec: 300),
    );
    expect(p.sublist(0, 7), [0x28, 2, 1, 0, 0x2C, 1, 0]);
    final n = V8Protocol.buildPacket(
      0x28,
      V8Protocol.measurePayload(
        mode: 2,
        start: true,
        durationSec: 300,
        variant: BandVariant.jc2208a,
      ),
    );
    expect(n.sublist(0, 7), [0x28, 2, 1, 0, 0, 0, 0]);
  });
  test('live packet carries calories, distance and exercise time', () {
    final p = Uint8List(25);
    p[0] = 0x09;
    void u32(int o, int v) => p.setRange(o, o + 4, [
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);
    u32(1, 5230); // steps
    u32(5, 18050); // 180.50 kcal
    u32(9, 315); // 3.15 km
    u32(13, 2520); // 42 min in seconds
    p[21] = 72;
    final v = V8Protocol.parseLivePacket(p)!;
    expect(v.steps, 5230);
    expect(v.caloriesKcal, closeTo(180.5, 0.001));
    expect(v.distanceKm, closeTo(3.15, 0.001));
    expect(v.exerciseMinutes, 42);
    expect(v.heartRate, 72);
  });
  group('V8 sleep stages follow the SDK rule (sleep.txt)', () {
    test('one-minute records carry stage codes', () {
      final p = sleepPacket(size: 130, length: 5)
        ..setRange(10, 15, [1, 2, 3, 58, 0]);
      final r = V8Protocol.parseSleepPackets([
        p,
      ], BandVariant.legacyV8).single;
      expect(r.unitMinutes, 1);
      expect(r.stages, [
        SleepStage.deep,
        SleepStage.light,
        SleepStage.rem,
        SleepStage.awake,
        SleepStage.awake,
      ]);
    });
    test('five-minute values are divided by 5 and bucketed', () {
      final p = sleepPacket(length: 7)
        ..setRange(10, 17, [0, 10, 11, 40, 41, 100, 101]);
      final r = V8Protocol.parseSleepPackets([
        p,
      ], BandVariant.legacyV8).single;
      expect(r.unitMinutes, 5);
      expect(r.stages, [
        SleepStage.deep, // 0
        SleepStage.deep, // 10 / 5 = 2
        SleepStage.light, // 2.2
        SleepStage.light, // 8
        SleepStage.rem, // 8.2
        SleepStage.rem, // 20
        SleepStage.awake, // 20.2
      ]);
      final s = SleepSummary.fromRecords([r]);
      expect(s.hasValidatedStages, isTrue);
      expect(s.deepMinutes, 10);
      expect(s.lightMinutes, 10);
      expect(s.remMinutes, 10);
      expect(s.awakeMinutes, 5);
    });
    test('2208A stays unverified: its SDK publishes no rule', () {
      final p = sleepPacket(size: 130, length: 3)..setRange(10, 13, [1, 2, 3]);
      final r = V8Protocol.parseSleepPackets([
        p,
      ], BandVariant.jc2208a).single;
      expect(r.stages.toSet(), {SleepStage.unknown});
    });
  });
  for (final variant in BandVariant.values) {
    group(variant.name, () {
      test('BCD date and timezone in both SDKs', () {
        final p = V8Protocol.setTimePayload(
          DateTime.utc(2026, 12, 25, 23, 45, 30),
          variant,
        );
        expect(p, [0x26, 0x12, 0x25, 0x23, 0x45, 0x30, 0, 0x80]);
        expect(
          V8Protocol.parseDeviceTime(Uint8List.fromList([0x41, ...p]), variant),
          DateTime(2026, 12, 25, 23, 45, 30),
        );
      });
      test('invalid BCD and impossible dates rejected', () {
        for (final fields in [
          [0x26, 0x02, 0x30, 0, 0, 0],
          [0x26, 0x09, 0x1A, 0, 0, 0],
        ]) {
          expect(
            V8Protocol.parseDeviceTime(
              Uint8List.fromList([0x41, ...fields]),
              variant,
            ),
            isNull,
          );
        }
      });
      test('record ID FF is not terminator and raw sleep values retained', () {
        final p = sleepPacket()..[10] = 200;
        expect(V8Protocol.isStreamEnd(p, variant), isFalse);
        final records = V8Protocol.parseSleepPackets([p], variant);
        expect(records, hasLength(1));
        expect(records.single.start, DateTime(2026, 9, 18, 1, 30));
        expect(records.single.durationMinutes, 120);
        expect(records.single.rawValues.first, 200);
        if (variant == BandVariant.legacyV8) {
          // V8 SDK rule: 200 / 5 = 40 → awake; zero padding → deep.
          expect(records.single.stages.first, SleepStage.awake);
          expect(records.single.stages.skip(1).toSet(), {SleepStage.deep});
          expect(SleepSummary.fromRecords(records).hasValidatedStages, isTrue);
        } else {
          expect(records.single.stages.toSet(), {SleepStage.unknown});
          expect(
            SleepSummary.fromRecords(records).hasValidatedStages,
            isFalse,
          );
        }
      });
      test('final notification retains all records and needs exact suffix', () {
        final p = Uint8List.fromList([
          ...sleepPacket(),
          ...sleepPacket(),
          0x53,
          0xFF,
        ]);
        expect(V8Protocol.isStreamEnd(p, variant), isTrue);
        expect(V8Protocol.parseSleepPackets([p], variant), hasLength(2));
        expect(
          V8Protocol.isStreamEnd(
            Uint8List.fromList([0x53, 1, 0, 0xFF]),
            variant,
          ),
          isFalse,
        );
        expect(
          V8Protocol.parseSleepPackets([
            Uint8List.fromList([0x53, 0xFF]),
          ], variant),
          isEmpty,
        );
      });
      test('one minute records, malformed lengths and dates', () {
        final r = V8Protocol.parseSleepPackets([
          sleepPacket(size: 130, length: 120),
        ], variant).single;
        expect(r.unitMinutes, 1);
        expect(r.rawValues, hasLength(120));
        for (final p in [
          sleepPacket(length: 25),
          sleepPacket()..[4] = 0x19,
          sleepPacket(size: 33),
        ]) {
          expect(V8Protocol.parseSleepPackets([p], variant), isEmpty);
        }
      });
    });
  }
  test('device errors and invalid battery values are rejected', () {
    expect(
      V8Protocol.parseBatteryPercent(Uint8List.fromList([0x93, 80])),
      isNull,
    );
    expect(
      V8Protocol.parseBatteryPercent(Uint8List.fromList([0x13, 255])),
      isNull,
    );
    expect(V8Protocol.parseBatteryPercent(Uint8List.fromList([0x13, 0])), 0);
  });
  test('UUID matching is exact', () {
    expect(V8Protocol.uuidMatches('fff0', V8Protocol.serviceUuid), isTrue);
    expect(V8Protocol.uuidMatches('0000fff0', V8Protocol.serviceUuid), isTrue);
    expect(
      V8Protocol.uuidMatches(
        '1234fff0-0000-1000-8000-00805f9b34fb',
        V8Protocol.serviceUuid,
      ),
      isFalse,
    );
  });
  test('V8 exercise carries duration but no distance', () {
    final p = Uint8List.fromList([
      0x18,
      120,
      0xE8,
      3,
      0,
      0,
      0,
      0,
      0x28,
      0x42,
      0x2C,
      1,
      0,
      0,
      0,
      0,
    ]);
    final live = V8Protocol.parseExerciseLive(p, BandVariant.legacyV8)!;
    expect(live.steps, 1000);
    expect(live.calories, 42);
    expect(live.durationSeconds, 300);
    expect(live.distanceM, 0);
    expect(
      V8Protocol.parseExerciseLive(p, BandVariant.jc2208a)!.durationSeconds,
      0,
    );
    expect(V8Protocol.parseExerciseLive(Uint8List(10)), isNull);
  });
  test('checksum and temperature flag follow vendor framing', () {
    final p = V8Protocol.buildPacket(
      9,
      V8Protocol.realtimePayload(enable: true, variant: BandVariant.legacyV8),
    );
    expect(p.take(3), [9, 1, 1]);
    expect(p.last, 11);
  });
  test('latest sleep episode selected; retry duplicates do not inflate it', () {
    final old = SleepRecord(
      start: DateTime(2026, 9, 16),
      stages: List.filled(60, SleepStage.light),
    );
    final recent = SleepRecord(
      start: DateTime(2026, 9, 18),
      stages: List.filled(60, SleepStage.deep),
    );
    final s = SleepSummary.fromRecords([old, recent, recent]);
    expect(s.totalMinutes, 60);
    expect(s.observedMinutes, 60);
    expect(s.bedTime, recent.start);
    expect(s.wakeTime, DateTime(2026, 9, 18, 1));
  });
  test('gaps are not converted into measured sleep', () {
    final s = SleepSummary.fromRecords([
      SleepRecord(start: DateTime(2026, 9, 18), stages: [SleepStage.light]),
      SleepRecord(
        start: DateTime(2026, 9, 18, 0, 2),
        stages: [SleepStage.light],
      ),
    ]);
    expect(s.timeline, [
      SleepStage.light,
      SleepStage.unknown,
      SleepStage.light,
    ]);
    expect(s.hasValidatedStages, isFalse);
    expect(s.observedMinutes, 2);
  });
}
