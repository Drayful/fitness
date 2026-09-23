import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fitness_app/api/api_client.dart';

void main() {
  test('production API defaults to the configured public IP', () {
    expect(kApiBaseUrl, 'https://80.242.213.87');
  });
  test('rejects HTTP before sending credentials', () async {
    var sent = false;
    final api = ApiClient(
      baseUrl: 'http://example.test',
      client: MockClient((_) async {
        sent = true;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.login(email: 'user@test.test', password: 'secret'),
      throwsA(isA<ApiException>()),
    );
    expect(sent, isFalse);
    api.dispose();
  });
  for (final body in ['{broken', '[]']) {
    test('malformed JSON is a controlled error: $body', () async {
      final api = ApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(api.me(), throwsA(isA<ApiException>()));
      api.dispose();
    });
  }
  test('HTML success page is rejected', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('<html/>', 200)),
    );
    await expectLater(api.me(), throwsA(isA<ApiException>()));
    api.dispose();
  });
  test('trailing slash and HTTPS bearer token', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test/',
      client: MockClient((req) async {
        expect(req.url.toString(), 'https://example.test/api/auth/me');
        expect(req.headers['Authorization'], 'Bearer token');
        return http.Response(
          '{"user":{"id":1}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..token = 'token';
    expect((await api.me())['user']['id'], 1);
    api.dispose();
  });
}
