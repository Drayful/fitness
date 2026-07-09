import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base URL of the fitness backend API.
///
/// The server sits behind an nginx reverse-proxy on port 80 reachable at the
/// machine's public IP. Port 8000 is blocked upstream by the provider, so we
/// go through nginx. Change this single constant if the server moves.
const String kApiBaseUrl = 'http://185.2.227.187';

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
    final uri = Uri.parse('$_baseUrl$path');
    late http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await _client.send(req).timeout(_timeout);
      res = await http.Response.fromStream(streamed);
    } catch (e) {
      throw ApiException('Нет связи с сервером. Проверьте интернет.');
    }

    final isJson =
        (res.headers['content-type'] ?? '').contains('application/json');
    final decoded = isJson && res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    // Laravel validation error shape: {message, errors: {field: [..]}}
    Map<String, List<String>>? fieldErrors;
    if (decoded['errors'] is Map) {
      fieldErrors = (decoded['errors'] as Map).map(
        (k, v) => MapEntry(
          k.toString(),
          (v as List).map((e) => e.toString()).toList(),
        ),
      );
    }
    final message = (decoded['message'] as String?) ??
        _statusMessage(res.statusCode);
    throw ApiException(message,
        statusCode: res.statusCode, fieldErrors: fieldErrors);
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
  }) =>
      _send('POST', '/api/auth/register',
          body: {'name': name, 'email': email, 'password': password});

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) =>
      _send('POST', '/api/auth/login',
          body: {'email': email, 'password': password});

  Future<void> logout() => _send('POST', '/api/auth/logout');

  Future<Map<String, dynamic>> me() => _send('GET', '/api/auth/me');

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createWorkout({
    required DateTime performedAt,
    required String type,
    required int durationMinutes,
    required int intensity,
    String? notes,
  }) =>
      _send('POST', '/api/workouts', body: {
        'performed_at': performedAt.toUtc().toIso8601String(),
        'type': type,
        'duration_minutes': durationMinutes,
        'intensity': intensity,
        'notes': ?notes,
      });

  Future<Map<String, dynamic>> sleepCheckin({
    DateTime? date,
    required double sleepHours,
    double? sleepQuality,
  }) =>
      _send('POST', '/api/checkins/sleep', body: {
        if (date != null)
          'date':
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'sleep_hours': sleepHours,
        'sleep_quality': ?sleepQuality,
      });

  Future<Map<String, dynamic>> todayScores() =>
      _send('GET', '/api/scores/today');

  void dispose() => _client.close();
}
