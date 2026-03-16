import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:mi_app_verificadora/src/features/identity/domain/identity_data.dart';
import 'ocr_service.dart';

/// Extrae texto de imágenes (JPG / PNG) usando Google ML Kit.
/// Optimizado para texto en español / caracteres latinos.
class ImageOcrService implements OcrService {
  // Singleton del recognizer para no recrearlo en cada llamada.
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractPlainText({
    required String filePath,
    required DocumentParserStrategy parserStrategy,
  }) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final recognized = await _recognizer.processImage(inputImage);
    return recognized.text;
  }

  /// Llama esto cuando el servicio ya no se necesite
  /// (ej. al hacer dispose del provider que lo contiene).
  void dispose() => _recognizer.close();
}