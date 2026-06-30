import 'dart:typed_data';

import 'sleep_model.dart';
import 'workout_model.dart';

/// JCV8 bracelet BLE protocol helpers (Youhong V1.0).
class V8Protocol {
  V8Protocol._();

  static const serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const txUuid = '0000fff6-0000-1000-8000-00805f9b34fb';
  static const rxUuid = '0000fff7-0000-1000-8000-00805f9b34fb';

  static const cmdSetTime = 0x01;
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

  static const exerciseStart = 1;
  static const exercisePause = 2;
  static const exerciseResume = 3;
  static const exerciseEnd = 4;

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
    return (response[0] & 0x7F) == (command & 0x7F);
  }

  static Uint8List setTimePayload(DateTime time) {
    return Uint8List.fromList([
      time.year % 100,
      time.month,
      time.day,
      time.hour,
      time.minute,
      time.second,
    ]);
  }

  static int? parseBatteryPercent(Uint8List response) {
    if (!isSuccess(response, cmdBattery) || response.length < 2) return null;
    return response[1];
  }

  static String? parseMac(Uint8List response) {
    if (!isSuccess(response, cmdMac) || response.length < 7) return null;
    final parts = <String>[];
    for (var i = 1; i <= 6; i++) {
      parts.add(response[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return parts.join(':');
  }

  static String? parseFirmware(Uint8List response) {
    if (!isSuccess(response, cmdFirmware) || response.length < 8) return null;
    final version = response
        .sublist(1, 5)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('.');
    final date =
        '20${response[5].toString().padLeft(2, '0')}-'
        '${response[6].toString().padLeft(2, '0')}-'
        '${response[7].toString().padLeft(2, '0')}';
    return '$version ($date)';
  }

  /// Matches full UUID strings and short BLE forms like `fff0`.
  static bool uuidMatches(String actual, String expectedFull) {
    final a = actual.toLowerCase();
    final e = expectedFull.toLowerCase();
    if (a == e) return true;

    final short = e.substring(4, 8); // 0000fff0-... -> fff0
    if (a == short) return true;
    if (a.startsWith('0000$short')) return true;
    return a.contains(short);
  }

  static String shortLabel(String uuid) {
    final u = uuid.toLowerCase();
    if (u.length <= 8) return u;
    if (u.startsWith('0000') && u.length >= 8) {
      return u.substring(4, 8);
    }
    return u;
  }

  /// Parses a single 0x53 sleep record packet.
  /// Format: 0x53 ID1 ID2 YY MM DD HH mm SS LEN SD1..SDn
  /// Each SDn byte: 01=deep, 02=light, 03=rem, else=awake
  static SleepRecord? parseSleepRecord(Uint8List data) {
    if (data.length < 11) return null;
    if ((data[0] & 0x7F) != cmdSleep) return null;
    if (data[1] == 0xFF) return null; // end-of-stream marker

    final yy = data[3];
    final mo = data[4];
    final dd = data[5];
    final hh = data[6];
    final mn = data[7];
    final ss = data[8];
    final len = data[9];

    if (len == 0 || mo < 1 || mo > 12 || dd < 1 || dd > 31) return null;

    final stages = <SleepStage>[];
    for (var i = 0; i < len && (10 + i) < data.length; i++) {
      final v = data[10 + i];
      stages.add(switch (v) {
        1 => SleepStage.deep,
        2 => SleepStage.light,
        3 => SleepStage.rem,
        _ => SleepStage.awake,
      });
    }

    if (stages.isEmpty) return null;
    return SleepRecord(
      start: DateTime(2000 + yy, mo, dd, hh, mn, ss),
      stages: stages,
    );
  }

  /// Parses 0x18 real-time exercise packet (21 bytes, sent ~1/sec by band).
  /// Returns null for end/warning packets — check [isExerciseEnded] and
  /// [exerciseInactiveWarning] separately.
  static WorkoutLive? parseExerciseLive(Uint8List data) {
    if (data.length < 18) return null;
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

    final dur = data[10] | (data[11] << 8) | (data[12] << 16) | (data[13] << 24);
    final distRaw = data[14] | (data[15] << 8) | (data[16] << 16) | (data[17] << 24);

    return WorkoutLive(
      heartRate: hr,
      steps: steps,
      calories: (cal.isNaN || cal.isInfinite) ? 0.0 : cal,
      durationSeconds: dur,
      distanceM: distRaw * 10.0, // unit: 0.01 km → meters
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

  static String hex(Uint8List data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  /// Builds 0x28 measure command (HR / SpO2 / ECG etc.).
  static Uint8List measurePayload({
    required int mode,
    required bool start,
    int durationSec = 30,
  }) {
    return Uint8List.fromList([
      mode,
      start ? 1 : 0,
      0,
      0,
      durationSec & 0xFF,
      (durationSec >> 8) & 0xFF,
    ]);
  }

  /// Parses streaming 0x09 packet (31+ bytes, no CRC).
  static LiveVitals? parseLivePacket(Uint8List data) {
    if (data.isEmpty || (data[0] & 0x7F) != cmdRealtime || data.length < 25) {
      return null;
    }

    final steps = data[1] | (data[2] << 8) | (data[3] << 16) | (data[4] << 24);
    final heartRate = data[21];
    final tempRaw = data[22] | (data[23] << 8);
    final spo2 = data[24];

    return LiveVitals(
      steps: steps,
      heartRate: heartRate > 0 ? heartRate : null,
      temperatureC: tempRaw > 0 ? tempRaw / 10.0 : null,
      spo2: spo2 > 0 ? spo2 : null,
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
