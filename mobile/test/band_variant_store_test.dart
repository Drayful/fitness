import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/band/band_variant.dart';
import 'package:fitness_app/band/band_variant_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each confirmed watch model is remembered independently', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BandVariantStore();
    expect(await store.findByRemoteId('watch-a'), isNull);
    expect(await store.findByRemoteId('watch-b'), isNull);

    await store.remember('watch-a', 'AA:BB:CC:DD:EE:01', BandVariant.legacyV8);
    await store.remember('watch-b', 'AA:BB:CC:DD:EE:02', BandVariant.jc2208a);
    final nextLaunch = BandVariantStore();
    expect(await nextLaunch.findByRemoteId('watch-a'), BandVariant.legacyV8);
    expect(await nextLaunch.findByRemoteId('watch-b'), BandVariant.jc2208a);
    expect(await nextLaunch.confirmedRemoteDevices(), {
      'watch-a': BandVariant.legacyV8,
      'watch-b': BandVariant.jc2208a,
    });
    expect(
      await nextLaunch.findByMac('aa:bb:cc:dd:ee:02'),
      BandVariant.jc2208a,
    );
    expect(await nextLaunch.findByMac('00:00:00:00:00:00'), isNull);

    await nextLaunch.remember('watch-a', 'AA:BB:CC:DD:EE:01', null);
    expect(await nextLaunch.findByRemoteId('watch-a'), isNull);
    expect(await nextLaunch.findByMac('AA:BB:CC:DD:EE:01'), isNull);
    expect(await nextLaunch.findByRemoteId('watch-b'), BandVariant.jc2208a);
    expect(await nextLaunch.confirmedRemoteDevices(), {
      'watch-b': BandVariant.jc2208a,
    });
  });
}
