import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/core_texts.dart';

/// What the login keeps on this device: the remembered email and, for
/// fingerprint login, the credentials (in the system's secure storage).
abstract interface class LoginMemory {
  Future<String?> rememberedEmail();
  Future<void> rememberEmail(String? email);

  /// The account the fingerprint login opens, without asking for the fingerprint.
  Future<String?> biometricEmail();

  /// The saved credentials. Where [promptsOnRead], reading them asks for the
  /// fingerprint; null when it was refused or nothing usable is saved.
  Future<({String email, String password})?> biometricCredentials();

  /// Saves them; false when the system refused (no strong fingerprint, cancelled).
  Future<bool> saveBiometricCredentials(String email, String password);
  Future<void> clearBiometricCredentials();

  /// Deletes what was saved before the password was bound to the biometric
  /// (SEC-1). Run once at every app start, with or without a session.
  Future<void> removeLegacyCredentials();

  /// The system itself asks for the fingerprint when the saved password is read.
  bool get promptsOnRead;

  /// The system itself asks for the fingerprint when the password is saved.
  bool get promptsOnSave;
}

/// Checks the person with the phone's fingerprint or face before using the
/// saved credentials. Only the mobile app has one.
abstract interface class BiometricAuth {
  /// The device can and has enrolled a fingerprint or face.
  Future<bool> isAvailable();

  /// Asks for it, saying [reason]; true if it matched.
  Future<bool> authenticate(String reason);
}

/// The fingerprint login's password is bound to the biometric (SEC-1): on
/// Android the key that encrypts it needs a strong biometric for every read
/// and write; on iOS the Keychain item needs the fingerprints or face enrolled
/// now, stays on this device and is not in backups. The email is kept apart,
/// without that protection, to show which account the button opens.
class SecureLoginMemory implements LoginMemory {
  SecureLoginMemory({FlutterSecureStorage? storage, FlutterSecureStorage? biometricStorage, TargetPlatform? platform})
    : _storage = storage ?? const FlutterSecureStorage(),
      _biometricStorage = biometricStorage ?? boundStorage,
      _platform = platform ?? (kIsWeb ? null : defaultTargetPlatform);

  static const _emailKey = 'ottos.login.email';
  static const _biometricEmailKey = 'ottos.login.biometric.account';
  static const _biometricPasswordKey = 'ottos.login.biometric.secret';

  /// Before SEC-1 the password was kept without the biometric binding.
  static const _legacyKeys = ['ottos.login.biometric.email', 'ottos.login.biometric.password'];

  /// The storage bound to the biometric, on its own namespace (Android) or
  /// service (iOS) so the session and the remembered email never prompt.
  static const boundStorage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: true,
      requireBiometricsPerOperation: true,
      biometricType: AndroidBiometricType.strongBiometricOnly,
      storageNamespace: 'ottos_biometric_login',
      biometricPromptTitle: CoreTexts.biometricLogin,
      biometricPromptSubtitle: CoreTexts.biometricPromptSubtitle,
      biometricPromptNegativeButton: CoreTexts.cancel,
    ),
    iOptions: IOSOptions(
      accountName: 'ottos_biometric_login',
      accessibility: KeychainAccessibility.passcode,
      accessControlFlags: [AccessControlFlag.biometryCurrentSet],
    ),
  );

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage _biometricStorage;
  final TargetPlatform? _platform;

  @override
  bool get promptsOnRead => _platform == TargetPlatform.android || _platform == TargetPlatform.iOS;

  @override
  bool get promptsOnSave => _platform == TargetPlatform.android;

  @override
  Future<String?> rememberedEmail() => _storage.read(key: _emailKey);

  @override
  Future<void> rememberEmail(String? email) =>
      email == null ? _storage.delete(key: _emailKey) : _storage.write(key: _emailKey, value: email);

  @override
  Future<String?> biometricEmail() => _storage.read(key: _biometricEmailKey);

  @override
  Future<void> removeLegacyCredentials() async {
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
    }
  }

  @override
  Future<({String email, String password})?> biometricCredentials() async {
    final email = await biometricEmail();
    if (email == null) return null;
    final String? password;
    try {
      password = await _biometricStorage.read(key: _biometricPasswordKey);
    } on PlatformException {
      // Cancelled or not recognised: the saved login stays for another try.
      return null;
    }
    // Gone with the key, e.g. a fingerprint was added or removed: forget it.
    if (password == null) await clearBiometricCredentials();
    return password == null ? null : (email: email, password: password);
  }

  @override
  Future<bool> saveBiometricCredentials(String email, String password) async {
    try {
      // Deleted first: on iOS updating a protected item would ask for the fingerprint.
      await _biometricStorage.delete(key: _biometricPasswordKey);
      await _biometricStorage.write(key: _biometricPasswordKey, value: password);
    } on PlatformException {
      return false;
    }
    await _storage.write(key: _biometricEmailKey, value: email);
    return true;
  }

  @override
  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: _biometricEmailKey);
    try {
      await _biometricStorage.delete(key: _biometricPasswordKey);
    } on PlatformException {
      // Without the email the password is never read again.
    }
  }
}
