// Archivo: lib/src/common/services/biometric_service.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

/// Resultado posible de un intento de autenticación biométrica.
enum BiometricResult {
  /// El usuario se autenticó correctamente.
  authenticated,

  /// La autenticación falló (huella/face no coincidió).
  failed,

  /// El dispositivo no cuenta con hardware biométrico disponible.
  notAvailable,

  /// Ocurrió un error inesperado durante el proceso.
  error,
}

/// Servicio encargado de gestionar la autenticación biométrica del dispositivo.
///
/// Utiliza el paquete `local_auth` para solicitar huella dactilar, Face ID
/// o, como respaldo, el PIN / patrón / contraseña del sistema operativo.
///
/// Uso típico:
/// ```dart
/// final service = BiometricService();
/// final result = await service.authenticate();
/// if (result == BiometricResult.authenticated) { ... }
/// ```
class BiometricService {
  /// Instancia interna del plugin de autenticación local.
  final LocalAuthentication _auth = LocalAuthentication();

  /// Comprueba si el dispositivo puede realizar autenticación biométrica.
  ///
  /// Retorna `true` cuando:
  /// - El hardware soporta biometría o credenciales del dispositivo.
  /// - Al menos una credencial (huella, face, PIN) está enrollada.
  ///
  /// Retorna `false` en cualquier otro caso o si ocurre un error.
  Future<bool> get isAvailable async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
      if (!canCheck) return false;

      final List<BiometricType> enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('BiometricService.isAvailable error: $e');
      return false;
    }
  }

  /// Devuelve la lista de métodos biométricos disponibles en el dispositivo.
  ///
  /// Puede incluir [BiometricType.fingerprint], [BiometricType.face],
  /// [BiometricType.iris], entre otros según el hardware.
  Future<List<BiometricType>> get availableTypes async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometricService.availableTypes error: $e');
      return [];
    }
  }

  /// Solicita al usuario que se autentique antes de escanear un documento.
  ///
  /// Muestra el diálogo nativo del sistema operativo con el mensaje
  /// [reason] como texto explicativo. Si el dispositivo no soporta
  /// biometría o no tiene credenciales enrolladas, se permite continuar
  /// directamente ([BiometricResult.notAvailable]).
  ///
  /// El parámetro [useDeviceCredentials] (por defecto `true`) habilita
  /// el respaldo con PIN / patrón / contraseña del sistema cuando la
  /// biometría falla o el usuario lo solicita.
  ///
  /// Retorna un [BiometricResult] según el desenlace:
  /// - [BiometricResult.authenticated] → acceso permitido.
  /// - [BiometricResult.failed]        → autenticación rechazada.
  /// - [BiometricResult.notAvailable]  → sin biometría, se permite continuar.
  /// - [BiometricResult.error]         → error del sistema.
  Future<BiometricResult> authenticate({
    String reason =
        'Confirma tu identidad para escanear el documento',
    bool useDeviceCredentials = true,
  }) async {
    // Si el dispositivo no tiene biometría disponible, dejamos pasar.
    final bool available = await isAvailable;
    if (!available) {
      debugPrint('BiometricService: no biometrics available, skipping auth.');
      return BiometricResult.notAvailable;
    }

    try {
      final bool success = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          // Permite usar PIN/patrón/contraseña como respaldo.
          biometricOnly: !useDeviceCredentials,
          // Mantiene el diálogo visible si el usuario falla el primer intento.
          stickyAuth: true,
          // Muestra opción de cancelar para no bloquear al usuario.
          sensitiveTransaction: true,
        ),
      );

      debugPrint('BiometricService.authenticate result: $success');
      return success ? BiometricResult.authenticated : BiometricResult.failed;
    } on PlatformException catch (e) {
      debugPrint('BiometricService PlatformException: ${e.code} — ${e.message}');
      // Código `notAvailable` o `passcodeNotSet` → no bloqueamos al usuario.
      if (e.code == 'NotAvailable' ||
          e.code == 'notAvailable' ||
          e.code == 'PasscodeNotSet' ||
          e.code == 'passcodeNotSet') {
        return BiometricResult.notAvailable;
      }
      return BiometricResult.error;
    } catch (e) {
      debugPrint('BiometricService unexpected error: $e');
      return BiometricResult.error;
    }
  }
}