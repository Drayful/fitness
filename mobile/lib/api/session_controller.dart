import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../band/sleep_model.dart';
import '../band/workout_model.dart';
import 'api_client.dart';

/// Holds authentication state (Sanctum token + current user) and exposes
/// high-level actions the UI calls. Token is persisted in shared_preferences
/// so the user stays logged in across launches.
class SessionController extends ChangeNotifier {
  SessionController({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

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
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    userName = prefs.getString(_userNameKey);
    userEmail = prefs.getString(_userEmailKey);
    api.token = _token;
    _bootstrapping = false;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await api.register(name: name, email: email, password: password);
    await _applyAuth(res);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final res = await api.login(email: email, password: password);
    await _applyAuth(res);
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {
      // Even if the network call fails, drop the local session.
    }
    _token = null;
    api.token = null;
    userName = null;
    userEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    notifyListeners();
  }

  Future<void> _applyAuth(Map<String, dynamic> res) async {
    _token = res['token'] as String?;
    api.token = _token;
    final user = res['user'];
    if (user is Map) {
      userName = user['name'] as String?;
      userEmail = user['email'] as String?;
    }
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_tokenKey, _token!);
    if (userName != null) await prefs.setString(_userNameKey, userName!);
    if (userEmail != null) await prefs.setString(_userEmailKey, userEmail!);
    notifyListeners();
  }

  // ── Data uploads (band → API) ───────────────────────────────────────────────

  /// Push a finished workout to the backend. The DB stores summaries only, so
  /// the richer live metrics (steps, calories, distance, HR) are packed into
  /// [notes] to avoid losing them.
  Future<void> uploadWorkout(WorkoutSummary s) async {
    final minutes = (s.durationSeconds / 60).round().clamp(1, 600);
    final notes = 'steps=${s.steps}; kcal=${s.calories.round()}; '
        'dist=${s.distanceM.round()}m; hr=${s.heartRate}';
    await api.createWorkout(
      performedAt: s.startTime,
      type: s.type.name,
      durationMinutes: minutes,
      intensity: _intensityFromHr(s.heartRate),
      notes: notes,
    );
  }

  /// Push a sleep summary as the daily sleep metric.
  Future<void> uploadSleep(SleepSummary s) async {
    if (!s.hasData) return;
    await api.sleepCheckin(
      date: s.bedTime,
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
