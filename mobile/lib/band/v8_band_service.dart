import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'band_variant.dart';
import 'band_variant_store.dart';
import 'sleep_model.dart';
import 'v8_protocol.dart';
import 'workout_model.dart';

class _StreamCollector {
  final packets = <Uint8List>[];
  int pagePackets = 0;
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
  final int? batteryPercent;
  final bool isCharging;
  final String firmware;
}

class V8BandService extends ChangeNotifier {
  V8BandService({BandVariantStore? variantStore})
    : _variantStore = variantStore ?? BandVariantStore();

  final BandVariantStore _variantStore;
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
  bool _disposed = false;
  int _connectionGeneration = 0;
  bool _startingLive = false;
  final Stopwatch _workoutClock = Stopwatch();
  List<SleepRecord> sleepRecords = const [];
  String? sleepSyncError;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// SDK model selected by the user; time/MTU replies cannot distinguish it.
  BandVariant variant = BandVariant.legacyV8;

  /// True after a model selection, including one recalled for this device.
  bool variantConfirmed = false;

  /// Selection for each connected device, also backed by local persistence.
  final Map<String, BandVariant> _deviceVariants = {};
  BandVariant? get _forcedVariant =>
      _device == null ? null : _deviceVariants[_device!.remoteId.str];
  Timer? _workoutHeartbeat;
  bool jcv8OnlyFilter = false;
  bool isLiveHrActive = false;
  LiveVitals? liveVitals;
  String? liveHrStatus;
  SleepSummary? sleepSummary;
  DateTime? liveVitalsAt;
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

  /// Confirms the SDK family for this device. Passing null clears confirmation.
  Future<void> overrideVariant(BandVariant? value) async {
    if (isWorkoutActive || isSleepSyncing) return;
    final id = _device?.remoteId.str;
    if (id == null) return;
    if (value == null) {
      _deviceVariants.remove(id);
    } else {
      _deviceVariants[id] = value;
    }
    if (value != null) {
      variant = value;
      variantConfirmed = true;
    } else {
      variantConfirmed = false;
    }
    sleepSummary = null;
    sleepRecords = const [];
    notifyListeners();
    await _variantStore.remember(id, deviceInfo?.mac, value);
    if (value != null && _ready) {
      _scheduleSleepSync(_connectionGeneration);
    }
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

    if (Platform.isIOS) {
      await Permission.bluetooth.request();
      return;
    }
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
    await FlutterBluePlus.stopScan();
    await disconnect();
    final generation = ++_connectionGeneration;
    final remoteId = device.remoteId.str;
    final remembered =
        _deviceVariants[remoteId] ??
        await _variantStore.findByRemoteId(remoteId);
    if (generation != _connectionGeneration || _disposed) return;
    if (remembered != null) _deviceVariants[remoteId] = remembered;
    _device = device;
    variant = _forcedVariant ?? BandVariant.legacyV8;
    variantConfirmed = _forcedVariant != null;
    lastDiscoveredServices = [];
    lastConnectDeviceName = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;
    state = BandConnectionState.connecting;
    statusMessage = 'Connecting to $lastConnectDeviceName...';
    notifyListeners();

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      _connectionSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          if (generation == _connectionGeneration) {
            _handleDisconnect('Bracelet disconnected');
          }
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

      _notifySub = rx.onValueReceived.listen(_onNotify);
      await rx.setNotifyValue(true);
      if (generation != _connectionGeneration || _disposed) return;

      _ready = true;
      statusMessage = 'Connected. Reading device info...';
      notifyListeners();

      await _syncBasics(device);
      if (generation != _connectionGeneration || !_ready || _disposed) return;
      state = BandConnectionState.connected;
      statusMessage = variantConfirmed
          ? 'Connected. Model restored; syncing data.'
          : 'Connected. Select the watch model once to sync sleep and train.';
      notifyListeners();

      // Auto-start live metrics and sleep sync after a short stabilization delay.
      Future<void>.delayed(const Duration(milliseconds: 400)).then((_) async {
        if (!_ready || generation != _connectionGeneration) return;
        try {
          await startLiveHeartRate();
        } catch (_) {}
      });
      if (variantConfirmed) _scheduleSleepSync(generation);
    } catch (e) {
      state = BandConnectionState.error;
      statusMessage = 'Connection failed: $e';
      notifyListeners();
      await disconnect();
    }
  }

  void _scheduleSleepSync(int generation) {
    Future<void>.delayed(const Duration(seconds: 2)).then((_) async {
      if (!_ready || generation != _connectionGeneration || !variantConfirmed) {
        return;
      }
      try {
        await syncSleepData();
      } catch (_) {}
    });
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

  /// Both SDKs use BCD and both report MTU in their time acknowledgement.
  /// Neither response can identify a model. Keep an explicit selection or
  /// the unconfirmed V8 default; never silently relabel a connected device.
  Future<void> _syncTimeAndDetectVariant() async {
    variant = _forcedVariant ?? BandVariant.legacyV8;
    variantConfirmed = _forcedVariant != null;
    await _writeDeviceTime();
  }

  Future<Uint8List?> _writeDeviceTime() async {
    try {
      return await sendCommand(
        V8Protocol.cmdSetTime,
        V8Protocol.setTimePayload(DateTime.now(), variant),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncBasics(BluetoothDevice device) async {
    await _syncTimeAndDetectVariant();

    final battery = await sendCommand(V8Protocol.cmdBattery);
    final mac = await sendCommand(V8Protocol.cmdMac);
    final firmware = await sendCommand(V8Protocol.cmdFirmware);

    final phoneMac = device.remoteId.str;
    deviceInfo = BandDeviceInfo(
      name: device.platformName.isNotEmpty
          ? device.platformName
          : variant.label,
      mac: V8Protocol.parseMac(mac) ?? phoneMac,
      batteryPercent: V8Protocol.parseBatteryPercent(battery),
      isCharging: battery.length > 2 && battery[2] == 1,
      firmware: V8Protocol.parseFirmware(firmware) ?? 'unknown',
    );
    if (!variantConfirmed) {
      final macAddress = deviceInfo!.mac;
      final remembered = await _variantStore.findByMac(macAddress);
      if (remembered != null && _device == device && _ready && !_disposed) {
        _deviceVariants[device.remoteId.str] = remembered;
        variant = remembered;
        variantConfirmed = true;
        await _variantStore.remember(
          device.remoteId.str,
          macAddress,
          remembered,
        );
      }
    }
    notifyListeners();
  }

  Future<void> startLiveHeartRate() async {
    if (!_ready) throw StateError('Bracelet is not connected');
    if (_startingLive || isLiveHrActive || isWorkoutActive) return;
    _startingLive = true;
    try {
      liveHrStatus = 'Starting heart rate measurement...';
      notifyListeners();

      if (variantConfirmed) {
        await sendCommand(
          V8Protocol.cmdMeasure,
          V8Protocol.measurePayload(
            mode: V8Protocol.measureHeartRate,
            start: true,
            durationSec: 60,
            variant: variant,
          ),
        );
        await sendCommand(
          V8Protocol.cmdMeasure,
          V8Protocol.measurePayload(
            mode: V8Protocol.measureSpO2,
            start: true,
            durationSec: 60,
            variant: variant,
          ),
        );
      }
      await sendCommand(
        V8Protocol.cmdRealtime,
        V8Protocol.realtimePayload(enable: true, variant: variant),
      );

      isLiveHrActive = true;
      liveHrStatus = 'Measuring... keep the band on your wrist, stay still.';
      notifyListeners();
    } finally {
      _startingLive = false;
    }
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
          variant: variant,
        ),
      );
      await sendCommand(
        V8Protocol.cmdMeasure,
        V8Protocol.measurePayload(
          mode: V8Protocol.measureSpO2,
          start: false,
          variant: variant,
        ),
      );
      await sendCommand(
        V8Protocol.cmdRealtime,
        V8Protocol.realtimePayload(enable: false, variant: variant),
      );
    } catch (_) {
      // Best-effort stop.
    }

    liveHrStatus = null;
    notifyListeners();
  }

  /// Sends a command that returns a variable number of BLE notifications,
  /// terminated by the command-specific end marker.
  Future<List<Uint8List>> sendStreamCommand(
    int command, [
    List<int> payload = const [],
  ]) async {
    if (!_ready || _tx == null) throw StateError('Bracelet is not ready');
    final cmd = command & 0x7F;
    if (_streamCollectors.containsKey(cmd) || _pending.containsKey(cmd)) {
      throw StateError('Command already in progress');
    }
    final collector = _StreamCollector();
    _streamCollectors[cmd] = collector;
    try {
      final result = await Future.wait<Object?>([
        _tx!.write(
          V8Protocol.buildPacket(command, payload),
          withoutResponse: false,
        ),
        collector.completer.future,
      ], eagerError: true).timeout(const Duration(minutes: 2));
      return result[1] as List<Uint8List>;
    } finally {
      if (identical(_streamCollectors[cmd], collector)) {
        _streamCollectors.remove(cmd);
      }
    }
  }

  Future<void> syncSleepData() async {
    if (!_ready || isSleepSyncing) return;
    final generation = _connectionGeneration;
    sleepSyncError = null;
    isSleepSyncing = true;
    notifyListeners();
    try {
      final packets = await sendStreamCommand(V8Protocol.cmdSleep, [0x00]);
      if (generation != _connectionGeneration) return;
      sleepRecords = V8Protocol.parseSleepPackets(packets, variant);
      sleepSummary = SleepSummary.fromRecords(sleepRecords);
    } catch (error) {
      if (generation != _connectionGeneration) return;
      sleepSyncError = error.toString();
    } finally {
      if (generation == _connectionGeneration) {
        isSleepSyncing = false;
        notifyListeners();
      }
    }
  }

  /// Fire-and-forget write for commands the band does not acknowledge.
  void _writeRaw(int command, List<int> payload) {
    final tx = _tx;
    if (!_ready || tx == null) return;
    tx
        .write(V8Protocol.buildPacket(command, payload), withoutResponse: false)
        .catchError((_) {});
  }

  Future<Uint8List> sendCommand(
    int command, [
    List<int> payload = const [],
    Duration timeout = const Duration(seconds: 8),
  ]) async {
    if (!_ready || _tx == null) {
      throw StateError('Bracelet is not ready');
    }

    final cmd = command & 0x7F;
    if (_pending.containsKey(cmd) || _streamCollectors.containsKey(cmd)) {
      throw StateError('Command already in progress');
    }
    final completer = Completer<Uint8List>();
    _pending[cmd] = completer;
    try {
      final result = await Future.wait<Object?>([
        _tx!.write(
          V8Protocol.buildPacket(command, payload),
          withoutResponse: false,
        ),
        completer.future,
      ], eagerError: true).timeout(timeout);
      return result[1] as Uint8List;
    } finally {
      if (identical(_pending[cmd], completer)) _pending.remove(cmd);
    }
  }

  void _onNotify(List<int> data) {
    if (data.isEmpty || !_ready || _disposed) return;
    final bytes = Uint8List.fromList(data);
    final cmd = bytes[0] & 0x7F;

    if ((bytes[0] & 0x80) != 0) {
      final error = StateError(
        'Device rejected command 0x${cmd.toRadixString(16)}',
      );
      _pending.remove(cmd)?.completeError(error);
      _streamCollectors.remove(cmd)?.completer.completeError(error);
      return;
    }

    // Exercise live packets (0x18) — handled before any other check.
    if (cmd == V8Protocol.cmdExerciseLive) {
      _handleExercisePacket(bytes);
      return;
    }

    // Live vitals stream (0x09 packets).
    if (cmd == V8Protocol.cmdRealtime && bytes.length >= 24) {
      final vitals = V8Protocol.parseLivePacket(bytes);
      if (vitals != null) {
        _pending.remove(cmd)?.complete(bytes);
        liveVitals = vitals;
        liveVitalsAt = DateTime.now();
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
      final isEnd = V8Protocol.isStreamEnd(bytes, variant);
      final isError = (bytes[0] & 0x80) != 0;
      // A 2208A end packet still carries a full batch of records, so keep it.
      if (!isError) collector.packets.add(bytes);
      collector.pagePackets++;
      if (!isEnd &&
          !isError &&
          cmd == V8Protocol.cmdSleep &&
          collector.pagePackets == 50) {
        collector.pagePackets = 0;
        _writeRaw(cmd, [0x02]); // Continuation used by both vendor demos.
      }
      if (isEnd || isError) {
        _streamCollectors.remove(cmd);
        if (!collector.completer.isCompleted) {
          collector.completer.complete(collector.packets);
        }
      }
      return;
    }

    // Single-response commands.
    final completer = _pending.remove(cmd);
    completer?.complete(bytes);
  }

  // ── Workout control ─────────────────────────────────────────────────────────

  Future<bool> startWorkout(ExerciseType type) async {
    if (!_ready || isWorkoutActive || _startingLive) return false;
    if (!variantConfirmed) {
      statusMessage = 'Select the device model before starting a workout';
      notifyListeners();
      return false;
    }
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
        _workoutClock
          ..reset()
          ..start();
        isWorkoutActive = true;
        isWorkoutPaused = false;
        workoutLive = null;
        workoutEndedByDevice = false;
        workoutInactiveWarning = null;
        _startWorkoutHeartbeat();
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
      await sendCommand(V8Protocol.cmdExercise, [
        V8Protocol.exercisePause,
        0,
        0,
        0,
      ]);
      _workoutClock.stop();
      isWorkoutPaused = true;
      _stopWorkoutHeartbeat();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> resumeWorkout() async {
    if (!_ready || !isWorkoutActive || !isWorkoutPaused) return;
    try {
      await sendCommand(V8Protocol.cmdExercise, [
        V8Protocol.exerciseResume,
        0,
        0,
        0,
      ]);
      _workoutClock.start();
      isWorkoutPaused = false;
      _startWorkoutHeartbeat();
      notifyListeners();
    } catch (_) {}
  }

  /// Ends the active workout, saves to history, restarts live metrics.
  /// Returns the saved [WorkoutSummary] or null if no live data was captured.
  Future<WorkoutSummary?> endWorkout() async {
    if (!isWorkoutActive) return null;
    _workoutClock.stop();
    WorkoutSummary? summary;
    isWorkoutActive =
        false; // Prevent an end notification from saving it twice.
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
        await sendCommand(V8Protocol.cmdExercise, [
          V8Protocol.exerciseEnd,
          0,
          0,
          0,
        ]);
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

  /// Both supplied SDKs expose the 0x17 workout heartbeat.
  void _startWorkoutHeartbeat() {
    _stopWorkoutHeartbeat();

    _workoutHeartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ready || !isWorkoutActive || isWorkoutPaused) return;

      // No GPS source is configured; do not send elapsed time as pace.
      _writeRaw(
        V8Protocol.cmdWorkoutHeartbeat,
        V8Protocol.workoutHeartbeatPayload(
          distanceKm: 0,
          paceSecondsPerKm: 0, // Pace is unavailable without measured distance.
        ),
      );
    });
  }

  void _stopWorkoutHeartbeat() {
    _workoutHeartbeat?.cancel();
    _workoutHeartbeat = null;
  }

  void _clearWorkoutState() {
    _workoutClock.stop();
    _stopWorkoutHeartbeat();
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
        _workoutClock.stop();
        workoutEndedByDevice = true;
        isWorkoutActive = false;
        isWorkoutPaused = false;
        _stopWorkoutHeartbeat();
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
      final live = V8Protocol.parseExerciseLive(bytes, variant);
      if (live != null) {
        // 2208A frames carry no duration; fall back to elapsed wall time so
        // the workout screen still counts up and can derive pace.
        workoutLive = live.durationSeconds > 0 || workoutStartTime == null
            ? live
            : WorkoutLive(
                heartRate: live.heartRate,
                steps: live.steps,
                calories: live.calories,
                durationSeconds: _workoutClock.elapsed.inSeconds,
                distanceM: live.distanceM,
              );
        notifyListeners();
      }
    }
  }

  void _handleDisconnect(String message) {
    _connectionGeneration++;
    _ready = false;
    _tx = null;
    _workoutClock.stop();
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Disconnected'));
      }
    }
    _pending.clear();
    _stopWorkoutHeartbeat();
    isLiveHrActive = false;
    liveVitals = null;
    liveHrStatus = null;
    deviceInfo = null;
    sleepSummary = null;
    sleepRecords = const [];
    sleepSyncError = null;
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
    _connectionGeneration++;
    _workoutClock.stop();
    _ready = false;
    _stopWorkoutHeartbeat();
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
    sleepRecords = const [];
    sleepSyncError = null;
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
    if (state != BandConnectionState.error) {
      state = BandConnectionState.idle;
      statusMessage = 'Disconnected';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanSub?.cancel();
    unawaited(disconnect());
    super.dispose();
  }
}
