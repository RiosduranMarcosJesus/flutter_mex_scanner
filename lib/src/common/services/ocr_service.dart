// Archivo: lib/src/common/services/ocr_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Excepción personalizada lanzada cuando el OCR no puede procesar la imagen.
///
/// Proporciona un [message] legible para mostrar al usuario y opcionalmente
/// la [cause] original para trazabilidad en desarrollo.
class OcrException implements Exception {
  /// Descripción legible del error ocurrido.
  final String message;

  /// Excepción original que causó el fallo, si está disponible.
  final Object? cause;

  /// Crea una [OcrException] con el [message] dado y una [cause] opcional.
  const OcrException(this.message, {this.cause});

  @override
  String toString() =>
      'OcrException: $message${cause != null ? ' (causa: $cause)' : ''}';
}

/// Servicio encargado de extraer texto de imágenes mediante OCR.
///
/// Usa el motor ML Kit de Google con el alfabeto latino, adecuado para
/// documentos oficiales mexicanos (INE, constancia CURP).
///
/// Uso típico:
/// ```dart
/// final service = OcrService();
/// try {
///   final text = await service.extraerTextoPlano('/path/to/image.jpg');
/// } on OcrException catch (e) {
///   // Mostrar e.message al usuario
/// }
/// ```
class OcrService {
  /// Motor de reconocimiento de texto con script latino.
  ///
  /// Se inicializa una sola vez y se cierra después de cada uso para
  /// liberar los recursos nativos de ML Kit.
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Extrae todo el texto visible de la imagen ubicada en [imagePath].
  ///
  /// Procesa la imagen con ML Kit y retorna el texto completo como
  /// una sola cadena. El orden del texto puede variar según el layout
  /// del documento detectado por el motor.
  ///
  /// Lanza [OcrException] si:
  /// - La ruta [imagePath] no corresponde a un archivo válido.
  /// - ML Kit no puede procesar la imagen (formato no soportado, imagen
  ///   corrupta, resolución insuficiente, etc.).
  ///
  /// Ejemplo:
  /// ```dart
  /// final rawText = await ocrService.extraerTextoPlano(photo.path);
  /// ```
  Future<String> extraerTextoPlano(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognized =
          await _textRecognizer.processImage(inputImage);

      final String result = recognized.text;
      debugPrint('OcrService: texto extraído (${result.length} chars)');
      return result;
    } catch (e) {
      debugPrint('OcrService error: $e');
      throw OcrException(
        'No se pudo leer el documento. '
        'Asegúrate de que la imagen sea clara y esté bien iluminada.',
        cause: e,
      );
    } finally {
      // Liberamos siempre los recursos nativos de ML Kit.
      await _textRecognizer.close();
    }
  }
}