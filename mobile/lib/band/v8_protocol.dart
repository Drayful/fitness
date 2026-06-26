import 'dart:typed_data';

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
