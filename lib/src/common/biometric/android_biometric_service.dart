import 'package:local_auth/local_auth.dart';

import 'biometric_service.dart';

/// Implementación Android de [BiometricService].
///
/// Android gestiona el diálogo con BiometricPrompt internamente a través
/// de `local_auth`. Con [biometricOnly: true] no permite caer a PIN/patrón,
/// que es lo que queremos para verificación de identidad.
class AndroidBiometricService implements BiometricService {
  final _auth = LocalAuthentication();

  @override
  Future<bool> get isAvailable async {
    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    return canCheck && supported;
  }

  @override
  Future<List<BiometricType>> get availableTypes =>
      _auth.getAvailableBiometrics();

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para continuar',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}