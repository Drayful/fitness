import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/band/v8_band_service.dart';

void main() {
  test('watch name hints avoid generic smart devices', () {
    expect(ScannedBand.hasWatchNameHint('JCV8-1234'), isTrue);
    expect(ScannedBand.hasWatchNameHint('V8_ABC'), isTrue);
    expect(ScannedBand.hasWatchNameHint('JStyle 2208A'), isTrue);
    expect(ScannedBand.hasWatchNameHint('Smart TV'), isFalse);
    expect(ScannedBand.hasWatchNameHint('Watch speaker'), isFalse);
    expect(ScannedBand.hasWatchNameHint(''), isFalse);
  });
}
