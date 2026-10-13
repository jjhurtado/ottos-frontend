import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage(this.tokens);

  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async => tokens = null;
}

/// Answers each request with `routes[path](request)` and records the requests.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  final Map<String, (int, Object?) Function(RequestOptions)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = routes[options.path]!(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _me = {'id': 'u1', 'email': 'admin@ottos.test'};
const _unauthorized = (401, {'status': 401, 'detail': 'Unauthorized'});

void main() {
  late _MemoryTokenStorage storage;

  ApiClient clientWith(_FakeAdapter adapter) => ApiClient(
    config: const AppConfig(apiUrl: 'http://api'),
    tokenStorage: storage,
    dio: Dio()..httpClientAdapter = adapter,
  );

  setUp(() => storage = _MemoryTokenStorage(const AuthTokens(accessToken: 'old', refreshToken: 'r1')));

  test('refreshes the token on 401 and retries with the new one', () async {
    final adapter = _FakeAdapter({
      '/auth/me': (request) => request.headers['Authorization'] == 'Bearer new' ? (200, _me) : _unauthorized,
      '/auth/refresh': (_) => (200, {'accessToken': 'new', 'refreshToken': 'r2'}),
    });

    final me = await clientWith(adapter).get<Map<String, dynamic>>('/auth/me');

    expect(me, _me);
    expect(storage.tokens!.refreshToken, 'r2');
    expect(adapter.requests.map((request) => request.path), ['/auth/me', '/auth/refresh', '/auth/me']);
  });

  test('clears the session and fails when the refresh is rejected', () async {
    final client = clientWith(_FakeAdapter({'/auth/me': (_) => _unauthorized, '/auth/refresh': (_) => _unauthorized}));
    final expired = expectLater(client.sessionExpired, emits(null));

    await expectLater(
      client.get<Map<String, dynamic>>('/auth/me').timeout(const Duration(seconds: 2)),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    await expired;
    expect(storage.tokens, isNull);
  });

  test('fails when the retry is rejected too, without refreshing again', () async {
    final adapter = _FakeAdapter({
      '/remittances': (_) => _unauthorized,
      '/auth/refresh': (_) => (200, {'accessToken': 'new', 'refreshToken': 'r2'}),
    });

    await expectLater(
      clientWith(adapter).get<Map<String, dynamic>>('/remittances').timeout(const Duration(seconds: 2)),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(adapter.requests.map((request) => request.path), ['/remittances', '/auth/refresh', '/remittances']);
  });

  test('the mobile app says which build it is, and hears when the backend refuses it', () async {
    final adapter = _FakeAdapter({
      '/remittances': (_) => (
        426,
        {'status': 426, 'code': 'APP_UPDATE_REQUIRED', 'minimumBuild': 5, 'latestBuild': 6, 'latestVersion': '1.0.1'},
      ),
    });
    final api = ApiClient(
      config: const AppConfig(
        apiUrl: 'http://api',
        app: AppIdentity(platform: 'ANDROID', build: 4),
      ),
      tokenStorage: storage,
      dio: Dio()..httpClientAdapter = adapter,
    );
    final refused = api.updateRequired.first;

    await expectLater(
      api.get<Object>('/remittances'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'APP_UPDATE_REQUIRED')),
    );
    expect(adapter.requests.single.headers['X-App-Platform'], 'ANDROID');
    expect(adapter.requests.single.headers['X-App-Build'], '4');
    final version = await refused;
    expect(version.minimumBuild, 5);
    expect(version.updateFor(4), AppUpdate.required);
  });

  test('the panel sends no app headers', () async {
    final adapter = _FakeAdapter({'/auth/me': (_) => (200, _me)});
    await clientWith(adapter).get<Object>('/auth/me');
    expect(adapter.requests.single.headers.containsKey('X-App-Build'), isFalse);
  });
}
