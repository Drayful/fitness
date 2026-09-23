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
      }
    });
    _uploadSerial = operation.catchError((_) {});
    return operation;
  }

  /// Push a sleep summary as the daily sleep metric.
  Future<void> uploadSleep(SleepSummary s) async {
    if (!s.hasValidatedStages) {
      throw StateError('Sleep interpretation is not verified');
    }
    await api.sleepCheckin(
      date: s.wakeTime,
      sleepHours: s.sleepMinutes / 60.0,
      sleepQuality: (s.score / 100.0).clamp(0.0, 1.0),
    );
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
