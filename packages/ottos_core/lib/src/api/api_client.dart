import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import '../config/app_config.dart';
import 'api_exception.dart';

/// HTTP client for the Ottos API.
///
/// Adds the access token to every request and, when the API answers 401,
/// refreshes the token once and retries. If the refresh fails the session is
/// cleared and [sessionExpired] emits, so the app can go back to login.
class ApiClient {
  ApiClient({required AppConfig config, required this._tokenStorage, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = config.apiBaseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..contentType = Headers.jsonContentType;
    _dio.interceptors.add(QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final _sessionExpired = StreamController<void>.broadcast();

  static const _skipAuth = 'skipAuth';
  static const _retried = 'retried';

  /// Emits when the session can no longer be refreshed.
  Stream<void> get sessionExpired => _sessionExpired.stream;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<T>(path, queryParameters: _withoutNulls(query)));

  Future<T> post<T>(String path, {Object? body, Map<String, String>? headers, bool authenticated = true}) => _send(
    () => _dio.post<T>(
      path,
      data: body,
      options: Options(headers: headers, extra: {_skipAuth: !authenticated}),
    ),
  );

  Future<T> put<T>(String path, {Object? body}) => _send(() => _dio.put<T>(path, data: body));

  Future<T> delete<T>(String path) => _send(() => _dio.delete<T>(path));

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[_skipAuth] != true) {
      final tokens = await _tokenStorage.read();
      if (tokens != null) options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final options = error.requestOptions;
    final canRefresh =
        error.response?.statusCode == 401 && options.extra[_skipAuth] != true && options.extra[_retried] != true;
    if (!canRefresh) return handler.next(error);

    final tokens = await _tokenStorage.read();
    // Another queued request may have refreshed the token already.
    final sentToken = (options.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
    if (tokens != null && tokens.accessToken != sentToken) {
      return _retry(options, tokens.accessToken, handler, error);
    }
    final refreshed = tokens == null ? null : await _refresh(tokens.refreshToken);
    if (refreshed == null) {
      await _tokenStorage.clear();
      _sessionExpired.add(null);
      return handler.next(error);
    }
    await _retry(options, refreshed.accessToken, handler, error);
  }

  Future<void> _retry(
    RequestOptions options,
    String accessToken,
    ErrorInterceptorHandler handler,
    DioException original,
  ) async {
    options
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..extra[_retried] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (error) {
      handler.next(error);
    }
  }

  Future<AuthTokens?> _refresh(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {_skipAuth: true}),
      );
      final tokens = AuthTokens.fromJson(response.data!);
      await _tokenStorage.write(tokens);
      return tokens;
    } on DioException {
      return null;
    }
  }

  static Map<String, dynamic>? _withoutNulls(Map<String, dynamic>? query) =>
      query == null ? null : (Map.of(query)..removeWhere((_, value) => value == null));

  Future<void> dispose() => _sessionExpired.close();
}
