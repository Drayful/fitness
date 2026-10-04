import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../band/sleep_model.dart';
import '../band/band_history.dart';
import '../band/body_profile.dart';
import '../band/band_variant.dart';
import '../band/v8_protocol.dart';
import '../band/workout_model.dart';
import 'api_client.dart';

/// Holds authentication state (Sanctum token + current user) and exposes
/// high-level actions the UI calls. Token is persisted in platform secure storage
/// so the user stays logged in across launches.
class SessionController extends ChangeNotifier {
  SessionController({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;
  final _storage = const FlutterSecureStorage();
  bool _disposed = false;
  int _sessionGeneration = 0;
  int _pendingCountRequest = 0;
  Future<void> _uploadSerial = Future.value();
  double? averageHeartRate;
  int heartRateSampleCount = 0;
  List<WorkoutSummary> savedWorkouts = const [];
  List<Map<String, dynamic>> savedSleepObservations = const [];
  List<Map<String, dynamic>> recentVitals = const [];
  int pendingUploadCount = 0;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  static const _tokenKey = 'auth_token';
  static const _userNameKey = 'auth_user_name';
  static const _userEmailKey = 'auth_user_email';

  bool _bootstrapping = true;
  bool get bootstrapping => _bootstrapping;

  String? _token;
  bool get isAuthenticated => _token != null;

  String? userName;
  String? userEmail;

  /// Load a persisted token on app start.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove the old plaintext session; require login after this upgrade.
      await prefs.remove(_tokenKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userEmailKey);
      stepGoal = prefs.getInt(_stepGoalKey) ?? defaultStepGoal;
      final savedToken = await _storage.read(key: _tokenKey);
      final savedName = await _storage.read(key: _userNameKey);
      final savedEmail = await _storage.read(key: _userEmailKey);
      if (_disposed) return;
      _token = savedToken;
      userName = savedName;
      userEmail = savedEmail;
      api.token = _token;
      unawaited(refreshPendingUploadCount().catchError((_) {}));
      unawaited(retryPendingWorkouts().catchError((_) {}));
      unawaited(retryPendingMeasurements().catchError((_) {}));
      unawaited(refreshHistory().catchError((_) {}));
    } catch (_) {
      _token = null;
      api.token = null;
    } finally {
      _bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await api.register(
      name: name,
      email: email,
      password: password,
    );
    await _applyAuth(res);
  }

  Future<void> login({required String email, required String password}) async {
    final res = await api.login(email: email, password: password);
    await _applyAuth(res);
  }

  Future<void> logout() async {
    _sessionGeneration++;
    try {
      await api.logout();
    } catch (_) {
      // Even if the network call fails, drop the local session.
    }
    _token = null;
    api.token = null;
    userName = null;
    userEmail = null;
    averageHeartRate = null;
    heartRateSampleCount = 0;
    savedWorkouts = const [];
    savedSleepObservations = const [];
    recentVitals = const [];
    sampleSummary = const {};
    savedDailyActivity = const [];
    bodyProfile = const BodyProfile();
    pendingUploadCount = 0;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userNameKey);
      await _storage.delete(key: _userEmailKey);
    } finally {
      notifyListeners();
    }
  }

  Future<void> _applyAuth(Map<String, dynamic> res) async {
    if (res['token'] is! String || (res['token'] as String).isEmpty) {
      throw ApiException('Сервер не вернул токен авторизации.');
    }
    _sessionGeneration++;
    await _storage.write(key: _tokenKey, value: res['token'] as String);
    _token = res['token'] as String?;
    api.token = _token;
    final user = res['user'];
    if (user is Map) {
      userName = user['name'] as String?;
      userEmail = user['email'] as String?;
      bodyProfile = BodyProfile.fromUser(user);
    }
    await _storage.write(key: _userNameKey, value: userName);
    await _storage.write(key: _userEmailKey, value: userEmail);
    notifyListeners();
    unawaited(refreshPendingUploadCount().catchError((_) {}));
    unawaited(retryPendingWorkouts().catchError((_) {}));
    unawaited(retryPendingMeasurements().catchError((_) {}));
    unawaited(refreshHistory().catchError((_) {}));
  }

  // ── Data uploads (band → API) ───────────────────────────────────────────────

  /// Save pending summaries securely per account before attempting delivery.
  /// Stable IDs make a retry after a lost HTTP response safe on the backend.
  Future<void> uploadWorkout(WorkoutSummary s) {
    final samples = s.heartRateSamples
        .where((bpm) => bpm >= 30 && bpm <= 240)
        .toList();
    final payload = <String, dynamic>{
      'client_id':
          '${s.type.name}-${s.startTime.toUtc().microsecondsSinceEpoch}',
      'performed_at': s.startTime.toUtc().toIso8601String(),
      'type': s.type.name,
      'duration_minutes': (s.durationSeconds / 60).round().clamp(1, 600),
      'intensity': _intensityFromHr(s.averageHeartRate ?? s.heartRate),
      'metrics': {
        'steps': s.steps,
        'calories': s.calories,
        'distance_m': s.distanceM > 0 ? s.distanceM : null,
        'last_heart_rate': s.heartRate > 0 ? s.heartRate : null,
        'average_heart_rate': s.averageHeartRate,
        'max_heart_rate': s.maxHeartRate,
        'duration_seconds': s.durationSeconds,
        // Keys only when present: a backend without chart support rejects
        // unknown metrics keys even with null values.
        if (samples.isNotEmpty) 'heart_rate_samples': samples,
        if (samples.isNotEmpty)
          'heart_rate_sample_seconds': WorkoutSummary.heartRateSampleSeconds,
      },
    };
    return _queueUpload(payload);
  }

  static const _chartMetricKeys = [
    'heart_rate_samples',
    'heart_rate_sample_seconds',
  ];

  /// Sends one queued workout. If a backend that predates the heart-rate
  /// chart rejects the payload (422), retry once without the chart so the
  /// workout itself is not stuck in the queue forever.
  Future<void> _sendWorkout(Map<String, dynamic> next) async {
    final metrics = Map<String, dynamic>.from(next['metrics'] as Map);
    Future<void> send(Map<String, dynamic> m) => api.createWorkout(
      performedAt: DateTime.parse(next['performed_at'] as String),
      type: next['type'] as String,
      durationMinutes: next['duration_minutes'] as int,
      intensity: next['intensity'] as int,
      clientId: next['client_id'] as String,
      metrics: m,
    );
    try {
      await send(metrics);
    } on ApiException catch (e) {
      final hasChart = _chartMetricKeys.any(metrics.containsKey);
      if (e.statusCode != 422 || !hasChart) rethrow;
      await send(
        Map.of(metrics)..removeWhere((k, _) => _chartMetricKeys.contains(k)),
      );
    }
  }

  Future<void> retryPendingWorkouts() => _queueUpload(null);

  Future<void> _queueUpload(Map<String, dynamic>? incoming) {
    if (!isAuthenticated || userEmail == null || _disposed) {
      return incoming == null
          ? Future.value()
          : Future.error(StateError('Sign in before uploading'));
    }
    final generation = _sessionGeneration;
    final key = 'pending_workouts_${Uri.encodeComponent(userEmail!)}';
    final operation = _uploadSerial.then((_) async {
      if (generation != _sessionGeneration || _disposed) return;
      final stored = await _storage.read(key: key);
      final pending = stored == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(stored) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      if (incoming != null &&
          !pending.any((e) => e['client_id'] == incoming['client_id'])) {
        pending.add(incoming);
        await _storage.write(key: key, value: jsonEncode(pending));
        await refreshPendingUploadCount();
      }
      while (pending.isNotEmpty) {
        if (generation != _sessionGeneration || _disposed) return;
        final next = pending.first;
        await _sendWorkout(next);
        pending.removeAt(0);
        await _storage.write(key: key, value: jsonEncode(pending));
        await refreshPendingUploadCount();
        unawaited(refreshWorkouts().catchError((_) {}));
      }
    });
    _uploadSerial = operation.catchError((_) {});
    return operation;
  }

  Future<void> uploadHeartRate(int bpm, DateTime measuredAt) async {
    if (bpm < 30 || bpm > 240) return;
    await _queueMeasurement({
      'kind': 'heart_rate',
      'client_id': 'hr-${measuredAt.toUtc().microsecondsSinceEpoch}',
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'bpm': bpm,
    });
    await refreshHeartRate();
  }

  Future<void> uploadVitals(
    LiveVitals vitals,
    DateTime measuredAt, {
    BandVariant? model,
  }) async {
    final rawHeartRate = vitals.heartRate;
    final rawSpo2 = vitals.spo2;
    final rawTemperature = vitals.temperatureC;
    final rawSteps = vitals.steps;
    final heartRate =
        rawHeartRate != null && rawHeartRate >= 30 && rawHeartRate <= 240
        ? rawHeartRate
        : null;
    final spo2 = rawSpo2 != null && rawSpo2 >= 1 && rawSpo2 <= 100
        ? rawSpo2
        : null;
    final temperature =
        rawTemperature != null && rawTemperature >= 0 && rawTemperature <= 60
        ? rawTemperature
        : null;
    final steps = rawSteps >= 0 && rawSteps <= 1000000 ? rawSteps : null;
    if (heartRate == null &&
        spo2 == null &&
        temperature == null &&
        steps == null) {
      return;
    }
    await _queueMeasurement({
      'kind': 'vitals',
      'client_id': 'vitals-${measuredAt.toUtc().microsecondsSinceEpoch}',
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'heart_rate': heartRate,
      'spo2': spo2,
      'temperature_c': temperature,
      'steps': steps,
      'device_model': model?.name,
    });
    await Future.wait([refreshHeartRate(), refreshVitals()]);
  }

  Future<void> refreshHeartRate() async {
    if (!isAuthenticated) return;
    final generation = _sessionGeneration;
    final response = await api.recentHeartRate();
    if (generation != _sessionGeneration || _disposed) return;
    averageHeartRate = (response['average_bpm'] as num?)?.toDouble();
    heartRateSampleCount = (response['count'] as num?)?.toInt() ?? 0;
    notifyListeners();
  }

  Future<void> refreshWorkouts() async {
    if (!isAuthenticated) return;
    final generation = _sessionGeneration;
    final response = await api.workouts();
    if (generation != _sessionGeneration || _disposed) return;
    final rows = response['data'] as List? ?? const [];
    savedWorkouts = rows.whereType<Map>().map((row) {
      final metrics = row['metrics'] is Map ? row['metrics'] as Map : const {};
      final typeName = row['type'] as String?;
      return WorkoutSummary(
        type: ExerciseType.values.firstWhere(
          (type) => type.name == typeName,
          orElse: () => ExerciseType.workout,
        ),
        startTime: DateTime.parse(row['performed_at'] as String).toLocal(),
        heartRate: (metrics['last_heart_rate'] as num?)?.toInt() ?? 0,
        averageHeartRate: (metrics['average_heart_rate'] as num?)?.toInt(),
        maxHeartRate: (metrics['max_heart_rate'] as num?)?.toInt(),
        steps: (metrics['steps'] as num?)?.toInt() ?? 0,
        calories: (metrics['calories'] as num?)?.toDouble() ?? 0,
        durationSeconds:
            (metrics['duration_seconds'] as num?)?.toInt() ??
            ((row['duration_minutes'] as num?)?.toInt() ?? 0) * 60,
        distanceM: (metrics['distance_m'] as num?)?.toDouble() ?? 0,
        heartRateSamples: (metrics['heart_rate_samples'] is List)
            ? (metrics['heart_rate_samples'] as List)
                  .whereType<num>()
                  .map((v) => v.toInt())
                  .toList()
            : const [],
      );
    }).toList();
    notifyListeners();
  }

  Future<void> refreshHistory() async {
    await Future.wait([
      refreshHeartRate(),
      refreshVitals(),
      refreshWorkouts(),
      refreshSleep(),
      refreshSampleSummary(),
      refreshDailyActivity(),
      refreshProfile(),
    ]);
  }

  // ── Daily step goal (TZ §20) ─────────────────────────────────────────────

  static const _stepGoalKey = 'step_goal_v1';
  static const defaultStepGoal = 10000;
  static const minStepGoal = 1000;
  static const maxStepGoal = 50000;

  int stepGoal = defaultStepGoal;

  Future<void> setStepGoal(int goal) async {
    final clamped = goal.clamp(minStepGoal, maxStepGoal);
    if (clamped == stepGoal) return;
    stepGoal = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepGoalKey, clamped);
    } catch (_) {}
  }

  // ── Body profile (sex, birth date, height, weight) ───────────────────────

  /// From the server; sent to the band and used for heart-rate zones.
  BodyProfile bodyProfile = const BodyProfile();

  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    final generation = _sessionGeneration;
    final response = await api.me();
    if (generation != _sessionGeneration || _disposed) return;
    final user = response['user'];
    if (user is Map) {
      final profile = BodyProfile.fromUser(user);
      if (profile != bodyProfile) {
        bodyProfile = profile;
        notifyListeners();
      }
    }
  }

  Future<void> updateBodyProfile(BodyProfile profile) async {
    if (!isAuthenticated) throw StateError('Sign in first');
    final response = await api.updateProfile(profile.toApi());
    final user = response['user'];
    bodyProfile = user is Map ? BodyProfile.fromUser(user) : profile;
    notifyListeners();
  }

  // ── Band memory history (raw samples + daily totals) ─────────────────────

  /// Server summary of the last 24 h per metric: `{kind: {latest, latest_at,
  /// average, min, max, count}}`, built from synced band history.
  Map<String, Map<String, dynamic>> sampleSummary = const {};

  /// Daily totals saved on the server, newest first.
  List<Map<String, dynamic>> savedDailyActivity = const [];

  static const _historyCursorPrefix = 'band_history_cursor_v1_';
  static const _samplesPerRequest = 1000;

  /// Uploads what a band history sync produced. Only samples newer than the
  /// per-metric cursor are sent; the cursor advances only after the server
  /// accepted them, so a failed upload is retried on the next sync — the
  /// band still holds the data, and the server ignores duplicates anyway.
  Future<void> uploadBandHistory(
    List<BodySample> samples,
    List<DailyActivity> days, {
    BandVariant? model,
  }) async {
    final email = userEmail;
    if (!isAuthenticated || email == null || _disposed) return;
    final generation = _sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    final cursorKey = '$_historyCursorPrefix${Uri.encodeComponent(email)}';
    final cursor = <String, DateTime>{};
    final stored = prefs.getString(cursorKey);
    if (stored != null) {
      try {
        (jsonDecode(stored) as Map).forEach((k, v) {
          final at = DateTime.tryParse('$v');
          if (at != null) cursor['$k'] = at;
        });
      } catch (_) {}
    }

    final fresh = samples.where((s) {
      final last = cursor[s.metric.apiName];
      return last == null || s.at.isAfter(last);
    }).toList();

    for (var i = 0; i < fresh.length; i += _samplesPerRequest) {
      if (generation != _sessionGeneration || _disposed) return;
      final chunk = fresh.sublist(
        i,
        i + _samplesPerRequest > fresh.length
            ? fresh.length
            : i + _samplesPerRequest,
      );
      await api.storeSamples([
        for (final s in chunk)
          {
            'kind': s.metric.apiName,
            'measured_at': s.at.toUtc().toIso8601String(),
            'value': s.value,
          },
      ], deviceModel: model?.name);
      for (final s in chunk) {
        final last = cursor[s.metric.apiName];
        if (last == null || s.at.isAfter(last)) cursor[s.metric.apiName] = s.at;
      }
      await prefs.setString(
        cursorKey,
        jsonEncode(cursor.map((k, v) => MapEntry(k, v.toIso8601String()))),
      );
    }

    if (days.isNotEmpty && generation == _sessionGeneration && !_disposed) {
      await api.storeDailyActivity([
        for (final d in days.take(60))
          {
            'date':
                '${d.date.year.toString().padLeft(4, '0')}-'
                '${d.date.month.toString().padLeft(2, '0')}-'
                '${d.date.day.toString().padLeft(2, '0')}',
            'steps': d.steps,
            'distance_m': (d.distanceKm * 1000).round(),
            'calories': d.calories,
            'active_minutes': d.activeMinutes.clamp(0, 1440),
          },
      ], deviceModel: model?.name);
    }
    await Future.wait([refreshSampleSummary(), refreshDailyActivity()]);
  }

  Future<void> refreshSampleSummary() async {
    if (!isAuthenticated) return;
    final generation = _sessionGeneration;
    final response = await api.samplesSummary();
    if (generation != _sessionGeneration || _disposed) return;
    final raw = response['summary'];
    sampleSummary = raw is Map
        ? {
            for (final e in raw.entries)
              if (e.value is Map)
                '${e.key}': Map<String, dynamic>.from(e.value as Map),
          }
        : const {};
    notifyListeners();
  }

  Future<void> refreshDailyActivity() async {
    if (!isAuthenticated) return;
    final generation = _sessionGeneration;
    final response = await api.recentDailyActivity();
    if (generation != _sessionGeneration || _disposed) return;
    savedDailyActivity = (response['days'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    notifyListeners();
  }

  /// Retry both account-scoped queues and then reload saved server history.
  Future<void> synchronize() async {
    await Future.wait([retryPendingWorkouts(), retryPendingMeasurements()]);
    await refreshHistory();
  }

  Future<void> refreshPendingUploadCount() async {
    final email = userEmail;
    final generation = _sessionGeneration;
    final request = ++_pendingCountRequest;
    if (!isAuthenticated || email == null) return;
    final encoded = Uri.encodeComponent(email);
    final values = await Future.wait([
      _storage.read(key: 'pending_workouts_$encoded'),
      _storage.read(key: 'pending_measurements_$encoded'),
    ]);
    if (generation != _sessionGeneration ||
        request != _pendingCountRequest ||
        _disposed) {
      return;
    }
    var count = 0;
    for (final value in values) {
      if (value == null) continue;
      final decoded = jsonDecode(value);
      if (decoded is List) count += decoded.length;
    }
    if (pendingUploadCount == count) return;
    pendingUploadCount = count;
    notifyListeners();
  }

  Future<void> refreshVitals() async {
    if (!isAuthenticated) return;
    final generation = _sessionGeneration;
    final response = await api.recentVitals();
    if (generation != _sessionGeneration || _disposed) return;
    recentVitals = (response['snapshots'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    notifyListeners();
  }

  Future<void> refreshSleep() async {
    if (!isAuthenticated) return;
    final generation = _sessionGeneration;
    final response = await api.recentSleep();
    if (generation != _sessionGeneration || _disposed) return;
    savedSleepObservations = (response['observations'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    notifyListeners();
  }

  Future<void> retryPendingMeasurements() => _queueMeasurement(null);

  Future<void> _queueMeasurement(Map<String, dynamic>? incoming) {
    if (!isAuthenticated || userEmail == null || _disposed) {
      return incoming == null
          ? Future.value()
          : Future.error(StateError('Sign in before uploading'));
    }
    final generation = _sessionGeneration;
    final key = 'pending_measurements_${Uri.encodeComponent(userEmail!)}';
    final operation = _uploadSerial.then((_) async {
      if (generation != _sessionGeneration || _disposed) return;
      final stored = await _storage.read(key: key);
      final pending = stored == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(stored) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      if (incoming != null &&
          !pending.any((e) => e['client_id'] == incoming['client_id'])) {
        pending.add(incoming);
        await _storage.write(key: key, value: jsonEncode(pending));
        await refreshPendingUploadCount();
      }
      while (pending.isNotEmpty) {
        if (generation != _sessionGeneration || _disposed) return;
        final next = pending.first;
        if (next['kind'] == 'heart_rate') {
          await api.storeHeartRate(
            clientId: next['client_id'] as String,
            measuredAt: DateTime.parse(next['measured_at'] as String),
            bpm: next['bpm'] as int,
          );
        } else if (next['kind'] == 'vitals') {
          await api.storeVitals(
            clientId: next['client_id'] as String,
            measuredAt: DateTime.parse(next['measured_at'] as String),
            heartRate: (next['heart_rate'] as num?)?.toInt(),
            spo2: (next['spo2'] as num?)?.toInt(),
            temperatureC: (next['temperature_c'] as num?)?.toDouble(),
            steps: (next['steps'] as num?)?.toInt(),
            deviceModel: next['device_model'] as String?,
          );
        } else if (next['kind'] == 'sleep') {
          await api.storeSleepObservation(
            clientId: next['client_id'] as String,
            startedAt: DateTime.parse(next['started_at'] as String),
            endedAt: DateTime.parse(next['ended_at'] as String),
            observedMinutes: next['observed_minutes'] as int,
            stagesValidated: next['stages_validated'] as bool,
            records: next['records'] == null
                ? null
                : (next['records'] as List)
                      .map((row) => Map<String, dynamic>.from(row as Map))
                      .toList(),
          );
        }
        pending.removeAt(0);
        await _storage.write(key: key, value: jsonEncode(pending));
        await refreshPendingUploadCount();
      }
    });
    _uploadSerial = operation.catchError((_) {});
    return operation;
  }

  /// Save the observed interval even when the vendor stage mapping is unknown.
  /// Only validated sleep stages can populate the daily sleep metric.
  Future<void> uploadSleep(
    SleepSummary s, {
    List<SleepRecord> records = const [],
  }) async {
    if (!s.hasData || s.bedTime == null || s.wakeTime == null) return;
    await _queueMeasurement({
      'kind': 'sleep',
      'client_id': 'sleep-${s.bedTime!.toUtc().microsecondsSinceEpoch}',
      'started_at': s.bedTime!.toUtc().toIso8601String(),
      'ended_at': s.wakeTime!.toUtc().toIso8601String(),
      'observed_minutes': s.observedMinutes.clamp(1, 1440),
      'stages_validated': s.hasValidatedStages,
      'records': records
          .where(
            (record) =>
                record.rawValues.isNotEmpty &&
                record.start.isBefore(s.wakeTime!) &&
                record.start
                    .add(Duration(minutes: record.durationMinutes))
                    .isAfter(s.bedTime!),
          )
          .take(100)
          .map(
            (record) => {
              'start_at': record.start.toUtc().toIso8601String(),
              'unit_minutes': record.unitMinutes,
              'raw_values': record.rawValues.take(120).toList(),
            },
          )
          .toList(),
    });
    unawaited(refreshSleep().catchError((_) {}));
    if (s.hasValidatedStages) {
      await api.sleepCheckin(
        date: s.wakeTime,
        sleepHours: s.sleepMinutes / 60.0,
        sleepQuality: (s.score / 100.0).clamp(0.0, 1.0),
      );
    }
  }

  /// Rough 1..10 intensity derived from average heart rate. 60 bpm → ~1,
  /// 180 bpm → 10. Falls back to a moderate 5 when HR is unavailable.
  int _intensityFromHr(int hr) {
    if (hr <= 0) return 5;
    return (((hr - 60) / 12).round()).clamp(1, 10);
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    api.dispose();
    super.dispose();
  }
}

/// Exposes the [SessionController] to the widget tree. Rebuilds dependents when
/// auth state changes. Read it with `SessionScope.of(context)`.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope?.notifier != null, 'SessionScope not found');
    return scope!.notifier!;
  }
}
