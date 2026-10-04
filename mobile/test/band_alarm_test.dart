import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/band/band_alarm.dart';

void main() {
  test('alarm packet follows SDK setClockData', () {
    const alarm = BandAlarm(
      hour: 6,
      minute: 45,
      weekdays: {1, 2, 3, 4, 5}, // Mon–Fri
    );
    final p = BandAlarm.packet([alarm]);
    expect(p, hasLength(41));
    expect(p.sublist(0, 9), [
      0x23, // command
      1, // alarms in list
      0, // number
      1, // enabled
      1, // normal alarm
      0x06, // 06 BCD
      0x45, // 45 BCD
      0x3E, // Mon..Fri → bits 1..5
      1, // content length
    ]);
    expect(p.sublist(39), [0x23, 0xFF]);
  });

  test('Sunday maps to bit 0, Saturday to bit 6', () {
    expect(
      const BandAlarm(hour: 9, minute: 0, weekdays: {7}).weekMask,
      0x01,
    );
    expect(
      const BandAlarm(hour: 9, minute: 0, weekdays: {6}).weekMask,
      0x40,
    );
  });

  test('disabled alarm keeps its record with the enabled flag off', () {
    final p = BandAlarm.packet([
      const BandAlarm(hour: 7, minute: 0, weekdays: {1}, enabled: false),
    ]);
    expect(p[3], 0);
  });

  test('json round trip', () {
    const a = BandAlarm(hour: 6, minute: 30, weekdays: {1, 7});
    final b = BandAlarm.fromJson(a.toJson())!;
    expect(b.hour, 6);
    expect(b.minute, 30);
    expect(b.weekdays, {1, 7});
    expect(b.enabled, isTrue);
    expect(BandAlarm.fromJson('not json'), isNull);
  });
}
