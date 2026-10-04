import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitness_app/api/api_client.dart';
import 'package:fitness_app/api/session_controller.dart';
import 'package:fitness_app/band/band_history.dart';
import 'package:fitness_app/band/workout_model.dart';
import 'package:fitness_app/band/sleep_model.dart';
import 'package:fitness_app/band/band_variant.dart';
import 'package:fitness_app/band/v8_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed upload survives restart and retries with the same ID', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'old-plaintext'});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'secure-token',
      'auth_user_email': 'athlete@example.com',
    });
    final sent = <Map<String, dynamic>>[];
    var online = false;
    ApiClient client() => ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((req) async {
        sent.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(
          online ? '{"workout":{"id":1}}' : '{"message":"offline"}',
          online ? 201 : 503,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final first = SessionController(api: client());
    await first.load();
    expect(
      (await SharedPreferences.getInstance()).getString('auth_token'),
      isNull,
    );
    final workout = WorkoutSummary(
      type: ExerciseType.run,
      startTime: DateTime.utc(2026, 9, 18),
      heartRate: 0,
      steps: 100,
      calories: 10,
      durationSeconds: 120,
      distanceM: 0,
    );
    await expectLater(
      first.uploadWorkout(workout),
      throwsA(isA<ApiException>()),
    );
    first.dispose();
    online = true;
    final second = SessionController(api: client());
    await second.load();
    await second.retryPendingWorkouts();
    expect(sent, hasLength(2));
    expect(sent[0]['client_id'], sent[1]['client_id']);
    expect(sent[1]['metrics']['last_heart_rate'], isNull);
    await second.retryPendingWorkouts();
    expect(sent, hasLength(2));
    second.dispose();
  });

  test('workout heart-rate chart falls back when backend rejects it', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'secure-token',
      'auth_user_email': 'athlete@example.com',
    });
    final posted = <Map<String, dynamic>>[];
    final session = SessionController(
      api: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((req) async {
          if (req.method != 'POST' || req.url.path != '/api/workouts') {
            return http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          posted.add(body);
          // A backend that predates the chart rejects the unknown keys.
          final rejects = (body['metrics'] as Map).containsKey(
            'heart_rate_samples',
          );
          return http.Response(
            rejects ? '{"message":"invalid"}' : '{"workout":{"id":1}}',
            rejects ? 422 : 201,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    await session.load();
    await session.uploadWorkout(
      WorkoutSummary(
        type: ExerciseType.run,
        startTime: DateTime.utc(2026, 10, 4),
        heartRate: 120,
        steps: 100,
        calories: 10,
        durationSeconds: 15,
        distanceM: 0,
        heartRateSamples: const [95, 400, 118, 120],
      ),
    );
    expect(posted, hasLength(2));
    // Out-of-range readings are dropped before upload.
    expect(posted[0]['metrics']['heart_rate_samples'], [95, 118, 120]);
    expect(
      posted[0]['metrics']['heart_rate_sample_seconds'],
      WorkoutSummary.heartRateSampleSeconds,
    );
    expect(
      (posted[1]['metrics'] as Map).containsKey('heart_rate_samples'),
      isFalse,
    );
    expect(posted[1]['client_id'], posted[0]['client_id']);
    expect(session.pendingUploadCount, 0);
    session.dispose();
  });

  test('band history upload sends only new samples and retries on failure', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'secure-token',
      'auth_user_email': 'athlete@example.com',
    });
    final batches = <List<dynamic>>[];
    final dayPosts = <List<dynamic>>[];
    var online = true;
    final session = SessionController(
      api: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((req) async {
          final ok = http.Response(
            '{"stored":1}',
            200,
            headers: {'content-type': 'application/json'},
          );
          if (req.method != 'POST') {
            return http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (!online) {
            return http.Response(
              '{"message":"offline"}',
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == '/api/measurements/samples') {
            batches.add(body['samples'] as List);
          } else if (req.url.path == '/api/activity/daily') {
            dayPosts.add(body['days'] as List);
          }
          return ok;
        }),
      ),
    );
    await session.load();
    final t0 = DateTime.utc(2026, 10, 4, 22);
    final first = [
      BodySample(BodyMetric.heartRate, t0, 60),
      BodySample(BodyMetric.heartRate, t0.add(const Duration(minutes: 1)), 62),
      BodySample(BodyMetric.spo2, t0, 97),
    ];
    final day = DailyActivity(
      date: DateTime(2026, 10, 4),
      steps: 4200,
      activeMinutes: 30,
      distanceKm: 3.1,
      calories: 180.5,
    );
    await session.uploadBandHistory(first, [day]);
    expect(batches.single, hasLength(3));
    expect(batches.single.first['kind'], 'heart_rate');
    expect(dayPosts.single.single['date'], '2026-10-04');
    expect(dayPosts.single.single['distance_m'], 3100);

    // Next sync returns the same history plus one newer reading.
    final second = [
      ...first,
      BodySample(BodyMetric.heartRate, t0.add(const Duration(minutes: 2)), 64),
    ];
    online = false;
    await expectLater(
      session.uploadBandHistory(second, const []),
      throwsA(isA<ApiException>()),
    );
    online = true;
    await session.uploadBandHistory(second, const []);
    expect(batches, hasLength(2));
    expect(batches.last, hasLength(1)); // only the new reading
    expect(batches.last.single['value'], 64);
    session.dispose();
  });

  test('manual workout sends the chosen intensity', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'secure-token',
      'auth_user_email': 'athlete@example.com',
    });
    final posted = <Map<String, dynamic>>[];
    final session = SessionController(
      api: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((req) async {
          if (req.method == 'POST' && req.url.path == '/api/workouts') {
            posted.add(jsonDecode(req.body) as Map<String, dynamic>);
            return http.Response(
              '{"workout":{"id":1}}',
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    await session.load();
    await session.uploadWorkout(
      WorkoutSummary(
        type: ExerciseType.yoga,
        startTime: DateTime.utc(2026, 10, 4, 7),
        heartRate: 0,
        steps: 0,
        calories: 0,
        durationSeconds: 45 * 60,
        distanceM: 0,
      ),
      intensity: 3,
    );
    expect(posted.single['intensity'], 3);
    expect(posted.single['duration_minutes'], 45);
    expect(posted.single['type'], 'yoga');
    session.dispose();
  });

  test('deleting the account signs out and clears local queues', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'secure-token',
      'auth_user_email': 'athlete@example.com',
      'pending_workouts_athlete%40example.com': '[{"client_id":"w-1"}]',
    });
    String? deleteBody;
    final session = SessionController(
      api: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((req) async {
          if (req.method == 'DELETE' && req.url.path == '/api/auth/me') {
            deleteBody = req.body;
            return http.Response(
              '{"deleted":true}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          // Keep the pending workout from being sent during load().
          return http.Response(
            '{"message":"offline"}',
            503,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    await session.load();
    await session.deleteAccount('password123');
    expect(jsonDecode(deleteBody!), {'password': 'password123'});
    expect(session.isAuthenticated, isFalse);
    const storage = FlutterSecureStorage();
    expect(
      await storage.read(key: 'pending_workouts_athlete%40example.com'),
      isNull,
    );
    expect(await storage.read(key: 'auth_token'), isNull);
    session.dispose();
  });

  test('pending uploads are isolated by signed-in account', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'token-b',
      'auth_user_email': 'b@example.com',
      'pending_workouts_a%40example.com': '[{"client_id":"private-a"}]',
    });
    var requests = 0;
    final session = SessionController(
      api: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((req) async {
          if (req.method == 'POST') requests++;
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    await session.load();
    await session.retryPendingWorkouts();
    expect(requests, 0);
    session.dispose();
  });

  test('heart rate and unverified sleep are queued then uploaded', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'token-measurements',
      'auth_user_email': 'measurements@example.com',
    });
    var online = false;
    final posted = <String>[];
    final session = SessionController(
      api: ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((req) async {
          if (req.method == 'GET') {
            final body = req.url.path.endsWith('/heart-rate/recent')
                ? '{"average_bpm":72.5,"count":2,"samples":[]}'
                : req.url.path.endsWith('/sleep/recent')
                ? '{"observations":[]}'
                : '{"data":[]}';
            return http.Response(
              body,
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          posted.add(req.url.path);
          return http.Response(
            online ? '{}' : '{"message":"offline"}',
            online ? 201 : 503,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    await session.load();
    await expectLater(
      session.uploadHeartRate(72, DateTime.utc(2026, 9, 18, 10)),
      throwsA(isA<ApiException>()),
    );
    online = true;
    await session.retryPendingMeasurements();
    await session.refreshHeartRate();
    expect(session.averageHeartRate, 72.5);
    expect(posted.where((path) => path.endsWith('/heart-rate')).length, 2);

    final sleep = SleepSummary.fromRecords([
      SleepRecord(
        start: DateTime.utc(2026, 9, 18, 1),
        stages: const [SleepStage.unknown, SleepStage.unknown],
      ),
    ]);
    expect(sleep.hasValidatedStages, isFalse);
    expect(sleep.observedMinutes, 2);
    await session.uploadSleep(sleep);
    expect(posted.last, '/api/measurements/sleep');
    session.dispose();
  });

  test(
    'vitals remain queued offline and manual sync clears the queue',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'token-vitals',
        'auth_user_email': 'vitals@example.com',
      });
      var online = false;
      final posted = <Map<String, dynamic>>[];
      final session = SessionController(
        api: ApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((req) async {
            if (req.method == 'GET') {
              final body = req.url.path.endsWith('/heart-rate/recent')
                  ? '{"average_bpm":74,"count":1,"samples":[]}'
                  : req.url.path.endsWith('/vitals/recent')
                  ? '{"snapshots":[]}'
                  : req.url.path.endsWith('/sleep/recent')
                  ? '{"observations":[]}'
                  : '{"data":[]}';
              return http.Response(
                body,
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            posted.add(jsonDecode(req.body) as Map<String, dynamic>);
            return http.Response(
              online ? '{"snapshot":{}}' : '{"message":"offline"}',
              online ? 201 : 503,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      await session.load();
      await expectLater(
        session.uploadVitals(
          const LiveVitals(steps: 123, heartRate: 74, spo2: 98),
          DateTime.utc(2026, 9, 18, 10),
          model: BandVariant.jc2208a,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(session.pendingUploadCount, 1);
      online = true;
      await session.synchronize();
      expect(session.pendingUploadCount, 0);
      expect(posted, hasLength(2));
      expect(posted[0]['client_id'], posted[1]['client_id']);
      expect(posted[1]['device_model'], 'jc2208a');
      expect(posted[1]['spo2'], 98);
      session.dispose();
    },
  );
}
