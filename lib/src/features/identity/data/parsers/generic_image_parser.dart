import '../../domain/identity_data.dart';

/// Parser genérico para imágenes y PDFs que no sean INE ni CURP.
/// Hace un best-effort: busca CURP, fecha y posibles nombres en el texto OCR.
/// Se puede especializar en el futuro sin tocar [DocParserFactory].
class GenericImageParser implements DocumentParserStrategy {
  const GenericImageParser();

  @override
  Future<IdentityData> process({
    required String ocrText,
    required String filePath,
  }) async {
    return IdentityData(
      idNumber: _extractCurp(ocrText),
      birthDate: _extractDate(ocrText),
      firstName: _extractFirstName(ocrText),
    );
  }

  String? _extractCurp(String text) {
    final match = RegExp(
      r'\b[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d\b',
    ).firstMatch(text.toUpperCase());
    return match?.group(0);
  }

  String? _extractDate(String text) =>
      RegExp(r'\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b').firstMatch(text)?.group(0);

  String? _extractFirstName(String text) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.length > 4 &&
          RegExp(r'^[A-ZÁÉÍÓÚÜÑ ]+$').hasMatch(t.toUpperCase()) &&
          t.split(' ').length >= 2) {
        return t;
      }
    }
    return null;
  }
}