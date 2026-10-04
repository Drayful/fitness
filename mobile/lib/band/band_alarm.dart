import 'dart:convert';
import 'dart:typed_data';

/// A wake-up alarm the band plays as vibration (TZ §14, SDK `setClockData`,
/// command 0x23). A plain time alarm: the band reports sleep phases only
/// after sync, so a phase-aware "smart" window is not possible on-device.
class BandAlarm {
  const BandAlarm({
    required this.hour,
    required this.minute,
    required this.weekdays,
    this.enabled = true,
  });

  final int hour;
  final int minute;

  /// Days as in [DateTime.weekday]: 1 = Monday … 7 = Sunday.
  final Set<int> weekdays;
  final bool enabled;

  static const cmdSetAlarms = 0x23;
  static const _recordBytes = 39;
  static const _typeNormal = 1;

  /// SDK week mask: bit 0 = Sunday, bit 1 = Monday … bit 6 = Saturday.
  int get weekMask {
    var mask = 0;
    for (final d in weekdays) {
      mask |= 1 << (d % 7); // Sunday (7) → bit 0
    }
    return mask;
  }

  static int _bcd(int v) => ((v ~/ 10) << 4) | (v % 10);

  /// The band replaces its whole alarm list with what is sent: one 39-byte
  /// record per alarm, then the `0x23 0xFF` terminator.
  static Uint8List packet(List<BandAlarm> alarms) {
    final out = Uint8List(_recordBytes * alarms.length + 2);
    for (var i = 0; i < alarms.length; i++) {
      final a = alarms[i];
      final o = i * _recordBytes;
      out[o] = cmdSetAlarms;
      out[o + 1] = alarms.length;
      out[o + 2] = i; // alarm number
      out[o + 3] = a.enabled ? 1 : 0;
      out[o + 4] = _typeNormal;
      out[o + 5] = _bcd(a.hour);
      out[o + 6] = _bcd(a.minute);
      out[o + 7] = a.weekMask;
      out[o + 8] = 1; // content length; no label text
    }
    out[out.length - 2] = cmdSetAlarms;
    out[out.length - 1] = 0xFF;
    return out;
  }

  String toJson() => jsonEncode({
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays.toList()..sort(),
    'enabled': enabled,
  });

  static BandAlarm? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map;
      return BandAlarm(
        hour: (m['hour'] as num).toInt(),
        minute: (m['minute'] as num).toInt(),
        weekdays: {for (final d in m['weekdays'] as List) (d as num).toInt()},
        enabled: m['enabled'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
