import 'package:local_auth/local_auth.dart';

import 'biometric_service.dart';

/// Implementación iOS de [BiometricService].
///
/// iOS exige un [localizedReason] claro y en el idioma del usuario,
/// de lo contrario el sistema rechaza la solicitud silenciosamente.
/// También permitimos caer a passcode ([biometricOnly: false]) porque
/// iOS lo maneja de forma segura y es la UX esperada por el usuario.
class IosBiometricService implements BiometricService {
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
        localizedReason:
            'Usamos Face ID o Touch ID para verificar tu identidad '
            'antes de procesar tu documento.',
        options: const AuthenticationOptions(
          // iOS: false permite caer al passcode del sistema como respaldo seguro
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}