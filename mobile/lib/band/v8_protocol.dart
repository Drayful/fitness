import 'dart:typed_data';

import 'band_variant.dart';
import 'sleep_model.dart';
import 'workout_model.dart';

/// BLE protocol helpers for JStyle-family bracelets.
///
/// Covers two supplied SDK families that share the same GATT profile, the same
/// 16-byte framing and the same command codes, but differ in a few payload
/// encodings — see [BandVariant].
class V8Protocol {
  V8Protocol._();

  static const serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const txUuid = '0000fff6-0000-1000-8000-00805f9b34fb';
  static const rxUuid = '0000fff7-0000-1000-8000-00805f9b34fb';

  static const cmdSetTime = 0x01;
  static const cmdGetTime = 0x41;
  static const cmdBattery = 0x13;
  static const cmdMac = 0x22;
  static const cmdFirmware = 0x27;
  static const cmdRealtime = 0x09;
  static const cmdMeasure = 0x28;
  static const cmdTotalSteps = 0x51;

  static const measureHeartRate = 0x02;
  static const measureSpO2 = 0x03;

  static const cmdSleep = 0x53;

  static const cmdExercise = 0x19;
  static const cmdExerciseLive = 0x18;

  /// Phone-to-band workout heartbeat available in both supplied SDKs.
  static const cmdWorkoutHeartbeat = 0x17;

  static const exerciseStart = 1;
  static const exercisePause = 2;
  static const exerciseResume = 3;
  static const exerciseEnd = 4;

  /// Fixed record size of a 2208A 0x53 sleep entry; several are packed into a
  /// single notification.
  static const _sleep2208RecordBytes = 34;

  /// 2208A packs one two-hour block per record: either 24 slots of 5 minutes
  /// (34-byte form) or 120 slots of 1 minute (130-byte form).
  static const _sleep2208LongPacketBytes = 130;

  static Uint8List buildPacket(int command, [List<int> payload = const []]) {
    final packet = Uint8List(16);
    packet[0] = command & 0x7F;
    for (var i = 0; i < 14; i++) {
      packet[i + 1] = i < payload.length ? payload[i] & 0xFF : 0;
    }
    var sum = 0;
    for (var i = 0; i < 15; i++) {
      sum += packet[i];
    }
    packet[15] = sum & 0xFF;
    return packet;
  }

  static bool isSuccess(Uint8List response, int command) {
    if (response.isEmpty) return false;
    return response[0] == command;
  }

  static int _toBcd(int value) => ((value ~/ 10) << 4) | (value % 10);

  static int _fromBcd(int byte) => ((byte >> 4) & 0x0F) * 10 + (byte & 0x0F);

  /// Validate BCD digits before decoding a timestamp.
  static bool _isBcd(int byte) =>
      (byte & 0x0F) <= 9 && ((byte >> 4) & 0x0F) <= 9;

  /// Builds the 0x01 payload. Both supplied SDKs take BCD plus a whole-hour timezone byte at payload index 7.
  static Uint8List setTimePayload(DateTime time, BandVariant variant) {
    final offsetHours = time.timeZoneOffset.inHours;
    final zone = offsetHours >= 0 ? (0x80 | offsetHours) : -offsetHours;
    return Uint8List.fromList([
      _toBcd(time.year % 100),
      _toBcd(time.month),
      _toBcd(time.day),
      _toBcd(time.hour),
      _toBcd(time.minute),
      _toBcd(time.second),
      0,
      zone & 0xFF,
    ]);
  }

  /// Decode the shared BCD date format; this cannot identify the model.
  static DateTime? parseDeviceTime(Uint8List response, BandVariant variant) {
    if (!isSuccess(response, cmdGetTime) || response.length < 7) return null;

    for (var i = 1; i <= 6; i++) {
      if (!_isBcd(response[i])) return null;
    }

    int decode(int b) => _fromBcd(b);
    final yy = decode(response[1]);
    final mo = decode(response[2]);
    final dd = decode(response[3]);
    final hh = decode(response[4]);
    final mi = decode(response[5]);
    final ss = decode(response[6]);

    if (yy > 99 || mo < 1 || mo > 12 || dd < 1 || dd > 31) return null;
    if (hh > 23 || mi > 59 || ss > 59) return null;
    final date = DateTime(2000 + yy, mo, dd, hh, mi, ss);
    return date.month == mo && date.day == dd ? date : null;
  }

  static int? parseBatteryPercent(Uint8List response) {
    if (!isSuccess(response, cmdBattery) || response.length < 2) return null;
    return response[1] <= 100 ? response[1] : null;
  }

  static String? parseMac(Uint8List response) {
    if (!isSuccess(response, cmdMac) || response.length < 7) return null;
    final parts = <String>[];
    for (var i = 1; i <= 6; i++) {
      parts.add(response[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return parts.join(':');
  }

  /// Both SDKs expose four version bytes; no undocumented build date.
  static String? parseFirmware(Uint8List response) {
    if (!isSuccess(response, cmdFirmware) || response.length < 5) return null;
    final version = response
        .sublist(1, 5)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('.');

    return version;
  }

  /// Matches full UUID strings and short BLE forms like `fff0`.
  static bool uuidMatches(String actual, String expectedFull) {
    final a = actual.toLowerCase();
    final e = expectedFull.toLowerCase();
    if (a == e) return true;

    if (!RegExp(r'^0000[0-9a-f]{4}-0000-1000-8000-00805f9b34fb$').hasMatch(e)) {
      return false;
    }
    return a == e.substring(4, 8) || a == e.substring(0, 8);
  }

  static String shortLabel(String uuid) {
    final u = uuid.toLowerCase();
    if (u.length <= 8) return u;
    if (u.startsWith('0000') && u.length >= 8) {
      return u.substring(4, 8);
    }
    return u;
  }

  /// Both SDKs terminate sleep history with the exact suffix 0x53 0xFF.
  /// The final notification may also contain records.
  static bool isStreamEnd(Uint8List data, BandVariant variant) {
    return data.length >= 2 &&
        data[0] == cmdSleep &&
        data[data.length - 2] == cmdSleep &&
        data.last == 0xFF;
  }

  /// Decodes every sleep record contained in [packets].
  static List<SleepRecord> parseSleepPackets(
    Iterable<Uint8List> packets,
    BandVariant variant,
  ) {
    final records = <SleepRecord>[];
    for (final packet in packets) {
      records.addAll(_parse2208SleepPacket(packet));
    }
    return records;
  }

  /// Splits a 2208A 0x53 notification into records.
  ///
  /// A notification holds either one 130-byte record of 1-minute slots, or a
  /// run of 34-byte records of 5-minute slots. The header is the same in both
  /// forms: 0x53 ID1 ID2 YY MM DD HH mm SS LEN, with dates in BCD.
  static List<SleepRecord> _parse2208SleepPacket(Uint8List data) {
    if (data.length < 11) return const [];
    if (data[0] != cmdSleep) return const [];

    if (isStreamEnd(data, BandVariant.jc2208a)) {
      data = Uint8List.sublistView(data, 0, data.length - 2);
    }
    if (data.length == _sleep2208LongPacketBytes) {
      final record = _parse2208SleepRecord(data, 0, data.length, 1);
      return record == null ? const [] : [record];
    }

    if (data.length % _sleep2208RecordBytes != 0) return const [];
    final count = data.length ~/ _sleep2208RecordBytes;
    if (count == 0) return const [];

    final records = <SleepRecord>[];
    for (var i = 0; i < count; i++) {
      final record = _parse2208SleepRecord(
        data,
        i * _sleep2208RecordBytes,
        _sleep2208RecordBytes,
        5,
      );
      if (record != null) records.add(record);
    }
    return records;
  }

  static SleepRecord? _parse2208SleepRecord(
    Uint8List data,
    int offset,
    int recordBytes,
    int unitMinutes,
  ) {
    if (offset + 11 > data.length) return null;
    if (data[offset] != cmdSleep) return null;
    for (var i = 3; i <= 8; i++) {
      if (!_isBcd(data[offset + i])) return null;
    }

    final yy = _fromBcd(data[offset + 3]);
    final mo = _fromBcd(data[offset + 4]);
    final dd = _fromBcd(data[offset + 5]);
    final hh = _fromBcd(data[offset + 6]);
    final mn = _fromBcd(data[offset + 7]);
    final ss = _fromBcd(data[offset + 8]);
    final len = data[offset + 9];

    if (len == 0 || yy > 99) return null;
    if (mo < 1 || mo > 12 || dd < 1 || dd > 31) return null;
    if (hh > 23 || mn > 59 || ss > 59) return null;

    final available = data.length - offset - 10;
    final capacity = recordBytes - 10;
    final maxSlots = available < capacity ? available : capacity;
    if (len > maxSlots) return null;
    final date = DateTime(2000 + yy, mo, dd, hh, mn, ss);
    if (date.month != mo || date.day != dd) return null;
    final slots = len;
    if (slots <= 0) return null;

    final stages = List<SleepStage>.filled(slots, SleepStage.unknown);

    return SleepRecord(
      start: DateTime(2000 + yy, mo, dd, hh, mn, ss),
      stages: stages,
      rawValues: List<int>.unmodifiable(
        data.sublist(offset + 10, offset + 10 + slots),
      ),
      unitMinutes: unitMinutes,
    );
  }

  /// Parses a 0x18 real-time exercise packet.
  ///
  /// V8 carries elapsed time in bytes 10..13 and no distance;
  /// 2208A sends the 16-byte common frame with heart rate, steps and calories
  /// only, and expects the phone to track duration and distance itself.
  /// Returns null for end/warning packets — check [isExerciseEnded] and
  /// [exerciseInactiveWarning] separately.
  static WorkoutLive? parseExerciseLive(
    Uint8List data, [
    BandVariant variant = BandVariant.legacyV8,
  ]) {
    if (data.length < 16) return null;
    if (data[0] != cmdExerciseLive) return null;
    if (data[1] == 0xFF || data[1] == 0xAA) return null;

    final hr = data[1];
    final steps = data[2] | (data[3] << 8) | (data[4] << 16) | (data[5] << 24);

    final bd = ByteData(4)
      ..setUint8(0, data[6])
      ..setUint8(1, data[7])
      ..setUint8(2, data[8])
      ..setUint8(3, data[9]);
    final cal = bd.getFloat32(0, Endian.little);
    final calories = (cal.isNaN || cal.isInfinite || cal < 0) ? 0.0 : cal;

    if (variant == BandVariant.jc2208a) {
      // 2208A frame: duration and distance are not on the wire.
      return WorkoutLive(
        heartRate: hr,
        steps: steps,
        calories: calories,
        durationSeconds: 0,
        distanceM: 0,
      );
    }

    final dur =
        data[10] | (data[11] << 8) | (data[12] << 16) | (data[13] << 24);

    return WorkoutLive(
      heartRate: hr,
      steps: steps,
      calories: calories,
      durationSeconds: dur,
      distanceM: 0, // Not provided by the supplied V8 SDK.
    );
  }

  /// True when band signals workout ended (HR byte == 0xFF).
  static bool isExerciseEnded(Uint8List data) =>
      data.length >= 2 && data[0] == cmdExerciseLive && data[1] == 0xFF;

  /// Returns inactive warning level (1 = 10 min, 2 = 20 min) or null.
  static int? exerciseInactiveWarning(Uint8List data) {
    if (data.length >= 3 && data[0] == cmdExerciseLive && data[1] == 0xAA) {
      return data[2];
    }
    return null;
  }

  /// Builds the 0x17 workout heartbeat 2208A expects once per second:
  /// distance as a little-endian float in km, then pace as minutes and
  /// seconds, then a satellite/RSSI indicator.
  static Uint8List workoutHeartbeatPayload({
    required double distanceKm,
    required int paceSecondsPerKm,
    int rssi = 2,
  }) {
    final bd = ByteData(4)..setFloat32(0, distanceKm, Endian.little);
    return Uint8List.fromList([
      ...bd.buffer.asUint8List(),
      (paceSecondsPerKm ~/ 60) & 0xFF,
      paceSecondsPerKm % 60,
      rssi & 0xFF,
    ]);
  }

  static String hex(Uint8List data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  /// Builds 0x28 measure command (HR / SpO2 / ECG etc.).
  static Uint8List measurePayload({
    required int mode,
    required bool start,
    int durationSec = 30,
    BandVariant variant = BandVariant.legacyV8,
  }) {
    if (variant == BandVariant.jc2208a) {
      return Uint8List.fromList([mode, start ? 1 : 0]);
    }
    return Uint8List.fromList([
      mode,
      start ? 1 : 0,
      0,
      durationSec & 0xFF,
      (durationSec >> 8) & 0xFF,
    ]);
  }

  /// Builds the 0x09 real-time payload. both supplied SDKs gate temperature behind a second flag.
  static Uint8List realtimePayload({
    required bool enable,
    required BandVariant variant,
  }) {
    return Uint8List.fromList([enable ? 1 : 0, enable ? 1 : 0]);
  }

  /// Parses streaming 0x09 packet (31+ bytes, no CRC).
  static LiveVitals? parseLivePacket(Uint8List data) {
    if (data.isEmpty || data[0] != cmdRealtime || data.length < 24) {
      return null;
    }

    final steps = data[1] | (data[2] << 8) | (data[3] << 16) | (data[4] << 24);
    final heartRate = data[21];
    final tempRaw = data[22] | (data[23] << 8);
    final spo2 = data.length > 24 ? data[24] : 0;

    return LiveVitals(
      steps: steps,
      heartRate: heartRate > 0 ? heartRate : null,
      temperatureC: tempRaw > 0 ? tempRaw / 10.0 : null,
      spo2: spo2 > 0 && spo2 <= 100 ? spo2 : null,
    );
  }
}

class LiveVitals {
  const LiveVitals({
    required this.steps,
    this.heartRate,
    this.temperatureC,
    this.spo2,
  });

  final int steps;
  final int? heartRate;
  final double? temperatureC;
  final int? spo2;
}
