import '../../domain/identity_data.dart';

/// Parser para INE / Credencial para Votar (formato 2013 en adelante).
///
/// Layout del bloque NOMBRE en la INE moderna (orden OCR de arriba a abajo):
///   "NOMBRE"
///   "RIOS"            ← apellido paterno  (línea idx+1)
///   "DURAN"           ← apellido materno  (línea idx+2)
///   "MARCOS JESUS"    ← nombre(s)         (línea idx+3)
///
/// El OCR a veces entrega los nombres en una sola línea separados por espacio.
/// En ese caso intentamos dividir: primera palabra = primer nombre,
/// resto = segundo nombre (si tiene).
class IneParser implements DocumentParserStrategy {
  const IneParser();

  @override
  Future<IdentityData> process({
    required String ocrText,
    required String filePath,
  }) async {
    final lines = _cleanLines(ocrText);
    final nameBlock = _extractNameBlock(lines);

    return IdentityData(
      lastName:        nameBlock.$1,
      secondLastName:  nameBlock.$2,
      firstName:       nameBlock.$3,
      secondFirstName: nameBlock.$4,
      birthDate:       _extractDate(ocrText),
      idNumber:        _extractCurp(ocrText) ?? _extractClaveElector(ocrText),
      sex:             _extractSex(ocrText),
      address:         _extractAddress(lines),
      state:           _extractState(lines),
    );
  }

  // ── Limpieza ──────────────────────────────────────────────────────

  List<String> _cleanLines(String text) => text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // ── Bloque de nombres ─────────────────────────────────────────────
  //
  // Retorna (apellidoPaterno, apellidoMaterno, primerNombre, segundoNombre)
  // Cualquiera puede ser null si no se encontró.

  (String?, String?, String?, String?) _extractNameBlock(List<String> lines) {
    final idx = lines.indexWhere((l) => l.toUpperCase() == 'NOMBRE');

    if (idx != -1) {
      final lastName       = _safeGet(lines, idx + 1);
      final secondLastName = _safeGet(lines, idx + 2);
      final fullFirstName  = _safeGet(lines, idx + 3);
      final split          = _splitFirstNames(fullFirstName);
      return (lastName, secondLastName, split.$1, split.$2);
    }

    // Fallback: intentar reconstruir desde el bloque visual
    return _fallbackNameBlock(lines);
  }

  /// Divide "MARCOS JESUS" → ("MARCOS", "JESUS")
  /// Si solo hay una palabra → ("MARCOS", null)
  (String?, String?) _splitFirstNames(String? fullName) {
    if (fullName == null) return (null, null);
    // Normalizar acentos del OCR antes de dividir
    final clean = _removeOcrAccentNoise(fullName);
    final words = clean.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return (words[0], null);
    return (words[0], words.sublist(1).join(' '));
  }

  /// El OCR a veces agrega acentos donde no corresponde (DURĀN, JÉSUS).
  /// Los normalizamos para presentación limpia.
  String _removeOcrAccentNoise(String s) => s
      .replaceAll('Ā', 'A').replaceAll('Ē', 'E')
      .replaceAll('Ī', 'I').replaceAll('Ō', 'O')
      .replaceAll('Ū', 'U')
      .replaceAll('ā', 'a').replaceAll('ē', 'e')
      .replaceAll('ī', 'i').replaceAll('ō', 'o')
      .replaceAll('ū', 'u');

  String? _safeGet(List<String> lines, int idx) =>
      (idx < lines.length && _looksLikeName(lines[idx]) && !_isKnownLabel(lines[idx]))
          ? _removeOcrAccentNoise(lines[idx])
          : null;

  /// Fallback cuando el OCR no detectó la etiqueta "NOMBRE" exacta.
  /// Busca el primer bloque de líneas consecutivas que parezcan apellidos/nombres
  /// después del encabezado "INSTITUTO NACIONAL ELECTORAL".
  (String?, String?, String?, String?) _fallbackNameBlock(List<String> lines) {
    bool pastHeader = false;
    final nameLines = <String>[];

    for (final line in lines) {
      final up = line.toUpperCase();
      if (up.contains('INSTITUTO') || up.contains('CREDENCIAL')) {
        pastHeader = true;
        continue;
      }
      if (!pastHeader) continue;
      if (_isKnownLabel(line)) {
        if (nameLines.isNotEmpty) break; // ya recogimos el bloque
        continue;
      }
      if (_looksLikeName(line)) {
        nameLines.add(_removeOcrAccentNoise(line));
        if (nameLines.length == 3) break;
      }
    }

    if (nameLines.isEmpty) return (null, null, null, null);
    final split = _splitFirstNames(nameLines.length >= 3 ? nameLines[2] : null);
    return (
      nameLines.isNotEmpty ? nameLines[0] : null,
      nameLines.length >= 2 ? nameLines[1] : null,
      split.$1,
      split.$2,
    );
  }

  bool _looksLikeName(String s) =>
      s.length >= 2 &&
      s.length <= 50 &&
      RegExp(r'^[A-ZÁÉÍÓÚÜÑĀĒĪŌŪ ]+$').hasMatch(s.toUpperCase()) &&
      !s.contains(RegExp(r'\d'));

  bool _isKnownLabel(String s) {
    const labels = [
      'NOMBRE', 'DOMICILIO', 'CURP', 'SECCIÓN', 'SECCION',
      'VIGENCIA', 'CLAVE', 'FECHA', 'SEXO', 'MEXICO', 'MÉXICO',
      'INSTITUTO', 'NACIONAL', 'ELECTORAL', 'CREDENCIAL', 'VOTAR',
      'REGISTRO', 'SECCIÓN',
    ];
    return labels.any((l) => s.toUpperCase().contains(l));
  }

  // ── Domicilio ─────────────────────────────────────────────────────

  String? _extractAddress(List<String> lines) {
    final idx = lines.indexWhere(
      (l) => l.toUpperCase().contains('DOMICILIO'),
    );
    if (idx == -1 || idx + 1 >= lines.length) return null;
    final parts = <String>[];
    for (int i = idx + 1; i <= idx + 2 && i < lines.length; i++) {
      final line = lines[i];
      if (_isKnownLabel(line)) break;
      parts.add(line);
    }
    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  // ── CURP ──────────────────────────────────────────────────────────

  String? _extractCurp(String text) {
    final match = RegExp(
      r'\b[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d\b',
    ).firstMatch(text.toUpperCase());
    return match?.group(0);
  }

  String? _extractClaveElector(String text) {
    final match = RegExp(
      r'CLAVE\s+DE\s+ELECTOR\s+([A-Z0-9]{18})',
    ).firstMatch(text.toUpperCase());
    return match?.group(1);
  }

  // ── Fecha ─────────────────────────────────────────────────────────

  String? _extractDate(String text) {
    final match = RegExp(
      r'\b(\d{2})[\/\-](\d{2})[\/\-](\d{4})\b',
    ).firstMatch(text);
    if (match == null) return null;
    final mm = int.tryParse(match.group(2) ?? '') ?? 0;
    final dd = int.tryParse(match.group(1) ?? '') ?? 0;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
    return match.group(0);
  }

  // ── Sexo ──────────────────────────────────────────────────────────

  Sex? _extractSex(String text) {
    final up = text.toUpperCase();
    if (RegExp(r'SEXO\s+H\b').hasMatch(up)) return Sex.male;
    if (RegExp(r'SEXO\s+M\b').hasMatch(up)) return Sex.female;
    final curp = _extractCurp(text);
    if (curp != null && curp.length > 10) {
      if (curp[10] == 'H') return Sex.male;
      if (curp[10] == 'M') return Sex.female;
    }
    return null;
  }

  // ── Estado ────────────────────────────────────────────────────────
  //
  // En la INE el estado aparece como ÚLTIMA palabra del domicilio:
  //   "XICOTEPEC, PUE." — ciudad + abreviatura de estado
  // El problema anterior: buscaba en todo el texto y encontraba
  // "ZARAGOZA SIN" (calle Ignacio Zaragoza + abrev. Sinaloa) — falso positivo.
  // Solución: buscamos la abreviatura solo como token FINAL de línea.

  String? _extractState(List<String> lines) {
    const abbrevs = {
      'PUE': 'PUEBLA', 'JAL': 'JALISCO', 'CDMX': 'CIUDAD DE MEXICO',
      'VER': 'VERACRUZ', 'OAX': 'OAXACA', 'CHIS': 'CHIAPAS',
      'GRO': 'GUERRERO', 'HGO': 'HIDALGO', 'MEX': 'ESTADO DE MEXICO',
      'NL': 'NUEVO LEON', 'SLP': 'SAN LUIS POTOSI', 'TAM': 'TAMAULIPAS',
      'YUC': 'YUCATAN', 'ZAC': 'ZACATECAS', 'AGS': 'AGUASCALIENTES',
      'BC': 'BAJA CALIFORNIA', 'BCS': 'BAJA CALIFORNIA SUR',
      'CAM': 'CAMPECHE', 'COA': 'COAHUILA', 'COL': 'COLIMA',
      'DGO': 'DURANGO', 'GTO': 'GUANAJUATO', 'MOR': 'MORELOS',
      'NAY': 'NAYARIT', 'QRO': 'QUERETARO', 'QROO': 'QUINTANA ROO',
      'SIN': 'SINALOA', 'SON': 'SONORA', 'TAB': 'TABASCO', 'TLAX': 'TLAXCALA',
      'DF': 'CIUDAD DE MEXICO',
    };

    final pattern = RegExp(
      r'\b([A-ZÁÉÍÓÚÜÑ]+)[,\s]+(' + abbrevs.keys.join('|') + r')\.?\s*$',
    );

    // Búsqueda 1: solo dentro del bloque DOMICILIO
    bool inDom = false;
    for (final line in lines) {
      final up = line.toUpperCase().trim();
      if (up.contains('DOMICILIO')) { inDom = true; continue; }
      if (!inDom) continue;
      if (_isKnownLabel(line) && !up.contains('DOMICILIO')) break;

      final m = pattern.firstMatch(up);
      if (m != null) {
        return '${m.group(1)}, ${abbrevs[m.group(2)] ?? m.group(2)}';
      }
    }

    // Búsqueda 2: fallback en cualquier línea pero evitando nombres de calles
    for (final line in lines) {
      final up = line.toUpperCase().trim();
      if (up.startsWith('C ') || up.startsWith('AV ') ||
          up.startsWith('BLVD') || up.contains(' SN') ||
          up.contains(' S/N') || up.contains('CALLE')) continue;
      final m = pattern.firstMatch(up);
      if (m != null) {
        return '${m.group(1)}, ${abbrevs[m.group(2)] ?? m.group(2)}';
      }
    }
    return null;
  }
}

/// Extensión del parser para extraer apellido materno desde la CURP
/// cuando el OCR no lo encontró en las líneas de texto.
///
/// La CURP codifica: posición 0 = inicial apellido paterno,
/// posición 1 = vocal interna apellido paterno,
/// posición 2 = inicial apellido materno,   ← esto usamos
/// posición 3 = inicial nombre.
/// No podemos reconstruir el apellido completo, pero sí la inicial,
/// que sirve para validación cruzada.
extension IneParserCurpFallback on IneParser {
  String? extractSecondLastNameInitialFromCurp(String ocrText) {
    final curp = RegExp(
      r'\b[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d\b',
    ).firstMatch(ocrText.toUpperCase())?.group(0);
    if (curp == null || curp.length < 3) return null;
    // pos 2 = inicial del apellido materno
    return '${curp[2]}...';
  }
}