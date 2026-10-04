import 'dart:typed_data';

/// Readings the band stores in its own memory while the phone is away
/// (TZ §5). Record layouts follow the V8 and 2208A SDK parsers, which are
/// identical for these commands.
enum BodyMetric {
  heartRate('heart_rate'),
  hrv('hrv'),
  spo2('spo2'),
  temperature('temperature'),
  stress('stress');

  const BodyMetric(this.apiName);

  /// Kind name accepted by `POST /api/measurements/samples`.
  final String apiName;
}

class BodySample {
  const BodySample(this.metric, this.at, this.value);

  final BodyMetric metric;
  final DateTime at;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is BodySample &&
      other.metric == metric &&
      other.at == at &&
      other.value == value;

  @override
  int get hashCode => Object.hash(metric, at, value);
}

/// One day of totals as the band keeps them (command 0x51).
class DailyActivity {
  const DailyActivity({
    required this.date,
    required this.steps,
    required this.activeMinutes,
    required this.distanceKm,
    required this.calories,
  });

  final DateTime date;
  final int steps;
  final int activeMinutes;
  final double distanceKm;
  final double calories;
}

/// Request builders and parsers for the band's history commands.
///
/// Every history command also has a mode 0x99 that *erases* that data on the
/// band. It is deliberately not representable here: [request] only builds
/// "read from latest" (0) and "continue" (2).
class BandHistory {
  BandHistory._();

  static const cmdDailyTotals = 0x51;
  static const cmdDynamicHeartRate = 0x54;
  static const cmdStaticHeartRate = 0x55;
  static const cmdHrv = 0x56;
  static const cmdTemperature = 0x62;
  static const cmdSpo2 = 0x66;

  /// Order of a sync session: totals first (small), then the dense streams.
  static const commands = [
    cmdDailyTotals,
    cmdDynamicHeartRate,
    cmdStaticHeartRate,
    cmdHrv,
    cmdSpo2,
    cmdTemperature,
  ];

  static bool isHistoryCommand(int cmd) => commands.contains(cmd);

  static const modeReadLatest = 0x00;
  static const modeContinue = 0x02;

  /// Payload for a history read; never the erasing mode.
  static List<int> request({bool continuation = false}) => [
    continuation ? modeContinue : modeReadLatest,
  ];

  /// The band asks for a continuation request after this many notifications
  /// (both vendor demos send mode 2 at 50).
  static const pageNotifications = 50;

  /// A stream ends with a notification whose last two bytes are
  /// `<cmd> 0xFF`, possibly appended to a final batch of records.
  static bool isEnd(int cmd, Uint8List data) =>
      data.length >= 2 && data[data.length - 2] == cmd && data.last == 0xFF;

  // ── Auto measurement (0x2A) ─────────────────────────────────────────────

  static const cmdSetAutoMeasurement = 0x2A;

  /// SDK `AutoMode` values.
  static const autoHeartRate = 1;
  static const autoSpo2 = 2;
  static const autoTemperature = 3;
  static const autoHrv = 4;

  /// Interval mode, all day, every day — so the band keeps recording into its
  /// own memory when the phone is not around. Times are BCD as in the SDK's
  /// `SetAutomaticHRMonitoring`.
  static List<int> autoMeasurementPayload({
    required int type,
    required int intervalMinutes,
    bool enabled = true,
  }) => [
    enabled ? 2 : 0, // 0 off, 1 continuous, 2 interval
    0x00, 0x00, // start 00:00
    0x23, 0x59, // end 23:59
    0x7F, // Monday..Sunday
    intervalMinutes & 0xFF,
    (intervalMinutes >> 8) & 0xFF,
    type,
  ];

  // ── Parsing ─────────────────────────────────────────────────────────────

  static const _dynamicHrRecord = 24;
  static const _staticHrRecord = 10;
  static const _hrvRecord = 15;
  static const _spo2Record = 10;
  static const _temperatureRecord = 11;

  /// Values in a dynamic heart-rate record, one per minute from its stamp.
  static const dynamicHrValuesPerRecord = 15;

  static List<BodySample> parse(int cmd, Iterable<Uint8List> packets) {
    final samples = <BodySample>[];
    for (final packet in packets) {
      switch (cmd) {
        case cmdDynamicHeartRate:
          for (final r in _records(cmd, packet, _dynamicHrRecord)) {
            final start = _stamp(r, 3);
            if (start == null) continue;
            for (var i = 0; i < dynamicHrValuesPerRecord; i++) {
              _add(
                samples,
                BodyMetric.heartRate,
                start.add(Duration(minutes: i)),
                r[9 + i].toDouble(),
              );
            }
          }
        case cmdStaticHeartRate:
          for (final r in _records(cmd, packet, _staticHrRecord)) {
            final at = _stamp(r, 3);
            if (at != null) {
              _add(samples, BodyMetric.heartRate, at, r[9].toDouble());
            }
          }
        case cmdHrv:
          for (final r in _records(cmd, packet, _hrvRecord)) {
            final at = _stamp(r, 3);
            if (at == null) continue;
            _add(samples, BodyMetric.hrv, at, r[9].toDouble());
            _add(samples, BodyMetric.heartRate, at, r[11].toDouble());
            _add(samples, BodyMetric.stress, at, r[12].toDouble());
          }
        case cmdSpo2:
          for (final r in _records(cmd, packet, _spo2Record)) {
            final at = _stamp(r, 3);
            if (at != null) _add(samples, BodyMetric.spo2, at, r[9].toDouble());
          }
        case cmdTemperature:
          for (final r in _records(cmd, packet, _temperatureRecord)) {
            final at = _stamp(r, 3);
            if (at == null) continue;
            final raw = r[9] | (r[10] << 8);
            _add(samples, BodyMetric.temperature, at, raw / 10.0);
          }
      }
    }
    return samples;
  }

  /// Daily totals (0x51). Records are 26 or 27 bytes depending on firmware;
  /// the SDK infers the size from the notification length.
  static List<DailyActivity> parseDailyTotals(Iterable<Uint8List> packets) {
    final days = <DailyActivity>[];
    for (final packet in packets) {
      final body = _body(cmdDailyTotals, packet);
      if (body == null) continue;
      final size = body.length % 26 == 0
          ? 26
          : body.length % 27 == 0
          ? 27
          : 0;
      if (size == 0) continue;
      for (var o = 0; o + size <= body.length; o += size) {
        if (body[o] != cmdDailyTotals) continue;
        final date = _date(body, o + 2);
        if (date == null) continue;
        final distance = _u32(body, o + 13) / 100.0; // km
        final calories = _u32(body, o + 17) / 100.0; // kcal
        days.add(
          DailyActivity(
            date: date,
            steps: _u32(body, o + 5),
            activeMinutes: _u32(body, o + 9),
            distanceKm: distance,
            calories: calories,
          ),
        );
      }
    }
    return days;
  }

  /// Plausibility bounds; anything outside is a sensor gap, not a reading.
  static bool isPlausible(BodyMetric metric, double v) => switch (metric) {
    BodyMetric.heartRate => v >= 30 && v <= 240,
    BodyMetric.hrv => v >= 1 && v <= 300,
    BodyMetric.spo2 => v >= 70 && v <= 100,
    BodyMetric.temperature => v >= 25 && v <= 45,
    BodyMetric.stress => v >= 1 && v <= 100,
  };

  static void _add(
    List<BodySample> out,
    BodyMetric metric,
    DateTime at,
    double value,
  ) {
    if (isPlausible(metric, value)) out.add(BodySample(metric, at, value));
  }

  /// Packet without the `<cmd> FF` end suffix, or null for a bare end marker.
  static Uint8List? _body(int cmd, Uint8List packet) {
    if (packet.isEmpty || packet[0] != cmd) return null;
    final body = isEnd(cmd, packet)
        ? Uint8List.sublistView(packet, 0, packet.length - 2)
        : packet;
    return body.isEmpty ? null : body;
  }

  static Iterable<Uint8List> _records(
    int cmd,
    Uint8List packet,
    int size,
  ) sync* {
    final body = _body(cmd, packet);
    if (body == null || body.length % size != 0) return;
    for (var o = 0; o < body.length; o += size) {
      if (body[o] == cmd) yield Uint8List.sublistView(body, o, o + size);
    }
  }

  static int _u32(Uint8List b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  static bool _isBcd(int b) => (b & 0x0F) <= 9 && ((b >> 4) & 0x0F) <= 9;

  static int _bcd(int b) => ((b >> 4) & 0x0F) * 10 + (b & 0x0F);

  static DateTime? _date(Uint8List b, int o) {
    for (var i = o; i < o + 3; i++) {
      if (!_isBcd(b[i])) return null;
    }
    final y = 2000 + _bcd(b[o]);
    final m = _bcd(b[o + 1]);
    final d = _bcd(b[o + 2]);
    final date = DateTime(y, m, d);
    return date.month == m && date.day == d ? date : null;
  }

  /// BCD `YY MM DD HH mm SS` at [o], validated.
  static DateTime? _stamp(Uint8List b, int o) {
    for (var i = o; i < o + 6; i++) {
      if (!_isBcd(b[i])) return null;
    }
    final date = _date(b, o);
    final h = _bcd(b[o + 3]);
    final mi = _bcd(b[o + 4]);
    final s = _bcd(b[o + 5]);
    if (date == null || h > 23 || mi > 59 || s > 59) return null;
    return DateTime(date.year, date.month, date.day, h, mi, s);
  }
}
