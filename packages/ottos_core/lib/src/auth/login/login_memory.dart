import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What the login keeps on this device: the remembered email and, for
/// fingerprint login, the credentials (in the system's secure storage).
abstract interface class LoginMemory {
  Future<String?> rememberedEmail();
  Future<void> rememberEmail(String? email);

  Future<({String email, String password})?> biometricCredentials();
  Future<void> saveBiometricCredentials(String email, String password);
  Future<void> clearBiometricCredentials();
}

/// Checks the person with the phone's fingerprint or face before using the
/// saved credentials. Only the mobile app has one.
abstract interface class BiometricAuth {
  /// The device can and has enrolled a fingerprint or face.
  Future<bool> isAvailable();

  /// Asks for it, saying [reason]; true if it matched.
  Future<bool> authenticate(String reason);
}

class SecureLoginMemory implements LoginMemory {
  SecureLoginMemory([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _emailKey = 'ottos.login.email';
  static const _biometricEmailKey = 'ottos.login.biometric.email';
  static const _biometricPasswordKey = 'ottos.login.biometric.password';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> rememberedEmail() => _storage.read(key: _emailKey);

  @override
  Future<void> rememberEmail(String? email) =>
      email == null ? _storage.delete(key: _emailKey) : _storage.write(key: _emailKey, value: email);

  @override
  Future<({String email, String password})?> biometricCredentials() async {
    final email = await _storage.read(key: _biometricEmailKey);
    final password = await _storage.read(key: _biometricPasswordKey);
    return email == null || password == null ? null : (email: email, password: password);
  }

  @override
  Future<void> saveBiometricCredentials(String email, String password) async {
    await _storage.write(key: _biometricEmailKey, value: email);
    await _storage.write(key: _biometricPasswordKey, value: password);
  }

  @override
  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: _biometricEmailKey);
    await _storage.delete(key: _biometricPasswordKey);
  }
}
