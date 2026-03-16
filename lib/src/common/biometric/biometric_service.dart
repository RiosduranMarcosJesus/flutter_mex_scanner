import 'package:local_auth/local_auth.dart';

/// Contrato del servicio biométrico.
///
/// IMPORTANTE: Los tipos [BiometricType] (face, fingerprint, iris, weak, strong)
/// y el bool de resultado de autenticación vienen de la librería `local_auth`.
/// No redefinimos enums propios para eso — ya están ahí, los usamos tal cual.
///
/// Lo que sí abstraemos es el comportamiento diferente entre iOS y Android:
///   - iOS requiere un [localizedReason] muy descriptivo o el sistema lo rechaza.
///   - iOS puede mostrar Face ID vs Touch ID y tienen textos distintos.
///   - Android maneja BiometricPrompt con más opciones de fallback.
abstract class BiometricService {
  /// True si el dispositivo tiene hardware biométrico enrollado y disponible.
  Future<bool> get isAvailable;

  /// Lista de tipos biométricos que el dispositivo tiene registrados.
  /// Usa el [BiometricType] de `local_auth` directamente.
  Future<List<BiometricType>> get availableTypes;

  /// Lanza el diálogo biométrico nativo del sistema operativo.
  /// Retorna true si la autenticación fue exitosa.
  Future<bool> authenticate();
}