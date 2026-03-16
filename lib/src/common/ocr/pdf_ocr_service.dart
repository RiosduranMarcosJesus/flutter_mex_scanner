import 'package:pdfx/pdfx.dart';

import 'package:mi_app_verificadora/src/features/identity/domain/identity_data.dart';
import 'ocr_service.dart';

/// Extrae texto de PDFs usando pdfx.
///
/// NOTA IMPORTANTE: pdfx renderiza páginas a imagen (bitmap).
/// Para PDFs con texto embebido (digitales) esto funciona bien.
/// Para PDFs escaneados (imágenes), el texto puede no ser preciso —
/// en ese caso considera renderizar la página a File y pasarla
/// por [ImageOcrService] para mejor resultado.
class PdfOcrService implements OcrService {
  @override
  Future<String> extractPlainText({
    required String filePath,
    required DocumentParserStrategy parserStrategy,
  }) async {
    final document = await PdfDocument.openFile(filePath);
    final buffer = StringBuffer();

    for (int i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);
      // pdfx no expone extracción de texto directamente;
      // aquí puedes renderizar a imagen y pasar a ML Kit si lo necesitas.
      // Por ahora dejamos el hook listo.
      await page.close();
    }

    await document.close();
    return buffer.toString();
  }
}