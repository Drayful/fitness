import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sleep_model.dart';
import 'v8_protocol.dart';
import 'workout_model.dart';

class _StreamCollector {
  final packets = <Uint8List>[];
  final completer = Completer<List<Uint8List>>();
}

enum BandConnectionState { idle, scanning, connecting, connected, error }

class ScannedBand {
  const ScannedBand({
    required this.device,
    required this.name,
    required this.rssi,
    required this.hasV8Service,
    required this.likelyBand,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;
  final bool hasV8Service;
  final bool likelyBand;
}

class BandDeviceInfo {
  const BandDeviceInfo({
    required this.name,
    required this.mac,
    required this.batteryPercent,
    required this.isCharging,
    required this.firmware,
  });

  final String name;
  final String mac;
  final int batteryPercent;
  final bool isCharging;
  final String firmware;
}

class V8BandService extends ChangeNotifier {
  BandConnectionState state = BandConnectionState.idle;
  String? statusMessage;
  final List<ScannedBand> scanResults = [];
  BandDeviceInfo? deviceInfo;
  List<String> lastDiscoveredServices = [];
  String? lastConnectDeviceName;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _tx;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  final Map<int, Completer<Uint8List>> _pending = {};
  final Map<int, _StreamCollector> _streamCollectors = {};
  bool _ready = false;
  bool jcv8OnlyFilter = false;
  bool isLiveHrActive = false;
  LiveVitals? liveVitals;
  String? liveHrStatus;
  SleepSummary? sleepSummary;
  bool isSleepSyncing = false;

  // ── Workout / exercise state ──
  ExerciseType? activeExerciseType;
  DateTime? workoutStartTime;
  bool isWorkoutActive = false;
  bool isWorkoutPaused = false;
  WorkoutLive? workoutLive;
  bool workoutEndedByDevice = false;
  int? workoutInactiveWarning;
  final List<WorkoutSummary> workoutHistory = [];

  bool get isConnected => state == BandConnectionState.connected;

  List<ScannedBand> get visibleScanResults {
    if (!jcv8OnlyFilter) return scanResults;
    return scanResults.where((d) => d.likelyBand).toList();
  }

  void setJcv8OnlyFilter(bool value) {
    jcv8OnlyFilter = value;
    notifyListeners();
  }

  static bool _isLikelyBand(String name, bool hasV8Service) {
    if (hasV8Service) return true;
    final n = name.toLowerCase();
    const hints = [
      'jcv8',
      'v8',
      'band',
      'ring',
      'bracelet',
      'youhong',
      'smart',
      'watch',
    ];
    return hints.any(n.contains);
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];
    if (Platform.isAndroid) {
      permissions.add(Permission.locationWhenInUse);
    }
    await permissions.request();
  }

  Future<void> startScan() async {
    await requestPermissions();
    await FlutterBluePlus.stopScan();
    scanResults.clear();
    statusMessage = 'Scanning for nearby Bluetooth devices...';
    state = BandConnectionState.scanning;
    notifyListeners();

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      scanResults
        ..clear()
        ..addAll(
          results.map((r) {
            final advertised = r.advertisementData.serviceUuids
                .map((g) => g.str.toLowerCase())
                .contains(V8Protocol.serviceUuid);
            final name = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : r.device.remoteId.str;
            return ScannedBand(
              device: r.device,
              name: name,
              rssi: r.rssi,
              hasV8Service: advertised,
              likelyBand: _isLikelyBand(name, advertised),
            );
          }),
        );
      scanResults.sort((a, b) {
        final byLikely = (b.likelyBand ? 1 : 0) - (a.likelyBand ? 1 : 0);
        if (byLikely != 0) return byLikely;
        return b.rssi.compareTo(a.rssi);
      });
      notifyListeners();
    });

    // Do not use withServices: many JCV8 bands expose FFF0 only after connect.
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));

    await Future<void>.delayed(const Duration(seconds: 12));
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (state == BandConnectionState.scanning) {
      state = BandConnectionState.idle;
      statusMessage = scanResults.isEmpty
          ? 'No devices found. Keep the bracelet near the phone.'
          : jcv8OnlyFilter && visibleScanResults.isEmpty
              ? 'No likely bracelets in filter. Turn off "Likely bands only".'
              : 'Found ${visibleScanResults.isEmpty ? scanResults.length : visibleScanResults.length} device(s). Tap one to connect.';
      notifyListeners();
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    lastDiscoveredServices = [];
    lastConnectDeviceName = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;
    state = BandConnectionState.connecting;
    statusMessage = 'Connecting to $lastConnectDeviceName...';
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      _connectionSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _handleDisconnect('Bracelet disconnected');
        }
      });

      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        await device.requestMtu(153);
      } catch (_) {
        // Some phones reject MTU negotiation; continue anyway.
      }

      final services = await _discoverServicesWithRetry(device);
      lastDiscoveredServices = services.map((s) => s.uuid.str).toList();
      notifyListeners();

      BluetoothService? v8Service;
      for (final s in services) {
        if (V8Protocol.uuidMatches(s.uuid.str, V8Protocol.serviceUuid)) {
          v8Service = s;
          break;
        }
      }
      if (v8Service == null) {
        final found = lastDiscoveredServices
            .map(V8Protocol.shortLabel)
            .toSet()
            .join(', ');
        throw StateError(
          'Service FFF0 not found. This is probably not your JCV8 band. '
          'Services on device: ${found.isEmpty ? 'none' : found}',
        );
      }

      BluetoothCharacteristic? tx;
      BluetoothCharacteristic? rx;
      for (final c in v8Service.characteristics) {
        if (V8Protocol.uuidMatches(c.uuid.str, V8Protocol.txUuid)) tx = c;
        if (V8Protocol.uuidMatches(c.uuid.str, V8Protocol.rxUuid)) rx = c;
      }
      if (tx == null) throw StateError('TX characteristic FFF6 not found');
      if (rx == null) throw StateError('RX characteristic FFF7 not found');
      _tx = tx;

      await rx.setNotifyValue(true);
      _notifySub = rx.onValueReceived.listen(_onNotify);

      _ready = true;
      statusMessage = 'Connected. Reading device info...';
      notifyListeners();

      await _syncBasics(device);
      state = BandConnectionState.connected;
      statusMessage = 'Connected and synced';
      notifyListeners();

      // Auto-start live metrics and sleep sync after a short stabilization delay.
      Future<void>.delayed(const Duration(milliseconds: 400)).then((_) async {
        if (!_ready) return;
        try {
          await startLiveHeartRate();
        } catch (_) {}
      });
      Future<void>.delayed(const Duration(seconds: 2)).then((_) async {
        if (!_ready) return;
        try {
          await syncSleepData();
        } catch (_) {}
      });
    } catch (e) {
      state = BandConnectionState.error;
      statusMessage = 'Connection failed: $e';
      notifyListeners();
      await disconnect();
    }
  }

  Future<List<BluetoothService>> _discoverServicesWithRetry(
    BluetoothDevice device,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (attempt > 0) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        }
        return await device.discoverServices();
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('Service discovery failed: $lastError');
  }

  Future<void> _syncBasics(BluetoothDevice device) async {
    final now = DateTime.now();
    await sendCommand(
      V8Protocol.cmdSetTime,
      V8Protocol.setTimePayload(now),
    );

    final battery = await sendCommand(V8Protocol.cmdBattery);
    final mac = await sendCommand(V8Protocol.cmdMac);
    final firmware = await sendCommand(V8Protocol.cmdFirmware);

    final phoneMac = device.remoteId.str;
    deviceInfo = BandDeviceInfo(
      name: device.platformName.isNotEmpty ? device.platformName : 'JCV8',
      mac: V8Protocol.parseMac(mac) ?? phoneMac,
      batteryPercent: V8Protocol.parseBatteryPercent(battery) ?? 0,
      isCharging: battery.length > 2 && battery[2] == 1,
      firmware: V8Protocol.parseFirmware(firmware) ?? 'unknown',
    );
    notifyListeners();
  }

  Future<void> startLiveHeartRate() async {
    if (!_ready) throw StateError('Bracelet is not connected');

    liveHrStatus = 'Starting heart rate measurement...';
    notifyListeners();

    await sendCommand(
      V8Protocol.cmdMeasure,
      V8Protocol.measurePayload(
        mode: V8Protocol.measureHeartRate,
        start: true,
        durationSec: 60,
      ),
    );
    await sendCommand(
      V8Protocol.cmdMeasure,
      V8Protocol.measurePayload(
        mode: V8Protocol.measureSpO2,
        start: true,
        durationSec: 60,
      ),
    );
    await sendCommand(V8Protocol.cmdRealtime, const [0x01]);

    isLiveHrActive = true;
    liveVitals = null;
    liveHrStatus = 'Measuring... keep the band on your wrist, stay still.';
    notifyListeners();
  }

  Future<void> stopLiveHeartRate() async {
    if (!_ready) return;

    isLiveHrActive = false;
    liveHrStatus = 'Stopping measurement...';
    notifyListeners();

    try {
      await sendCommand(
        V8Protocol.cmdMeasure,
        V8Protocol.measurePayload(
          mode: V8Protocol.measureHeartRate,
          start: false,
        ),
      );
      await sendCommand(V8Protocol.cmdRealtime, const [0x00]);
    } catch (_) {
      // Best-effort stop.
    }

    liveHrStatus = null;
    notifyListeners();
  }

  /// Sends a command that returns a variable number of BLE notifications,
  /// terminated by a packet where byte[1] == 0xFF.
  Future<List<Uint8List>> sendStreamCommand(
    int command, [
    List<int> payload = const [],
  ]) async {
    if (!_ready || _tx == null) throw StateError('Bracelet is not ready');
    final cmd = command & 0x7F;
    final collector = _StreamCollector();
    _streamCollectors[cmd] = collector;
    final packet = V8Protocol.buildPacket(command, payload);
    await _tx!.write(packet, withoutResponse: false);
    return collector.completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _streamCollectors.remove(cmd);
        throw TimeoutException(
          'Timeout reading stream 0x${command.toRadixString(16)}',
        );
      },
    );
  }

  Future<void> syncSleepData() async {
    if (!_ready) return;
    isSleepSyncing = true;
    notifyListeners();
    try {
      final packets = await sendStreamCommand(V8Protocol.cmdSleep, [0x00]);
      final records = packets
          .map(V8Protocol.parseSleepRecord)
          .whereType<SleepRecord>()
          .toList();
      sleepSummary = SleepSummary.fromRecords(records);
    } catch (_) {
      sleepSummary ??= const SleepSummary.empty();
    } finally {
      isSleepSyncing = false;
      notifyListeners();
    }
  }

  Future<Uint8List> sendCommand(int command, [List<int> payload = const []]) async {
    if (!_ready || _tx == null) {
      throw StateError('Bracelet is not ready');
    }

    final packet = V8Protocol.buildPacket(command, payload);
    final completer = Completer<Uint8List>();
    _pending[command & 0x7F] = completer;

    await _tx!.write(packet, withoutResponse: false);

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _pending.remove(command & 0x7F);
        throw TimeoutException('No response for command 0x${command.toRadixString(16)}');
      },
    );
  }

  void _onNotify(List<int> data) {
    if (data.isEmpty) return;
    final bytes = Uint8List.fromList(data);
    final cmd = bytes[0] & 0x7F;

    // Exercise live packets (0x18) — handled before any other check.
    if (cmd == V8Protocol.cmdExerciseLive) {
      _handleExercisePacket(bytes);
      return;
    }

    // Live vitals stream (0x09 packets).
    if (isLiveHrActive && cmd == V8Protocol.cmdRealtime && bytes.length >= 25) {
      final vitals = V8Protocol.parseLivePacket(bytes);
      if (vitals != null) {
        liveVitals = vitals;
        liveHrStatus = vitals.heartRate != null
            ? 'Live heart rate'
            : 'Waiting for heart rate... stay still';
        notifyListeners();
      }
      return;
    }

    // Multi-packet stream commands (sleep, etc.).
    final collector = _streamCollectors[cmd];
    if (collector != null) {
      final isEnd = bytes.length >= 2 && bytes[1] == 0xFF;
      final isError = (bytes[0] & 0x80) != 0;
      if (isEnd || isError) {
        _streamCollectors.remove(cmd);
        if (!collector.completer.isCompleted) {
          collector.completer.complete(collector.packets);
        }
      } else {
        collector.packets.add(bytes);
      }
      return;
    }

    // Single-response commands.
    final completer = _pending.remove(cmd);
    completer?.complete(bytes);
  }

  // ── Workout control ─────────────────────────────────────────────────────────

  Future<bool> startWorkout(ExerciseType type) async {
    if (!_ready) return false;
    // Stop live HR stream to avoid 0x09/0x18 packet conflicts during exercise.
    if (isLiveHrActive) {
      try {
        await stopLiveHeartRate();
      } catch (_) {}
    }
    try {
      final response = await sendCommand(V8Protocol.cmdExercise, [
        V8Protocol.exerciseStart,
        type.bandCode,
        0,
        0,
      ]);
      final success = response.length >= 2 && response[1] == 1;
      if (success) {
        activeExerciseType = type;
        workoutStartTime = DateTime.now();
        isWorkoutActive = true;
        isWorkoutPaused = false;
        workoutLive = null;
        workoutEndedByDevice = false;
        workoutInactiveWarning = null;
        notifyListeners();
      }
      return success;
    } catch (_) {
      // Restart live metrics if start failed.
      Future<void>.delayed(const Duration(milliseconds: 300)).then((_) async {
        if (_ready && !isWorkoutActive) {
          try {
            await startLiveHeartRate();
          } catch (_) {}
        }
      });
      return false;
    }
  }

  Future<void> pauseWorkout() async {
    if (!_ready || !isWorkoutActive || isWorkoutPaused) return;
    try {
      await sendCommand(V8Protocol.cmdExercise,
          [V8Protocol.exercisePause, 0, 0, 0]);
      isWorkoutPaused = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> resumeWorkout() async {
    if (!_ready || !isWorkoutActive || !isWorkoutPaused) return;
    try {
      await sendCommand(V8Protocol.cmdExercise,
          [V8Protocol.exerciseResume, 0, 0, 0]);
      isWorkoutPaused = false;
      notifyListeners();
    } catch (_) {}
  }

  /// Ends the active workout, saves to history, restarts live metrics.
  /// Returns the saved [WorkoutSummary] or null if no live data was captured.
  Future<WorkoutSummary?> endWorkout() async {
    WorkoutSummary? summary;
    if (workoutLive != null && activeExerciseType != null) {
      summary = WorkoutSummary.fromLive(
        activeExerciseType!,
        workoutStartTime ?? DateTime.now(),
        workoutLive!,
      );
      workoutHistory.insert(0, summary);
      if (workoutHistory.length > 20) workoutHistory.removeLast();
    }
    if (_ready) {
      try {
        await sendCommand(
            V8Protocol.cmdExercise, [V8Protocol.exerciseEnd, 0, 0, 0]);
      } catch (_) {}
    }
    _clearWorkoutState();
    // Restart live metrics after a brief delay.
    Future<void>.delayed(const Duration(milliseconds: 600)).then((_) async {
      if (_ready && !isWorkoutActive) {
        try {
          await startLiveHeartRate();
        } catch (_) {}
      }
    });
    return summary;
  }

  void clearWorkoutWarning() {
    workoutInactiveWarning = null;
    notifyListeners();
  }

  void _clearWorkoutState() {
    isWorkoutActive = false;
    isWorkoutPaused = false;
    workoutEndedByDevice = false;
    workoutInactiveWarning = null;
    workoutLive = null;
    notifyListeners();
  }

  void _handleExercisePacket(Uint8List bytes) {
    if (V8Protocol.isExerciseEnded(bytes)) {
      if (isWorkoutActive) {
        if (workoutLive != null && activeExerciseType != null) {
          final summary = WorkoutSummary.fromLive(
            activeExerciseType!,
            workoutStartTime ?? DateTime.now(),
            workoutLive!,
          );
          workoutHistory.insert(0, summary);
          if (workoutHistory.length > 20) workoutHistory.removeLast();
        }
        workoutEndedByDevice = true;
        isWorkoutActive = false;
        isWorkoutPaused = false;
        notifyListeners();
        // Restart live metrics.
        Future<void>.delayed(const Duration(milliseconds: 600)).then((_) async {
          if (_ready && !isWorkoutActive) {
            try {
              await startLiveHeartRate();
            } catch (_) {}
          }
        });
      }
      return;
    }

    final warning = V8Protocol.exerciseInactiveWarning(bytes);
    if (warning != null) {
      workoutInactiveWarning = warning;
      notifyListeners();
      return;
    }

    if (isWorkoutActive && !isWorkoutPaused) {
      final live = V8Protocol.parseExerciseLive(bytes);
      if (live != null) {
        workoutLive = live;
        notifyListeners();
      }
    }
  }

  void _handleDisconnect(String message) {
    _ready = false;
    isLiveHrActive = false;
    liveVitals = null;
    liveHrStatus = null;
    deviceInfo = null;
    sleepSummary = null;
    isSleepSyncing = false;
    isWorkoutActive = false;
    isWorkoutPaused = false;
    workoutLive = null;
    workoutEndedByDevice = false;
    workoutInactiveWarning = null;
    for (final c in _streamCollectors.values) {
      if (!c.completer.isCompleted) {
        c.completer.completeError(StateError('Disconnected'));
      }
    }
    _streamCollectors.clear();
    state = BandConnectionState.idle;
    statusMessage = message;
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (isLiveHrActive) {
      await stopLiveHeartRate();
    }
    _ready = false;
    await _notifySub?.cancel();
    _notifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('Disconnected'));
      }
    }
    _pending.clear();
    _tx = null;

    final device = _device;
    _device = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    deviceInfo = null;
    isLiveHrActive = false;
    liveVitals = null;
    liveHrStatus = null;
    sleepSummary = null;
    isSleepSyncing = false;
    isWorkoutActive = false;
    isWorkoutPaused = false;
    workoutLive = null;
    workoutEndedByDevice = false;
    workoutInactiveWarning = null;
    for (final c in _streamCollectors.values) {
      if (!c.completer.isCompleted) c.completer.completeError(StateError('Disconnected'));
    }
    _streamCollectors.clear();
    if (state != BandConnectionState.error) {
      state = BandConnectionState.idle;
      statusMessage = 'Disconnected';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    disconnect();
    super.dispose();
  }
}
