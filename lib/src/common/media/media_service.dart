import 'dart:io';

/// Contrato para obtener archivos del dispositivo (cámara / galería / archivos).
///
/// No es una interfaz formal con `interface` keyword porque iOS y Android
/// comparten la misma firma pública pero difieren en:
///   - Cómo solicitan y verifican permisos en runtime.
///   - Las opciones disponibles del picker nativo.
///   - El comportamiento especial de iOS con PHPickerViewController.
///
/// El `if (Platform.isAndroid / isIOS)` vive en [providers.dart] al
/// momento de registrar la implementación concreta — aquí solo el contrato.
abstract class MediaService {
  /// Abre la cámara trasera y devuelve la foto, o null si el usuario cancela.
  Future<File?> takePhoto();

  /// Abre el selector de archivos del sistema.
  /// Si [allowPdf] es true intenta abrir el selector de documentos.
  Future<File?> pickFile({bool allowPdf = false});
}