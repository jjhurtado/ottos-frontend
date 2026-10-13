import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import '../config/app_config.dart';
import '../models/app_version.dart';
import 'api_exception.dart';

/// HTTP client for the Ottos API.
///
/// Adds the access token to every request and, when the API answers 401,
/// refreshes the token once and retries. If the refresh fails the session is
/// cleared and [sessionExpired] emits, so the app can go back to login.
class ApiClient {
  ApiClient({required AppConfig config, required this._tokenStorage, Dio? dio}) : _dio = dio ?? Dio() {
    final app = config.app;
    _dio.options
      ..baseUrl = config.apiBaseUrl
      ..headers.addAll({
        if (app != null) 'X-App-Platform': app.platform,
        if (app != null) 'X-App-Build': '${app.build}',
      })
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..contentType = Headers.jsonContentType;
    // Refresh and retry go through a client without the interceptor: a queued
    // interceptor waits for its current error to finish, so an error from a
    // request sent while handling one would never be handled.
    _bareDio = Dio(_dio.options)..httpClientAdapter = _dio.httpClientAdapter;
    _dio.interceptors.add(QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio _dio;
  late final Dio _bareDio;
  final TokenStorage _tokenStorage;
  final _sessionExpired = StreamController<void>.broadcast();
  final _updateRequired = StreamController<AppVersion>.broadcast();

  static const _skipAuth = 'skipAuth';

  /// Emits when the session can no longer be refreshed.
  Stream<void> get sessionExpired => _sessionExpired.stream;

  /// Emits when the backend refuses this build of the app (426), with what to
  /// update to.
  Stream<AppVersion> get updateRequired => _updateRequired.stream;

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
      final response = error.response;
      final data = response?.data;
      if (response?.statusCode == 426 && data is Map<String, dynamic>) {
        _updateRequired.add(AppVersion.fromJson(data));
      }
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
    final canRefresh = error.response?.statusCode == 401 && options.extra[_skipAuth] != true;
    if (!canRefresh) return handler.next(error);

    final tokens = await _tokenStorage.read();
    // Another queued request may have refreshed the token already.
    final sentToken = (options.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
    if (tokens != null && tokens.accessToken != sentToken) {
      return _retry(options, tokens.accessToken, handler, error);
    }
    final refreshed = tokens == null ? null : await _refresh(tokens.refreshToken);
    if (identical(refreshed, _unreachable)) {
      // No network: the session may still be good; keep it and fail this request.
      return handler.next(error);
    }
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
    options.headers['Authorization'] = 'Bearer $accessToken';
    try {
      handler.resolve(await _bareDio.fetch<dynamic>(options));
    } on DioException catch (error) {
      handler.next(error);
    }
  }

  /// Returned by [_refresh] when the server could not be reached.
  static const _unreachable = AuthTokens(accessToken: '', refreshToken: '');

  /// New tokens; null if the server rejected the refresh token, or
  /// [_unreachable] without network (the app keeps working offline and
  /// retries later; the backend accepts a retry within its grace window).
  Future<AuthTokens?> _refresh(String refreshToken) async {
    try {
      final response = await _bareDio.post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refreshToken});
      final tokens = AuthTokens.fromJson(response.data!);
      await _tokenStorage.write(tokens);
      return tokens;
    } on DioException catch (error) {
      return error.response == null ? _unreachable : null;
    }
  }

  static Map<String, dynamic>? _withoutNulls(Map<String, dynamic>? query) =>
      query == null ? null : (Map.of(query)..removeWhere((_, value) => value == null));

  Future<void> dispose() async {
    await _sessionExpired.close();
    await _updateRequired.close();
  }
}
