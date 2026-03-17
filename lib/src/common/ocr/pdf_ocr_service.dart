import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../features/identity/domain/identity_data.dart';
import 'ocr_service.dart';

/// Extrae texto de PDFs convirtiendo cada página a imagen y pasándola por ML Kit.
///
/// pdfx NO extrae texto nativo — renderiza a bitmap. Por eso combinamos:
///   1. pdfx renderiza cada página → PNG en memoria
///   2. ML Kit lee el texto del PNG
///   3. Concatenamos el texto de todas las páginas
class PdfOcrService implements OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractPlainText({
    required String filePath,
    required DocumentParserStrategy parserStrategy,
  }) async {
    final document = await PdfDocument.openFile(filePath);
    final buffer = StringBuffer();
    final tempDir = await getTemporaryDirectory();

    for (int i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);
      // Renderizamos a imagen con buena resolución para que ML Kit lea bien
      final pageImage = await page.render(
        width: page.width * 2,   // 2x para mejor OCR
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage?.bytes == null) continue;

      // Guardamos en temp para que ML Kit pueda leer desde ruta de archivo
      final tempFile = File('${tempDir.path}/pdf_page_$i.png');
      await tempFile.writeAsBytes(Uint8List.fromList(pageImage!.bytes!));

      try {
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final recognized = await _recognizer.processImage(inputImage);
        if (recognized.text.isNotEmpty) {
          buffer.writeln(recognized.text);
        }
      } finally {
        // Limpiamos el archivo temporal de la página
        if (tempFile.existsSync()) tempFile.deleteSync();
      }
    }

    await document.close();
    return buffer.toString();
  }

  void dispose() => _recognizer.close();
}