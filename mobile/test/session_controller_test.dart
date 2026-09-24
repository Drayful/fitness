import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitness_app/api/api_client.dart';
import 'package:fitness_app/api/session_controller.dart';
import 'package:fitness_app/band/workout_model.dart';
import 'package:fitness_app/band/sleep_model.dart';

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
}
