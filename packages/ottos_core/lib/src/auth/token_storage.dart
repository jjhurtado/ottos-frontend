import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'current_user.dart';

/// Access and refresh tokens returned by `/auth/login` and `/auth/refresh`.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      AuthTokens(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String);

  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() => {'accessToken': accessToken, 'refreshToken': refreshToken};
}

/// Keeps the tokens between app launches.
abstract interface class TokenStorage {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// [TokenStorage] backed by the platform keychain/keystore (encrypted
/// storage on web).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ottos.tokens';

  final FlutterSecureStorage _storage;
  AuthTokens? _cache;

  @override
  Future<AuthTokens?> read() async {
    if (_cache != null) return _cache;
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return _cache = AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    _cache = tokens;
    await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: _key);
  }
}

/// The last user who logged in, so the mobile app can open without network.
abstract interface class UserCache {
  Future<CurrentUser?> read();
  Future<void> write(CurrentUser user);
  Future<void> clear();
}

class SecureUserCache implements UserCache {
  SecureUserCache([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ottos.user';

  final FlutterSecureStorage _storage;

  @override
  Future<CurrentUser?> read() async {
    final raw = await _storage.read(key: _key);
    return raw == null ? null : CurrentUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(CurrentUser user) => _storage.write(key: _key, value: jsonEncode(user.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
