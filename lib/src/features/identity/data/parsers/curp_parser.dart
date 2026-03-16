import '../../domain/identity_data.dart';

/// Parser para CURP impresa o en imagen.
/// La CURP tiene 18 caracteres con información codificada:
///   Pos 0–3   : iniciales (apellido paterno, materno, nombre, segunda letra)
///   Pos 4–9   : fecha de nacimiento AAMMDD
///   Pos 10    : sexo H/M
///   Pos 11–12 : clave de entidad federativa
///   Pos 13–15 : consonantes internas
///   Pos 16    : diferenciador histórico
///   Pos 17    : dígito verificador
class CurpParser implements DocumentParserStrategy {
  const CurpParser();

  @override
  Future<IdentityData> process({
    required String ocrText,
    required String filePath,
  }) async {
    final curp = _extractCurp(ocrText);
    if (curp == null) return const IdentityData();

    return IdentityData(
      idNumber: curp,
      birthDate: _decodeBirthDate(curp),
      // El nombre no está codificado completo en la CURP,
      // pero se puede intentar leer del texto OCR circundante.
      firstName: _extractName(ocrText),
      lastName: _extractLastName(ocrText),
    );
  }

  String? _extractCurp(String text) {
    final match = RegExp(
      r'\b[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d\b',
    ).firstMatch(text.toUpperCase());
    return match?.group(0);
  }

  /// Decodifica la fecha de nacimiento desde la CURP (pos 4–9: AAMMDD).
  String? _decodeBirthDate(String curp) {
    if (curp.length < 10) return null;
    final yy = curp.substring(4, 6);
    final mm = curp.substring(6, 8);
    final dd = curp.substring(8, 10);
    // Asume siglo XXI para YY < 30, XX para YY >= 30 (criterio RENAPO).
    final year = int.parse(yy) < 30 ? '20$yy' : '19$yy';
    return '$dd/$mm/$year';
  }

  String? _extractName(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    // Busca etiquetas comunes en documentos CURP del SAT / RENAPO
    final idx = lines.indexWhere(
      (l) => l.toUpperCase().contains('NOMBRE(S)') ||
          l.toUpperCase().contains('NOMBRES'),
    );
    if (idx != -1 && idx + 1 < lines.length) return lines[idx + 1];
    return null;
  }

  String? _extractLastName(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    final idx = lines.indexWhere(
      (l) => l.toUpperCase().contains('PRIMER APELLIDO') ||
          l.toUpperCase().contains('APELLIDO PATERNO'),
    );
    if (idx != -1 && idx + 1 < lines.length) return lines[idx + 1];
    return null;
  }
}