import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'current_user.dart';
import 'token_storage.dart';

/// Login, logout and the current user.
class AuthRepository {
  AuthRepository({required this._api, required this._tokenStorage});

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Stream<void> get sessionExpired => _api.sessionExpired;

  Future<CurrentUser> login({required String email, required String password}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    await _tokenStorage.write(AuthTokens.fromJson(json));
    return currentUser();
  }

  Future<CurrentUser> currentUser() async => CurrentUser.fromJson(await _api.get<Map<String, dynamic>>('/auth/me'));

  /// The stored session's user, or null if there is no valid session.
  Future<CurrentUser?> restoreSession() async {
    if (await _tokenStorage.read() == null) return null;
    try {
      return await currentUser();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokenStorage.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final tokens = await _tokenStorage.read();
    await _tokenStorage.clear();
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
