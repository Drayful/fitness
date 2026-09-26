import 'package:shared_preferences/shared_preferences.dart';

import 'band_variant.dart';

/// A local, per-device record of the model confirmed by the user.
/// The shared BLE service, time reply and firmware version do not identify it.
class BandVariantStore {
  static const _prefix = 'confirmed_band_variant_v1_';

  Future<BandVariant?> findByRemoteId(String remoteId) =>
      _read('remote:${remoteId.toLowerCase()}');

  Future<BandVariant?> findByMac(String mac) =>
      _usableMac(mac) ? _read('mac:${mac.toLowerCase()}') : Future.value();

  /// Models explicitly selected for BLE identifiers seen on this phone.
  Future<Map<String, BandVariant>> confirmedRemoteDevices() async {
    final prefs = await SharedPreferences.getInstance();
    const remotePrefix = '${_prefix}remote:';
    final confirmed = <String, BandVariant>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(remotePrefix)) continue;
      final name = prefs.getString(key);
      for (final variant in BandVariant.values) {
        if (variant.name == name) {
          confirmed[key.substring(remotePrefix.length)] = variant;
          break;
        }
      }
    }
    return confirmed;
  }

  Future<void> remember(
    String remoteId,
    String? mac,
    BandVariant? variant,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      'remote:${remoteId.toLowerCase()}',
      if (mac != null && _usableMac(mac)) 'mac:${mac.toLowerCase()}',
    ];
    for (final key in keys) {
      if (variant == null) {
        await prefs.remove('$_prefix$key');
      } else {
        await prefs.setString('$_prefix$key', variant.name);
      }
    }
  }

  Future<BandVariant?> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('$_prefix$key');
    for (final variant in BandVariant.values) {
      if (variant.name == name) return variant;
    }
    return null;
  }

  bool _usableMac(String mac) =>
      RegExp(r'^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$').hasMatch(mac) &&
      mac.toLowerCase() != '00:00:00:00:00:00';
}
