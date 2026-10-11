import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../config/app_config.dart';
import 'current_user.dart';
import 'token_storage.dart';

/// Login, logout and the current user.
class AuthRepository {
  AuthRepository({required this._api, required this._tokenStorage, this.client = AppClient.web, this._userCache});

  final ApiClient _api;
  final TokenStorage _tokenStorage;
  final AppClient client;

  /// Mobile only: opens the app without network as the last user.
  final UserCache? _userCache;

  Stream<void> get sessionExpired => _api.sessionExpired;

  Future<CurrentUser> login({required String email, required String password}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'email': email.trim(), 'password': password, 'client': client.code},
      authenticated: false,
    );
    await _tokenStorage.write(AuthTokens.fromJson(json));
    final user = await currentUser();
    await _userCache?.write(user);
    return user;
  }

  Future<CurrentUser> currentUser() async => CurrentUser.fromJson(await _api.get<Map<String, dynamic>>('/auth/me'));

  /// The stored session's user, or null if there is no valid session.
  Future<CurrentUser?> restoreSession() async {
    if (await _tokenStorage.read() == null) return null;
    try {
      final user = await currentUser();
      await _userCache?.write(user);
      return user;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokenStorage.clear();
        await _userCache?.clear();
        return null;
      }
      // No network: the mobile app goes on with the last user; it syncs later.
      final cached = error.statusCode == null ? await _userCache?.read() : null;
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> logout() async {
    final tokens = await _tokenStorage.read();
    await _tokenStorage.clear();
    await _userCache?.clear();
    if (tokens == null) return;
    try {
      await _api.post<void>('/auth/logout', body: {'refreshToken': tokens.refreshToken}, authenticated: false);
    } on ApiException {
      // The local session is gone either way; the refresh token expires on its own.
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      _api.post<void>('/auth/change-password', body: {'currentPassword': currentPassword, 'newPassword': newPassword});
}
