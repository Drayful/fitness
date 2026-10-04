import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/app/notifications/alert_rules.dart';

void main() {
  late List<AlertCategory> fired;
  late DateTime now;
  late AlertRules rules;

  setUp(() {
    fired = [];
    now = DateTime(2026, 10, 5, 8);
    rules = AlertRules(notify: (c, _) => fired.add(c), clock: () => now);
  });

  test('low battery fires once and re-arms after charging', () {
    rules.onBattery(25);
    rules.onBattery(19);
    rules.onBattery(15);
    expect(fired, [AlertCategory.lowBattery]);
    rules.onBattery(80);
    rules.onBattery(10);
    expect(fired, [AlertCategory.lowBattery, AlertCategory.lowBattery]);
  });

  test('band away only after 30 minutes and once per absence', () {
    rules.onConnection(connected: false, remembered: true);
    now = now.add(const Duration(minutes: 29));
    rules.onConnection(connected: false, remembered: true);
    expect(fired, isEmpty);
    now = now.add(const Duration(minutes: 2));
    rules.onConnection(connected: false, remembered: true);
    rules.onConnection(connected: false, remembered: true);
    expect(fired, [AlertCategory.bandAway]);
    // Never-connected users are not nagged.
    final other = AlertRules(notify: (c, _) => fired.add(c), clock: () => now);
    other.onConnection(connected: false, remembered: false);
    expect(fired, hasLength(1));
  });

  test('high heart rate needs 3 readings, ignores workouts, has cooldown', () {
    rules.onLiveHeartRate(130, workoutActive: false);
    rules.onLiveHeartRate(131, workoutActive: false);
    rules.onLiveHeartRate(90, workoutActive: false); // streak broken
    rules.onLiveHeartRate(130, workoutActive: false);
    rules.onLiveHeartRate(130, workoutActive: true); // workout resets
    expect(fired, isEmpty);
    for (var i = 0; i < 3; i++) {
      rules.onLiveHeartRate(135, workoutActive: false);
    }
    expect(fired, [AlertCategory.highHeartRate]);
    for (var i = 0; i < 3; i++) {
      rules.onLiveHeartRate(135, workoutActive: false);
    }
    expect(fired, hasLength(1)); // cooldown
    now = now.add(const Duration(hours: 1));
    for (var i = 0; i < 3; i++) {
      rules.onLiveHeartRate(135, workoutActive: false);
    }
    expect(fired, hasLength(2));
  });

  test('short sleep fires once per night, not for old nights', () {
    final bed = DateTime(2026, 10, 4, 23, 30);
    rules.onSleep(bedTime: bed, asleepMinutes: 7 * 60);
    expect(fired, isEmpty);
    rules.onSleep(bedTime: bed, asleepMinutes: 5 * 60);
    rules.onSleep(bedTime: bed, asleepMinutes: 5 * 60);
    expect(fired, [AlertCategory.sleepShortage]);
    rules.onSleep(bedTime: DateTime(2026, 10, 1, 23), asleepMinutes: 60);
    expect(fired, hasLength(1));
  });

  test('stale sync once per last sync; sync complete skips the first', () {
    final last = DateTime(2026, 10, 1);
    rules.onStaleSync(stale: true, lastSyncAt: last);
    rules.onStaleSync(stale: true, lastSyncAt: last);
    expect(fired, [AlertCategory.staleSync]);
    rules.onHistorySynced(1);
    rules.onHistorySynced(1);
    rules.onHistorySynced(2);
    expect(fired, [AlertCategory.staleSync, AlertCategory.syncComplete]);
  });
}
