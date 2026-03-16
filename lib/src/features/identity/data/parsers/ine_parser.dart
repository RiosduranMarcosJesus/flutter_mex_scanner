import '../../domain/identity_data.dart';

/// Parser para INE / Credencial para Votar (formato 2013 en adelante).
///
/// El layout de la INE moderna NO usa etiquetas como "APELLIDO PATERNO:"
/// antes de cada dato. Los datos aparecen en este orden fijo:
///
///   NOMBRE
///   [APELLIDO_PATERNO]          ← línea 1 después de "NOMBRE"
///   [APELLIDO_MATERNO]          ← línea 2
///   [NOMBRE(S)]                 ← línea 3
///
///   DOMICILIO
///   [calle y número]
///   [localidad y CP]
///   [municipio y estado]
///
///   CLAVE DE ELECTOR  [valor]
///   CURP              [valor]
///   FECHA DE NACIMIENTO  [dd/mm/yyyy]
///   SEXO [H|M]   (puede aparecer como "SEXO H" en esquina superior derecha)
///
/// El OCR de ML Kit devuelve el texto en el orden visual de lectura
/// (de arriba a abajo, de izquierda a derecha), por eso podemos
/// buscar por posición relativa después de las etiquetas clave.
class IneParser implements DocumentParserStrategy {
  const IneParser();

  @override
  Future<IdentityData> process({
    required String ocrText,
    required String filePath,
  }) async {
    final lines = _cleanLines(ocrText);

    return IdentityData(
      lastName:       _extractAfterLabel(lines, ['NOMBRE']) ?? _guessLastName(lines),
      secondLastName: _extractSecondLine(lines, ['NOMBRE']),
      firstName:      _extractThirdLine(lines, ['NOMBRE']),
      birthDate:      _extractDate(ocrText),
      idNumber:       _extractCurp(ocrText) ?? _extractClaveElector(ocrText),
      sex:            _extractSex(ocrText),
      address:        _extractAddress(lines),
      state:          _extractState(ocrText),
    );
  }

  // ── Limpieza ────────────────────────────────────────────────────

  List<String> _cleanLines(String text) => text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // ── Nombre / apellidos ─────────────────────────────────────────
  //
  // En la INE moderna el bloque de nombre tiene este aspecto en el OCR:
  //   "NOMBRE"
  //   "RIOS"           ← apellido paterno
  //   "DURAN"          ← apellido materno  (a veces en la misma línea: "RIOS\nDURAN")
  //   "MARCOS JESUS"   ← nombre(s)
  //
  // A veces el OCR lo junta: "RIOS\nDURAN\nMARCOS JESUS"
  // A veces lo separa con espacios extra o lo concatena en una línea.
  // Usamos múltiples estrategias y tomamos la primera que devuelva algo.

  String? _extractAfterLabel(List<String> lines, List<String> labels) {
    for (final label in labels) {
      final idx = lines.indexWhere((l) => l.toUpperCase() == label.toUpperCase());
      if (idx != -1 && idx + 1 < lines.length) return lines[idx + 1];
    }
    return null;
  }

  String? _extractSecondLine(List<String> lines, List<String> labels) {
    for (final label in labels) {
      final idx = lines.indexWhere((l) => l.toUpperCase() == label.toUpperCase());
      if (idx != -1 && idx + 2 < lines.length) return lines[idx + 2];
    }
    return null;
  }

  String? _extractThirdLine(List<String> lines, List<String> labels) {
    for (final label in labels) {
      final idx = lines.indexWhere((l) => l.toUpperCase() == label.toUpperCase());
      if (idx != -1 && idx + 3 < lines.length) return lines[idx + 3];
    }
    return null;
  }

  /// Fallback: si no encontró la etiqueta "NOMBRE", busca la primera línea
  /// que sea solo mayúsculas, sin números, de longitud razonable,
  /// que aparezca DESPUÉS de "INSTITUTO NACIONAL ELECTORAL" o "CREDENCIAL".
  String? _guessLastName(List<String> lines) {
    bool pastHeader = false;
    for (final line in lines) {
      final up = line.toUpperCase();
      if (up.contains('INSTITUTO') || up.contains('CREDENCIAL')) {
        pastHeader = true;
        continue;
      }
      if (!pastHeader) continue;
      if (_looksLikeName(line) && !_isKnownLabel(line)) {
        return line.toUpperCase();
      }
    }
    return null;
  }

  bool _looksLikeName(String s) =>
      s.length >= 3 &&
      s.length <= 40 &&
      RegExp(r'^[A-ZÁÉÍÓÚÜÑ ]+$').hasMatch(s.toUpperCase()) &&
      !s.contains(RegExp(r'\d'));

  bool _isKnownLabel(String s) {
    const labels = [
      'NOMBRE', 'DOMICILIO', 'CURP', 'SECCIÓN', 'SECCION',
      'VIGENCIA', 'CLAVE', 'FECHA', 'SEXO', 'MEXICO', 'MÉXICO',
      'INSTITUTO', 'NACIONAL', 'ELECTORAL', 'CREDENCIAL', 'VOTAR',
    ];
    return labels.any((l) => s.toUpperCase().contains(l));
  }

  // ── Domicilio ───────────────────────────────────────────────────

  String? _extractAddress(List<String> lines) {
    final idx = lines.indexWhere(
      (l) => l.toUpperCase().contains('DOMICILIO'),
    );
    if (idx == -1 || idx + 1 >= lines.length) return null;
    // Toma las siguientes 2 líneas y las une (calle + localidad/CP)
    final parts = <String>[];
    for (int i = idx + 1; i <= idx + 2 && i < lines.length; i++) {
      final line = lines[i];
      // Para si encontramos otra etiqueta conocida
      if (_isKnownLabel(line)) break;
      parts.add(line);
    }
    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  // ── CURP ────────────────────────────────────────────────────────

  String? _extractCurp(String text) {
    final match = RegExp(
      r'\b[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d\b',
    ).firstMatch(text.toUpperCase());
    return match?.group(0);
  }

  /// Fallback: clave de elector si la CURP no se reconoció.
  String? _extractClaveElector(String text) {
    // Clave de elector: 18 caracteres alfanuméricos después de "CLAVE DE ELECTOR"
    final match = RegExp(
      r'CLAVE\s+DE\s+ELECTOR\s+([A-Z0-9]{18})',
    ).firstMatch(text.toUpperCase());
    return match?.group(1);
  }

  // ── Fecha de nacimiento ─────────────────────────────────────────

  String? _extractDate(String text) {
    // Formato dd/mm/yyyy — el más común en la INE
    final match = RegExp(
      r'\b(\d{2})[\/\-](\d{2})[\/\-](\d{4})\b',
    ).firstMatch(text);
    if (match == null) return null;
    final mm = int.tryParse(match.group(2) ?? '') ?? 0;
    final dd = int.tryParse(match.group(1) ?? '') ?? 0;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
    return match.group(0);
  }

  // ── Sexo ────────────────────────────────────────────────────────

  Sex? _extractSex(String text) {
    final up = text.toUpperCase();
    // "SEXO H" o "SEXO M" — puede aparecer en cualquier parte
    if (RegExp(r'SEXO\s+H\b').hasMatch(up)) return Sex.male;
    if (RegExp(r'SEXO\s+M\b').hasMatch(up)) return Sex.female;
    // Fallback: posición 10 de la CURP
    final curp = _extractCurp(text);
    if (curp != null && curp.length > 10) {
      if (curp[10] == 'H') return Sex.male;
      if (curp[10] == 'M') return Sex.female;
    }
    return null;
  }

  // ── Estado ──────────────────────────────────────────────────────

  String? _extractState(String text) {
    // Busca "XICOTEPEC, PUE." o cualquier patrón "MUNICIPIO, ESTADO"
    final match = RegExp(
      r'\b([A-ZÁÉÍÓÚÜÑ]+),?\s*(PUE|JAL|CDMX|VER|OAX|CHIS|GRO|HGO|MEX|DF|NL|SLP|TAM|YUC|ZAC|AGS|BC|BCS|CAM|COA|COL|DGO|GTO|MOR|NAY|QRO|QROO|SIN|SON|TAB|TLAX)\b',
    ).firstMatch(text.toUpperCase());
    return match?.group(0);
  }
}