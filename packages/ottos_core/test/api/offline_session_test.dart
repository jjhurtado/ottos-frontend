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

class _MemoryUserCache implements UserCache {
  CurrentUser? user;

  @override
  Future<CurrentUser?> read() async => user;

  @override
  Future<void> write(CurrentUser user) async => this.user = user;

  @override
  Future<void> clear() async => user = null;
}

/// Answers by path; a null answer is a network failure (no response).
class _Adapter implements HttpClientAdapter {
  _Adapter(this.routes);

  final Map<String, (int, Object?)? Function(RequestOptions)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final answer = routes[options.path]!(options);
    if (answer == null) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    final (status, body) = answer;
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

const _me = {
  'id': 'u1',
  'email': 'courier@ottos.test',
  'name': 'Luis',
  'permissions': ['remittances:read-assigned'],
};
const _unauthorized = (401, {'status': 401, 'detail': 'Unauthorized'});

void main() {
  late _MemoryTokenStorage tokens;
  late _MemoryUserCache cache;

  setUp(() {
    tokens = _MemoryTokenStorage(const AuthTokens(accessToken: 'old', refreshToken: 'r1'));
    cache = _MemoryUserCache();
  });

  ApiClient client(_Adapter adapter) => ApiClient(
    config: const AppConfig(apiUrl: 'http://api'),
    tokenStorage: tokens,
    dio: Dio()..httpClientAdapter = adapter,
  );

  test('a refresh without network keeps the session', () async {
    final api = client(_Adapter({'/auth/me': (_) => _unauthorized, '/auth/refresh': (_) => null}));
    var expired = false;
    api.sessionExpired.listen((_) => expired = true);

    await expectLater(api.get<Object?>('/auth/me'), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);

    expect(tokens.tokens, isNotNull);
    expect(expired, isFalse);
  });

  test('a rejected refresh still ends the session', () async {
    final api = client(_Adapter({'/auth/me': (_) => _unauthorized, '/auth/refresh': (_) => _unauthorized}));

    await expectLater(api.get<Object?>('/auth/me'), throwsA(isA<ApiException>()));

    expect(tokens.tokens, isNull);
  });

  test('the mobile app logs in as MOBILE and opens offline as the last user', () async {
    var online = true;
    final adapter = _Adapter({
      '/auth/login': (_) => (200, {'accessToken': 'a', 'refreshToken': 'r'}),
      '/auth/me': (_) => online ? (200, _me) : null,
    });
    final auth = AuthRepository(api: client(adapter), tokenStorage: tokens, client: AppClient.mobile, userCache: cache);

    await auth.login(email: 'courier@ottos.test', password: 'x');
    expect((adapter.requests.first.data as Map)['client'], 'MOBILE');

    online = false;
    final restored = await auth.restoreSession();

    expect(restored?.email, 'courier@ottos.test');
    expect(restored?.can(Permissions.remittancesReadAssigned), isTrue);
  });

  test('the panel does not open offline', () async {
    final auth = AuthRepository(api: client(_Adapter({'/auth/me': (_) => null})), tokenStorage: tokens);

    await expectLater(auth.restoreSession(), throwsA(isA<ApiException>()));
  });

  test('logging out forgets the user', () async {
    cache.user = CurrentUser.fromJson(_me);
    final auth = AuthRepository(
      api: client(_Adapter({'/auth/logout': (_) => (204, null)})),
      tokenStorage: tokens,
      client: AppClient.mobile,
      userCache: cache,
    );

    await auth.logout();

    expect(cache.user, isNull);
  });
}
