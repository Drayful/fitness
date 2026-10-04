import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'band_history.dart';
import 'band_variant.dart';
import 'body_profile.dart';
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
    required this.hasNameHint,
    this.rememberedVariant,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;
  final bool hasV8Service;
  final bool hasNameHint;
  final BandVariant? rememberedVariant;

  bool get likelyBand =>
      rememberedVariant != null || hasV8Service || hasNameHint;

  int get matchRank => rememberedVariant != null
      ? 3
      : hasV8Service
      ? 2
      : hasNameHint
      ? 1
      : 0;

  /// A name is only a hint. Actual compatibility is checked after connecting.
  static bool hasWatchNameHint(String name) {
    final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.startsWith('jcv8') ||
        normalized.startsWith('v8') ||
        normalized.contains('2208a');
  }
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
  final Map<String, ScannedBand> _scanCandidates = {};
  Map<String, BandVariant> _rememberedRemoteVariants = const {};
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
  int _scanGeneration = 0;
  bool _startingLive = false;
  final Stopwatch _workoutClock = Stopwatch();
  List<SleepRecord> sleepRecords = const [];
  String? sleepSyncError;

  // ── Background refresh & auto-reconnect ──
  //
  // A 0x28 measurement is a one-shot session on the band (60 s on legacy
  // firmware), and sleep/battery are only answered on request. Without a loop
  // that re-asks, every value froze at whatever the first connect produced.
  static const _lastDeviceKey = 'last_band_remote_id_v1';
  static const _refreshTick = Duration(seconds: 30);
  static const _measurementInterval = Duration(minutes: 2);
  static const _liveStreamStaleAfter = Duration(seconds: 75);
  static const _batteryInterval = Duration(minutes: 5);
  static const _sleepInterval = Duration(minutes: 30);
  static const _reconnectBackoff = [2, 5, 10, 20, 30, 60];

  Timer? _refreshTimer;
  Timer? _reconnectTimer;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  bool _refreshing = false;
  DateTime? _lastMeasureArmAt;
  DateTime? _lastBatteryAt;
  DateTime? _lastSleepSyncAt;

  /// The watch to reconnect to on launch and after a dropped link. Cleared
  /// only by [forgetDevice], i.e. when the user disconnects on purpose.
  String? _rememberedDeviceId;
  int _reconnectAttempt = 0;
  bool _autoReconnecting = false;

  bool get hasRememberedDevice => _rememberedDeviceId != null;
  bool get isAutoReconnecting => _autoReconnecting;

  // ── Last successful sync (Spec-06: warn after three days) ──
  static const _lastSyncKey = 'last_band_sync_at_v1';
  static const staleSyncAfter = Duration(days: 3);

  /// When data last arrived from the watch, persisted across launches so the
  /// home screen can say how old the numbers are when the watch is away.
  DateTime? lastSyncAt;
  DateTime? _lastSyncSavedAt;

  bool get isSyncStale =>
      lastSyncAt != null &&
      DateTime.now().difference(lastSyncAt!) > staleSyncAfter;

  Future<void> _loadLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastSyncKey);
      lastSyncAt = raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {}
  }

  void _markSynced() {
    final now = DateTime.now();
    lastSyncAt = now;
    // Live packets arrive every second; persist at most once a minute.
    final saved = _lastSyncSavedAt;
    if (saved != null && now.difference(saved) < const Duration(minutes: 1)) {
      return;
    }
    _lastSyncSavedAt = now;
    unawaited(
      SharedPreferences.getInstance()
          .then((p) => p.setString(_lastSyncKey, now.toIso8601String()))
          .catchError((_) => false),
    );
  }

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
  bool isLiveHrActive = false;
  bool get isStartingLive => _startingLive;
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
  int _workoutHeartRateSum = 0;
  int _workoutHeartRateCount = 0;
  int _workoutHeartRateMax = 0;

  /// One reading per [WorkoutSummary.heartRateSampleSeconds] for the summary
  /// chart; capped at four hours.
  final List<int> _workoutHeartRateSamples = [];
  int _lastHeartRateBucket = -1;
  static const _maxHeartRateSamples = 4 * 3600 ~/ WorkoutSummary.heartRateSampleSeconds;

  int? get _averageWorkoutHeartRate => _workoutHeartRateCount == 0
      ? null
      : (_workoutHeartRateSum / _workoutHeartRateCount).round();

  bool get isConnected => state == BandConnectionState.connected;

  /// Confirms the SDK family for this device. Passing null clears confirmation.
  Future<void> overrideVariant(BandVariant? value) async {
    if (isWorkoutActive || isSleepSyncing) return;
    if (_startingLive) {
      throw StateError('Wait for live measurements to start');
    }
    final id = _device?.remoteId.str;
    if (id == null) return;
    if (isLiveHrActive) {
      await stopLiveHeartRate();
    }
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
    liveVitals = null;
    liveVitalsAt = null;
    notifyListeners();
    await _variantStore.remember(id, deviceInfo?.mac, value);
    if (value != null && _ready) {
      _scheduleSleepSync(_connectionGeneration);
      try {
        await startLiveHeartRate();
      } catch (_) {
        statusMessage = 'Model saved, but live measurements could not start.';
        notifyListeners();
      }
    }
  }

  static bool _bleOptionsSet = false;
  bool _locationAskedThisSession = false;

  /// Must run before any other FlutterBluePlus call: on iOS the options are
  /// read once, when the plugin creates its CBCentralManager.
  static Future<void> applyBleOptions() async {
    if (_bleOptionsSet || kIsWeb) return;
    _bleOptionsSet = true;
    try {
      // We show our own "Bluetooth is off" state instead of the iOS alert.
      await FlutterBluePlus.setOptions(
        showPowerAlert: false,
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// Asks only for what is still missing, so the system dialogs do not pop up
  /// on every scan, launch and reconnect.
  ///
  /// iOS: no explicit request at all — CoreBluetooth shows its own permission
  /// prompt on first use. permission_handler's request opened a second
  /// CBCentralManager, which re-showed the "Turn on Bluetooth" alert each time.
  ///
  /// Android 12+: BLUETOOTH_SCAN is declared `neverForLocation` and location is
  /// capped at API 30 in the manifest, so the location prompt is gone there.
  /// On Android ≤ 11 it is still required for scanning, but asked at most once
  /// per session and never again once the user chose "Don't ask again".
  Future<void> requestPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    await applyBleOptions();
    if (Platform.isIOS) return;

    final missing = <Permission>[];
    for (final p in const [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ]) {
      final status = await p.status;
      if (!status.isGranted && !status.isPermanentlyDenied) missing.add(p);
    }

    if (!_locationAskedThisSession) {
      final location = await Permission.locationWhenInUse.status;
      if (!location.isGranted && !location.isPermanentlyDenied) {
        _locationAskedThisSession = true;
        missing.add(Permission.locationWhenInUse);
      }
    }

    if (missing.isNotEmpty) await missing.request();
  }

  /// A watch that is still linked to the phone at OS level — left over from a
  /// killed app process, or held by the system — stops advertising, so a scan
  /// never sees it. That is what toggling Bluetooth used to "fix". Ask the OS
  /// for such devices directly and list them alongside the scan results.
  Future<void> _addSystemConnectedWatches() async {
    try {
      final devices = await FlutterBluePlus.systemDevices([
        Guid(V8Protocol.serviceUuid),
      ]).timeout(const Duration(seconds: 3));
      for (final device in devices) {
        final id = device.remoteId.str.toLowerCase();
        final name = device.platformName.trim();
        _scanCandidates[id] = ScannedBand(
          device: device,
          name: name,
          rssi: 0,
          hasV8Service: true,
          hasNameHint: ScannedBand.hasWatchNameHint(name),
          rememberedVariant: _rememberedRemoteVariants[id],
        );
      }
      if (devices.isNotEmpty) {
        scanResults
          ..clear()
          ..addAll(_scanCandidates.values);
        notifyListeners();
      }
    } catch (_) {
      // Not supported on this platform/version; the regular scan still runs.
    }
  }

  /// True when BLE can be used right now; otherwise surfaces a status message
  /// instead of triggering a system "turn on Bluetooth" prompt.
  bool _ensureAdapterOn() {
    final adapter = FlutterBluePlus.adapterStateNow;
    // `unknown` right after launch means "not reported yet", not "off".
    if (adapter == BluetoothAdapterState.on ||
        adapter == BluetoothAdapterState.unknown) {
      return true;
    }
    state = BandConnectionState.idle;
    statusMessage = 'Bluetooth is off. Turn it on to connect the watch.';
    notifyListeners();
    return false;
  }

  Future<void> startScan() async {
    final generation = ++_scanGeneration;
    try {
      await requestPermissions();
      if (generation != _scanGeneration || _disposed) return;
      if (!_ensureAdapterOn()) return;
      await FlutterBluePlus.stopScan();
      scanResults.clear();
      _scanCandidates.clear();
      try {
        _rememberedRemoteVariants = await _variantStore
            .confirmedRemoteDevices();
      } catch (_) {
        _rememberedRemoteVariants = const {};
      }
      await _addSystemConnectedWatches();
      statusMessage = 'Scanning for nearby Bluetooth devices...';
      state = BandConnectionState.scanning;
      notifyListeners();

      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (generation != _scanGeneration || _disposed) return;
        for (final result in results) {
          final id = result.device.remoteId.str.toLowerCase();
          final previous = _scanCandidates[id];
          final advertised =
              previous?.hasV8Service == true ||
              result.advertisementData.serviceUuids.any(
                (uuid) =>
                    V8Protocol.uuidMatches(uuid.str, V8Protocol.serviceUuid),
              );
          final reportedName = result.device.platformName.trim().isNotEmpty
              ? result.device.platformName.trim()
              : result.advertisementData.advName.trim();
          final name = reportedName.isNotEmpty
              ? reportedName
              : previous?.name ?? '';
          _scanCandidates[id] = ScannedBand(
            device: result.device,
            name: name,
            rssi: result.rssi,
            hasV8Service: advertised,
            hasNameHint: ScannedBand.hasWatchNameHint(name),
            rememberedVariant: _rememberedRemoteVariants[id],
          );
        }
        scanResults
          ..clear()
          ..addAll(_scanCandidates.values);
        scanResults.sort((a, b) {
          final byMatch = b.matchRank.compareTo(a.matchRank);
          if (byMatch != 0) return byMatch;
          return (b.rssi == 0 ? -999 : b.rssi).compareTo(
            a.rssi == 0 ? -999 : a.rssi,
          );
        });
        notifyListeners();
      });

      // Do not filter by service: some watches expose FFF0 only after connect.
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
      await Future<void>.delayed(const Duration(seconds: 12));
    } catch (error) {
      if (generation == _scanGeneration && !_disposed) {
        state = BandConnectionState.error;
        statusMessage = 'Bluetooth scan failed: $error';
        notifyListeners();
      }
    } finally {
      if (generation == _scanGeneration) {
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
        await _scanSub?.cancel();
        _scanSub = null;
        if (state == BandConnectionState.scanning) {
          state = BandConnectionState.idle;
          statusMessage = scanResults.isEmpty
              ? 'No nearby Bluetooth devices found.'
              : 'Found ${scanResults.length} nearby Bluetooth device(s).';
          notifyListeners();
        }
      }
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    if (!_ensureAdapterOn()) return;
    _scanGeneration++;
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
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
      await _connectLink(device);
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

      var services = await _discoverServicesWithRetry(device);
      BluetoothService? findV8() {
        for (final s in services) {
          if (V8Protocol.uuidMatches(s.uuid.str, V8Protocol.serviceUuid)) {
            return s;
          }
        }
        return null;
      }

      var v8Service = findV8();
      if (v8Service == null && Platform.isAndroid) {
        // Android caches a device's GATT table across connections; a stale
        // cache hides FFF0 until Bluetooth is toggled. Drop it and rediscover.
        try {
          await device.clearGattCache();
          services = await _discoverServicesWithRetry(device);
          v8Service = findV8();
        } catch (_) {}
      }
      lastDiscoveredServices = services.map((s) => s.uuid.str).toList();
      notifyListeners();
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

      _reconnectAttempt = 0;
      _autoReconnecting = false;
      unawaited(_rememberDevice(remoteId));
      _startRefreshLoop();

      // Auto-start live metrics and sleep sync after a short stabilization delay.
      Future<void>.delayed(const Duration(milliseconds: 400)).then((_) async {
        if (!_ready ||
            generation != _connectionGeneration ||
            !variantConfirmed) {
          return;
        }
        try {
          await startLiveHeartRate();
        } catch (_) {}
      });
      if (variantConfirmed) _scheduleSleepSync(generation);
    } catch (e) {
      final wasAutoReconnect = _autoReconnecting;
      state = BandConnectionState.error;
      statusMessage = wasAutoReconnect
          ? 'Watch not reachable. Retrying automatically…'
          : 'Connection failed: $e';
      notifyListeners();
      await disconnect();
      if (wasAutoReconnect) _scheduleReconnect();
    }
  }

  // ── Auto-reconnect ─────────────────────────────────────────────────────────

  /// Reconnects to the watch used last time, without a scan. Call once on
  /// launch; it is a no-op until a watch has been connected successfully.
  Future<void> restoreLastDevice() async {
    await _loadLastSync();
    try {
      final prefs = await SharedPreferences.getInstance();
      _rememberedDeviceId = prefs.getString(_lastDeviceKey);
    } catch (_) {
      _rememberedDeviceId = null;
    }
    if (_rememberedDeviceId == null || _disposed) return;
    notifyListeners();

    // Reconnect as soon as Bluetooth comes (back) on, not only at launch.
    await _adapterSub?.cancel();
    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      if (s == BluetoothAdapterState.on) {
        _reconnectAttempt = 0;
        unawaited(_attemptReconnect());
      }
    });

    try {
      await requestPermissions();
    } catch (_) {}
    await _attemptReconnect();
  }

  /// User-initiated disconnect: drops the link and stops reconnecting to this
  /// watch until one is connected again.
  Future<void> forgetDevice() async {
    _rememberedDeviceId = null;
    _autoReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastDeviceKey);
    } catch (_) {}
    await disconnect();
  }

  Future<void> _rememberDevice(String remoteId) async {
    _rememberedDeviceId = remoteId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDeviceKey, remoteId);
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed || _rememberedDeviceId == null) return;
    if (state == BandConnectionState.connecting ||
        state == BandConnectionState.connected) {
      return;
    }
    _reconnectTimer?.cancel();
    final step = _reconnectAttempt < _reconnectBackoff.length
        ? _reconnectAttempt
        : _reconnectBackoff.length - 1;
    _reconnectTimer = Timer(
      Duration(seconds: _reconnectBackoff[step]),
      () => unawaited(_attemptReconnect()),
    );
  }

  Future<void> _attemptReconnect() async {
    final id = _rememberedDeviceId;
    if (id == null || _disposed) return;
    // Never fight a scan or a connection the user started by hand.
    if (state == BandConnectionState.connecting ||
        state == BandConnectionState.connected ||
        state == BandConnectionState.scanning) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final adapter = FlutterBluePlus.adapterStateNow;
    if (adapter != BluetoothAdapterState.on) {
      // The adapter listener retries the moment Bluetooth reports "on".
      // `unknown` just means it has not reported yet (early in launch).
      if (adapter != BluetoothAdapterState.unknown) {
        statusMessage = 'Bluetooth is off. Will reconnect when it is on.';
        notifyListeners();
      }
      return;
    }

    _reconnectAttempt++;
    _autoReconnecting = true;
    notifyListeners();
    // Connecting by stored id works without a scan: Android keeps the MAC,
    // iOS the peripheral UUID it handed out on the first connection.
    await connect(BluetoothDevice.fromId(id));
  }

  // ── Periodic refresh ───────────────────────────────────────────────────────

  /// Pull fresh data from the watch now: re-arms HR/SpO2, re-reads battery,
  /// re-syncs sleep. If the watch is not connected, tries to reconnect.
  Future<void> refresh() async {
    if (!_ready) {
      _reconnectAttempt = 0;
      await _attemptReconnect();
      return;
    }
    await _refreshTickHandler(force: true);
  }

  /// Called when the app returns to the foreground.
  Future<void> onAppResumed() => refresh();

  void _startRefreshLoop() {
    _stopRefreshLoop();
    final now = DateTime.now();
    // The connect sequence itself just armed measurements and reads battery
    // and sleep, so count those as fresh.
    _lastMeasureArmAt = now;
    _lastBatteryAt = now;
    _lastSleepSyncAt = now;
    _refreshTimer = Timer.periodic(
      _refreshTick,
      (_) => unawaited(_refreshTickHandler()),
    );
  }

  void _stopRefreshLoop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshTickHandler({bool force = false}) async {
    if (!_ready || _refreshing || _disposed || !variantConfirmed) return;
    // A workout owns the link: 0x28/0x09 would collide with its 0x18 stream.
    if (isWorkoutActive || _startingLive) return;
    _refreshing = true;
    final generation = _connectionGeneration;
    try {
      final now = DateTime.now();
      bool due(DateTime? last, Duration every) =>
          force || last == null || now.difference(last) >= every;

      final streamStale = liveVitalsAt == null ||
          now.difference(liveVitalsAt!) >= _liveStreamStaleAfter;
      if (due(_lastMeasureArmAt, _measurementInterval) || streamStale) {
        await _rearmMeasurements(restartStream: streamStale || force);
        _lastMeasureArmAt = DateTime.now();
      }
      if (generation != _connectionGeneration) return;

      if (due(_lastBatteryAt, _batteryInterval)) {
        await _refreshBattery();
        _lastBatteryAt = DateTime.now();
      }
      if (generation != _connectionGeneration) return;

      if (due(_lastSleepSyncAt, _sleepInterval) && !isSleepSyncing) {
        _lastSleepSyncAt = DateTime.now();
        await syncSleepData();
        if (generation != _connectionGeneration) return;
        await syncHistory();
      }
    } catch (_) {
      // Best effort; the next tick tries again.
    } finally {
      _refreshing = false;
    }
  }

  /// Starts a new HR/SpO2 measurement session. [startLiveHeartRate] cannot be
  /// reused: it bails out while [isLiveHrActive] is set, which is exactly the
  /// state left behind once the band's own session has timed out.
  Future<void> _rearmMeasurements({required bool restartStream}) async {
    if (!_ready || isWorkoutActive) return;
    if (!isLiveHrActive) {
      await startLiveHeartRate();
      return;
    }
    for (final mode in const [
      V8Protocol.measureHeartRate,
      V8Protocol.measureSpO2,
    ]) {
      await sendCommand(
        V8Protocol.cmdMeasure,
        V8Protocol.measurePayload(
          mode: mode,
          start: true,
          durationSec: 60,
          variant: variant,
        ),
      );
    }
    if (restartStream) {
      await sendCommand(
        V8Protocol.cmdRealtime,
        V8Protocol.realtimePayload(enable: true, variant: variant),
      );
    }
  }

  Future<void> _refreshBattery() async {
    final info = deviceInfo;
    if (!_ready || info == null) return;
    final battery = await sendCommand(V8Protocol.cmdBattery);
    final percent = V8Protocol.parseBatteryPercent(battery);
    if (percent == null) return;
    deviceInfo = BandDeviceInfo(
      name: info.name,
      mac: info.mac,
      batteryPercent: percent,
      isCharging: battery.length > 2 && battery[2] == 1,
      firmware: info.firmware,
    );
    notifyListeners();
  }

  void _scheduleSleepSync(int generation) {
    Future<void>.delayed(const Duration(seconds: 2)).then((_) async {
      if (!_ready || generation != _connectionGeneration || !variantConfirmed) {
        return;
      }
      try {
        await syncSleepData();
      } catch (_) {}
      if (!_ready || generation != _connectionGeneration) return;
      try {
        await _configureAutoMeasurement();
      } catch (_) {}
      if (!_ready || generation != _connectionGeneration) return;
      _bodyProfileSent = null; // a fresh link: make sure the band has it
      await _sendBodyProfile();
      _stepGoalSent = null;
      await _sendStepGoal();
      if (!_ready || generation != _connectionGeneration) return;
      try {
        await syncHistory();
      } catch (_) {}
    });
  }

  /// Opens the BLE link, retrying once after closing the half-open GATT a
  /// failed attempt leaves behind on Android (status 133 / timeout) — the
  /// other state that otherwise only a Bluetooth toggle cleared.
  Future<void> _connectLink(BluetoothDevice device) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        try {
          await device.disconnect();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      try {
        // mtu: null — the plugin would otherwise negotiate 512 on its own and
        // we negotiate 153 right after (the size both vendor SDKs fall back
        // to); two back-to-back MTU exchanges upset some watches.
        await device.connect(
          timeout: const Duration(seconds: 15),
          mtu: null,
          autoConnect: false,
        );
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Connection failed');
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
    if (!variantConfirmed) throw StateError('Select the watch model first');
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
      notifyListeners();
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
      _markSynced();
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

  // ── Band memory: auto measurement + history download (TZ §4.1, §5) ──────

  /// Readings from the band's own memory, from the latest history sync.
  List<BodySample> historySamples = const [];

  /// Per-day totals from the latest history sync, newest first.
  List<DailyActivity> dailyActivity = const [];

  /// Bumped after every successful history sync; listeners use it to upload.
  int historySyncCount = 0;
  bool isHistorySyncing = false;
  DateTime? lastHistorySyncAt;

  /// Most recent history value for [metric], if any.
  BodySample? latestHistory(BodyMetric metric) {
    BodySample? best;
    for (final s in historySamples) {
      if (s.metric == metric && (best == null || s.at.isAfter(best.at))) {
        best = s;
      }
    }
    return best;
  }

  // ── Step goal → band (0x0B, 2208A only; the V8 SDK has no such command) ──
  static const _cmdSetStepGoal = 0x0B;
  int? _stepGoal;
  int? _stepGoalSent;

  Future<void> setStepGoal(int goal) async {
    _stepGoal = goal;
    if (goal != _stepGoalSent) await _sendStepGoal();
  }

  Future<void> _sendStepGoal() async {
    final goal = _stepGoal;
    if (goal == null ||
        !_ready ||
        !variantConfirmed ||
        variant != BandVariant.jc2208a) {
      return;
    }
    try {
      await sendCommand(_cmdSetStepGoal, [
        goal & 0xFF,
        (goal >> 8) & 0xFF,
        (goal >> 16) & 0xFF,
        (goal >> 24) & 0xFF,
      ]);
      _stepGoalSent = goal;
    } catch (_) {}
  }

  // ── Body profile → band (0x02) ──
  BodyProfile _bodyProfile = const BodyProfile();
  BodyProfile? _bodyProfileSent;

  /// Sends sex/age/height/weight/stride so the band's calorie and distance
  /// estimates stop using factory defaults. Re-sent after each connect.
  Future<void> setBodyProfile(BodyProfile profile) async {
    _bodyProfile = profile;
    if (profile != _bodyProfileSent) await _sendBodyProfile();
  }

  Future<void> _sendBodyProfile() async {
    final payload = _bodyProfile.bandPayload();
    if (payload == null || !_ready || !variantConfirmed) return;
    try {
      await sendCommand(BodyProfile.cmdSetPersonalInfo, payload);
      _bodyProfileSent = _bodyProfile;
    } catch (_) {
      // Retried on the next connect.
    }
  }

  /// Intervals for the band's own background measurements, in minutes.
  /// Heart rate is the densest because RHR, zones and strain depend on it;
  /// the rest are sparser to spare the battery.
  static const _autoMeasurements = {
    BandHistory.autoHeartRate: 5,
    BandHistory.autoHrv: 30,
    BandHistory.autoTemperature: 30,
    BandHistory.autoSpo2: 60,
  };

  /// Turns on interval measurements so the band keeps recording into its
  /// memory while the phone is away; without it there is little to download.
  /// Each type is best effort: firmware without, say, temperature rejects
  /// just that one.
  Future<void> _configureAutoMeasurement() async {
    if (!_ready || !variantConfirmed) return;
    for (final entry in _autoMeasurements.entries) {
      if (!_ready) return;
      try {
        await sendCommand(
          BandHistory.cmdSetAutoMeasurement,
          BandHistory.autoMeasurementPayload(
            type: entry.key,
            intervalMinutes: entry.value,
          ),
        );
      } catch (_) {}
    }
  }

  /// Downloads heart rate, HRV/stress, SpO2, temperature and daily totals
  /// stored on the band. Reads only (modes 0 and 2); one command at a time,
  /// and a command the firmware does not answer is skipped, not fatal.
  Future<void> syncHistory() async {
    if (!_ready || !variantConfirmed || isHistorySyncing || isWorkoutActive) {
      return;
    }
    final generation = _connectionGeneration;
    isHistorySyncing = true;
    notifyListeners();
    final samples = <BodySample>[];
    var days = <DailyActivity>[];
    var anyAnswered = false;
    try {
      for (final cmd in BandHistory.commands) {
        if (!_ready || generation != _connectionGeneration) return;
        try {
          final packets = await sendStreamCommand(cmd, BandHistory.request());
          anyAnswered = true;
          if (cmd == BandHistory.cmdDailyTotals) {
            days = BandHistory.parseDailyTotals(packets)
              ..sort((a, b) => b.date.compareTo(a.date));
          } else {
            samples.addAll(BandHistory.parse(cmd, packets));
          }
        } catch (_) {
          // Unsupported or timed out: keep going with the other kinds.
        }
      }
      if (generation != _connectionGeneration || !anyAnswered) return;
      samples.sort((a, b) => a.at.compareTo(b.at));
      historySamples = List.unmodifiable(samples);
      dailyActivity = List.unmodifiable(days);
      lastHistorySyncAt = DateTime.now();
      historySyncCount++;
      _markSynced();
    } finally {
      if (generation == _connectionGeneration) {
        isHistorySyncing = false;
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
      if (!variantConfirmed) return;
      final vitals = V8Protocol.parseLivePacket(bytes);
      if (vitals != null) {
        _pending.remove(cmd)?.complete(bytes);
        liveVitals = vitals;
        liveVitalsAt = DateTime.now();
        _markSynced();
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
      final isHistory = BandHistory.isHistoryCommand(cmd);
      final isEnd = isHistory
          ? BandHistory.isEnd(cmd, bytes)
          : V8Protocol.isStreamEnd(bytes, variant);
      final isError = (bytes[0] & 0x80) != 0;
      // A 2208A end packet still carries a full batch of records, so keep it.
      if (!isError) collector.packets.add(bytes);
      collector.pagePackets++;
      if (!isEnd &&
          !isError &&
          (cmd == V8Protocol.cmdSleep || isHistory) &&
          collector.pagePackets == BandHistory.pageNotifications) {
        collector.pagePackets = 0;
        // Continuation used by both vendor demos; never the erasing 0x99.
        _writeRaw(cmd, BandHistory.request(continuation: true));
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
        _workoutHeartRateSum = 0;
        _workoutHeartRateCount = 0;
        _workoutHeartRateMax = 0;
        _workoutHeartRateSamples.clear();
        _lastHeartRateBucket = -1;
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
        averageHeartRate: _averageWorkoutHeartRate,
        maxHeartRate: _workoutHeartRateCount == 0 ? null : _workoutHeartRateMax,
        heartRateSamples: _workoutHeartRateSamples,
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
            averageHeartRate: _averageWorkoutHeartRate,
            maxHeartRate: _workoutHeartRateCount == 0
                ? null
                : _workoutHeartRateMax,
            heartRateSamples: _workoutHeartRateSamples,
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
        if (live.heartRate >= 30 && live.heartRate <= 240) {
          _workoutHeartRateSum += live.heartRate;
          _workoutHeartRateCount++;
          if (live.heartRate > _workoutHeartRateMax) {
            _workoutHeartRateMax = live.heartRate;
          }
          final bucket =
              _workoutClock.elapsed.inSeconds ~/
              WorkoutSummary.heartRateSampleSeconds;
          if (bucket != _lastHeartRateBucket &&
              _workoutHeartRateSamples.length < _maxHeartRateSamples) {
            _lastHeartRateBucket = bucket;
            _workoutHeartRateSamples.add(live.heartRate);
          }
        }
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
    isHistorySyncing = false;
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
    _stopRefreshLoop();
    state = BandConnectionState.idle;
    statusMessage = _rememberedDeviceId != null
        ? '$message. Reconnecting…'
        : message;
    notifyListeners();
    // The link dropped on its own (range, watch reboot): get it back.
    _reconnectAttempt = 0;
    _scheduleReconnect();
  }

  /// Drops the link but keeps the watch remembered for auto-reconnect; use
  /// [forgetDevice] for a user-initiated disconnect.
  Future<void> disconnect() async {
    _connectionGeneration++;
    _workoutClock.stop();
    _ready = false;
    _stopRefreshLoop();
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
    isHistorySyncing = false;
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
    _adapterSub?.cancel();
    _reconnectTimer?.cancel();
    _stopRefreshLoop();
    unawaited(disconnect());
    super.dispose();
  }
}
