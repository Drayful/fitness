import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

/// Configure the API at build time. Release builds require HTTPS.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://80.242.213.87',
);

/// Thrown for any non-2xx response or transport failure. [message] is safe to
/// show to the user; [fieldErrors] carries Laravel validation messages keyed
/// by field name (e.g. {'email': ['Invalid credentials.']}).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors});

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON client around the Laravel API. Holds the Sanctum bearer token in
/// memory; persistence is handled by [SessionController].
class ApiClient {
  ApiClient({http.Client? client, String baseUrl = kApiBaseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  final http.Client _client;
  final String _baseUrl;

  String? token;

  static const _timeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['https', 'http'].contains(base.scheme)) {
      throw ApiException('Не настроен адрес API. Укажите API_BASE_URL.');
    }
    if (base.scheme != 'https' &&
        (kReleaseMode || !const bool.fromEnvironment('ALLOW_INSECURE_API'))) {
      throw ApiException('Для подключения к серверу требуется HTTPS.');
    }
    final uri = Uri.parse('${_baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    late http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      res = await (() async {
        final streamed = await _client.send(req);
        return http.Response.fromStream(streamed);
      })().timeout(_timeout);
    } catch (e) {
      throw ApiException('Нет связи с сервером. Проверьте интернет.');
    }

    final isJson = (res.headers['content-type'] ?? '').contains(
      'application/json',
    );
    Map<String, dynamic> decoded = {};
    if (isJson && res.body.isNotEmpty) {
      try {
        final value = jsonDecode(res.body);
        if (value is! Map<String, dynamic>) throw const FormatException();
        decoded = value;
      } on FormatException {
        throw ApiException(
          'Сервер вернул некорректный ответ.',
          statusCode: res.statusCode,
        );
      }
    } else if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        res.statusCode != 204) {
      throw ApiException(
        'Сервер вернул некорректный ответ.',
        statusCode: res.statusCode,
      );
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    // Laravel validation error shape: {message, errors: {field: [..]}}
    Map<String, List<String>>? fieldErrors;
    if (decoded['errors'] is Map) {
      fieldErrors = (decoded['errors'] as Map).map(
        (k, v) => MapEntry(
          k.toString(),
          v is List ? v.map((e) => e.toString()).toList() : [v.toString()],
        ),
      );
    }
    final message =
        (decoded['message'] is String ? decoded['message'] as String : null) ??
        _statusMessage(res.statusCode);
    throw ApiException(
      message,
      statusCode: res.statusCode,
      fieldErrors: fieldErrors,
    );
  }

  String _statusMessage(int code) => switch (code) {
    401 => 'Требуется вход в аккаунт.',
    403 => 'Доступ запрещён.',
    404 => 'Не найдено.',
    422 => 'Проверьте введённые данные.',
    >= 500 => 'Ошибка сервера. Попробуйте позже.',
    _ => 'Ошибка запроса ($code).',
  };

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) => _send(
    'POST',
    '/api/auth/register',
    body: {'name': name, 'email': email, 'password': password},
  );

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _send(
    'POST',
    '/api/auth/login',
    body: {'email': email, 'password': password},
  );

  Future<void> logout() => _send('POST', '/api/auth/logout');

  Future<Map<String, dynamic>> me() => _send('GET', '/api/auth/me');

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createWorkout({
    required DateTime performedAt,
    required String type,
    required int durationMinutes,
    required int intensity,
    String? notes,
    String? clientId,
    Map<String, dynamic>? metrics,
  }) => _send(
    'POST',
    '/api/workouts',
    body: {
      'performed_at': performedAt.toUtc().toIso8601String(),
      'type': type,
      'duration_minutes': durationMinutes,
      'intensity': intensity,
      'notes': ?notes,
      'client_id': ?clientId,
      'metrics': ?metrics,
    },
  );

  Future<Map<String, dynamic>> sleepCheckin({
    DateTime? date,
    required double sleepHours,
    double? sleepQuality,
  }) => _send(
    'POST',
    '/api/checkins/sleep',
    body: {
      if (date != null)
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'sleep_hours': sleepHours,
      'sleep_quality': ?sleepQuality,
    },
  );

  Future<Map<String, dynamic>> todayScores() =>
      _send('GET', '/api/scores/today');

  Future<Map<String, dynamic>> storeHeartRate({
    required String clientId,
    required DateTime measuredAt,
    required int bpm,
  }) => _send(
    'POST',
    '/api/measurements/heart-rate',
    body: {
      'client_id': clientId,
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'bpm': bpm,
    },
  );

  Future<Map<String, dynamic>> recentHeartRate() =>
      _send('GET', '/api/measurements/heart-rate/recent');

  Future<Map<String, dynamic>> storeVitals({
    required String clientId,
    required DateTime measuredAt,
    int? heartRate,
    int? spo2,
    double? temperatureC,
    int? steps,
    String? deviceModel,
  }) => _send(
    'POST',
    '/api/measurements/vitals',
    body: {
      'client_id': clientId,
      'measured_at': measuredAt.toUtc().toIso8601String(),
      'heart_rate': ?heartRate,
      'spo2': ?spo2,
      'temperature_c': ?temperatureC,
      'steps': ?steps,
      'device_model': ?deviceModel,
    },
  );

  Future<Map<String, dynamic>> recentVitals() =>
      _send('GET', '/api/measurements/vitals/recent');

  /// Batched raw readings from the band's memory; idempotent per
  /// metric + timestamp on the server.
  Future<Map<String, dynamic>> storeSamples(
    List<Map<String, dynamic>> samples, {
    String? deviceModel,
  }) => _send(
    'POST',
    '/api/measurements/samples',
    body: {'device_model': ?deviceModel, 'samples': samples},
  );

  Future<Map<String, dynamic>> samplesSummary({int hours = 24}) =>
      _send('GET', '/api/measurements/samples/summary?hours=$hours');

  Future<Map<String, dynamic>> storeDailyActivity(
    List<Map<String, dynamic>> days, {
    String? deviceModel,
  }) => _send(
    'POST',
    '/api/activity/daily',
    body: {'device_model': ?deviceModel, 'days': days},
  );

  Future<Map<String, dynamic>> recentDailyActivity() =>
      _send('GET', '/api/activity/daily/recent');

  Future<Map<String, dynamic>> storeSleepObservation({
    required String clientId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int observedMinutes,
    required bool stagesValidated,
    List<Map<String, dynamic>>? records,
  }) => _send(
    'POST',
    '/api/measurements/sleep',
    body: {
      'client_id': clientId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'observed_minutes': observedMinutes,
      'stages_validated': stagesValidated,
      'records': ?records,
    },
  );

  Future<Map<String, dynamic>> recentSleep() =>
      _send('GET', '/api/measurements/sleep/recent');

  Future<Map<String, dynamic>> workouts() => _send('GET', '/api/workouts');

  void dispose() => _client.close();
}
