import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../band/sleep_model.dart';
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
  Future<void> _uploadSerial = Future.value();
  double? averageHeartRate;
  int heartRateSampleCount = 0;
  List<WorkoutSummary> savedWorkouts = const [];
  List<Map<String, dynamic>> savedSleepObservations = const [];

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
      final savedToken = await _storage.read(key: _tokenKey);
      final savedName = await _storage.read(key: _userNameKey);
      final savedEmail = await _storage.read(key: _userEmailKey);
      if (_disposed) return;
      _token = savedToken;
      userName = savedName;
      userEmail = savedEmail;
      api.token = _token;
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
    }
    await _storage.write(key: _userNameKey, value: userName);
    await _storage.write(key: _userEmailKey, value: userEmail);
    notifyListeners();
    unawaited(retryPendingWorkouts().catchError((_) {}));
    unawaited(retryPendingMeasurements().catchError((_) {}));
    unawaited(refreshHistory().catchError((_) {}));
  }

  // ── Data uploads (band → API) ───────────────────────────────────────────────

  /// Save pending summaries securely per account before attempting delivery.
  /// Stable IDs make a retry after a lost HTTP response safe on the backend.
  Future<void> uploadWorkout(WorkoutSummary s) {
    final payload = <String, dynamic>{
      'client_id':
          '${s.type.name}-${s.startTime.toUtc().microsecondsSinceEpoch}',
      'performed_at': s.startTime.toUtc().toIso8601String(),
      'type': s.type.name,
      'duration_minutes': (s.durationSeconds / 60).round().clamp(1, 600),
      'intensity': _intensityFromHr(s.heartRate),
      'metrics': {
        'steps': s.steps,
        'calories': s.calories,
        'distance_m': s.distanceM > 0 ? s.distanceM : null,
        'last_heart_rate': s.heartRate > 0 ? s.heartRate : null,
        'duration_seconds': s.durationSeconds,
      },
    };
    return _queueUpload(payload);
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
      }
      while (pending.isNotEmpty) {
        if (generation != _sessionGeneration || _disposed) return;
        final next = pending.first;
        await api.createWorkout(
          performedAt: DateTime.parse(next['performed_at'] as String),
          type: next['type'] as String,
          durationMinutes: next['duration_minutes'] as int,
          intensity: next['intensity'] as int,
          clientId: next['client_id'] as String,
          metrics: Map<String, dynamic>.from(next['metrics'] as Map),
        );
        pending.removeAt(0);
        await _storage.write(key: key, value: jsonEncode(pending));
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
        steps: (metrics['steps'] as num?)?.toInt() ?? 0,
        calories: (metrics['calories'] as num?)?.toDouble() ?? 0,
        durationSeconds:
            (metrics['duration_seconds'] as num?)?.toInt() ??
            ((row['duration_minutes'] as num?)?.toInt() ?? 0) * 60,
        distanceM: (metrics['distance_m'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> refreshHistory() async {
    await Future.wait([refreshHeartRate(), refreshWorkouts(), refreshSleep()]);
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
        } else if (next['kind'] == 'sleep') {
          await api.storeSleepObservation(
            clientId: next['client_id'] as String,
            startedAt: DateTime.parse(next['started_at'] as String),
            endedAt: DateTime.parse(next['ended_at'] as String),
            observedMinutes: next['observed_minutes'] as int,
            stagesValidated: next['stages_validated'] as bool,
          );
        }
        pending.removeAt(0);
        await _storage.write(key: key, value: jsonEncode(pending));
      }
    });
    _uploadSerial = operation.catchError((_) {});
    return operation;
  }

  /// Save the observed interval even when the vendor stage mapping is unknown.
  /// Only validated sleep stages can populate the daily sleep metric.
  Future<void> uploadSleep(SleepSummary s) async {
    if (!s.hasData || s.bedTime == null || s.wakeTime == null) return;
    await _queueMeasurement({
      'kind': 'sleep',
      'client_id': 'sleep-${s.bedTime!.toUtc().microsecondsSinceEpoch}',
      'started_at': s.bedTime!.toUtc().toIso8601String(),
      'ended_at': s.wakeTime!.toUtc().toIso8601String(),
      'observed_minutes': s.observedMinutes.clamp(1, 1440),
      'stages_validated': s.hasValidatedStages,
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
