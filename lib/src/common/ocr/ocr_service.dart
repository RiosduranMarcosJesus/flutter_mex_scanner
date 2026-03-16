import 'package:mi_app_verificadora/src/features/identity/domain/identity_data.dart';

/// Contrato para extraer texto plano de un archivo.
/// Recibe [parserStrategy] por si la implementación necesita saber
/// el tipo de documento para configurar el motor OCR (ej. idioma, orientación).
abstract class OcrService {
  Future<String> extractPlainText({
    required String filePath,
    required DocumentParserStrategy parserStrategy,
  });
}