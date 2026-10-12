import 'package:local_auth/local_auth.dart';
import 'package:ottos_core/ottos_core.dart';

/// The phone's fingerprint (or face), through the system prompt.
class DeviceBiometrics implements BiometricAuth {
  DeviceBiometrics([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } catch (_) {
      // Cancelled, locked out after too many tries or no sensor: the password still works.
      return false;
    }
  }
}
