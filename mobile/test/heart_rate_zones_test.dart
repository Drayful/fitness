import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/band/heart_rate_zones.dart';

void main() {
  test('max heart rate from age, with a fallback', () {
    expect(HeartRateZones.maxHeartRate(20), 200);
    expect(HeartRateZones.maxHeartRate(null), 190);
  });

  test('zone boundaries are 50/60/70/80/90 % of max', () {
    const max = 200;
    expect(HeartRateZones.zoneOf(99, max), isNull); // rest
    expect(HeartRateZones.zoneOf(100, max), 0);
    expect(HeartRateZones.zoneOf(119, max), 0);
    expect(HeartRateZones.zoneOf(120, max), 1);
    expect(HeartRateZones.zoneOf(140, max), 2);
    expect(HeartRateZones.zoneOf(160, max), 3);
    expect(HeartRateZones.zoneOf(180, max), 4);
    expect(HeartRateZones.zoneOf(230, max), 4);
    expect(HeartRateZones.lowerBpm(max), [100, 120, 140, 160, 180]);
  });

  test('time in zones from 5-second samples', () {
    final seconds = HeartRateZones.secondsInZones(
      [90, 105, 125, 125, 145, 165, 185, 185, 185],
      5,
      200,
    );
    expect(seconds, [5, 10, 5, 5, 15]);
  });
}
