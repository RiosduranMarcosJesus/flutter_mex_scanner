import '../../domain/identity_data.dart';

/// Parser para CURP (Constancia de la CURP del SAT/RENAPO).
///
/// Basado en el texto OCR real que devuelve ML Kit para este documento:
///
///   "Clave:"
///   "RIDM050419HPLSRRA7"        ← CURP en la línea siguiente
///   "Nombre"
///   "MARCOS JESUS RIOS DURAN"   ← nombre completo en una sola línea
///   "Entidad de registro:"
///   "PUEBLA"                    ← estado en línea siguiente
///
/// El OCR entrega mixed case ("Nombre", "Clave:") — comparamos en uppercase.
class CurpParser implements DocumentParserStrategy {
  const CurpParser();

  @override
  Future<IdentityData> process({
    required String ocrText,
    required String filePath,
  }) async {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final curp     = _extractCurp(ocrText);
    final fullName = _extractFullName(lines);
    final names    = _splitName(fullName);
    final state    = _extractState(lines);
    final birthDate = curp != null ? _decodeBirthDate(curp) : null;
    final sex       = curp != null ? _decodeSex(curp) : null;

    return IdentityData(
      idNumber:        curp,
      firstName:       names.$1,
      secondFirstName: names.$2,
      lastName:        names.$3,
      secondLastName:  names.$4,
      birthDate:       birthDate,
      sex:             sex,
      state:           state,
    );
  }

  // ── CURP ─────────────────────────────────────────────────────────
  // La CURP tiene 18 caracteres. El OCR a veces confunde el dígito
  // final: "7" puede leerse como "Z". Aceptamos ambos.
  String? _extractCurp(String text) {
    // Intento 1: patrón estricto
    final strict = RegExp(
      r'\b[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d\b',
    ).firstMatch(text.toUpperCase())?.group(0);
    if (strict != null) return strict;

    // Intento 2: patrón flexible (último char puede ser Z por OCR)
    final flexible = RegExp(
      r'\b[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9][0-9Z]\b',
    ).firstMatch(text.toUpperCase())?.group(0);
    if (flexible != null) {
      // Corrección: si termina en Z y parece dígito, lo mantenemos
      // — será validado más adelante con otros documentos
      return flexible;
    }
    return null;
  }

  // ── Nombre completo ───────────────────────────────────────────────
  // En la CURP el nombre aparece en la línea SIGUIENTE a "Nombre" o "NOMBRE"
  String? _extractFullName(List<String> lines) {
    for (int i = 0; i < lines.length - 1; i++) {
      final up = lines[i].toUpperCase().trim();
      if (up == 'NOMBRE' || up == 'NOMBRE:') {
        return lines[i + 1];
      }
    }
    // Fallback: línea que contenga varios nombres/apellidos en mayúsculas
    for (final line in lines) {
      if (_looksLikeFullName(line)) return line;
    }
    return null;
  }

  bool _looksLikeFullName(String s) {
    final up = s.toUpperCase().trim();
    return up.length > 8 &&
        RegExp(r'^[A-ZÁÉÍÓÚÜÑ ]+$').hasMatch(up) &&
        up.split(' ').length >= 3 && // al menos 3 tokens = nombres + apellidos
        !up.contains(RegExp(r'\d'));
  }

  // ── Separar nombre completo en partes ─────────────────────────────
  // La CURP de RENAPO imprime el nombre como:
  //   "MARCOS JESUS RIOS DURAN"
  // Con 4 tokens: nombre1 nombre2 apellidoPaterno apellidoMaterno
  // Con 3 tokens: nombre apellidoPaterno apellidoMaterno
  (String?, String?, String?, String?) _splitName(String? fullName) {
    if (fullName == null) return (null, null, null, null);
    final words = fullName.trim().toUpperCase().split(RegExp(r'\s+'));
    if (words.length == 4) {
      return (words[0], words[1], words[2], words[3]);
    } else if (words.length == 3) {
      return (words[0], null, words[1], words[2]);
    } else if (words.length >= 5) {
      // Nombre compuesto largo — tomamos últimos 2 como apellidos
      final lastTwo   = words.sublist(words.length - 2);
      final firstPart = words.sublist(0, words.length - 2);
      return (firstPart.first,
              firstPart.length > 1 ? firstPart.sublist(1).join(' ') : null,
              lastTwo[0], lastTwo[1]);
    }
    return (fullName, null, null, null);
  }

  // ── Estado ────────────────────────────────────────────────────────
  // Aparece en la línea siguiente a "Entidad de registro:" o "PUEBLA" suelto
  String? _extractState(List<String> lines) {
    for (int i = 0; i < lines.length - 1; i++) {
      final up = lines[i].toUpperCase();
      if (up.contains('ENTIDAD') && up.contains('REGISTRO')) {
        // Siguiente línea que no sea otra etiqueta
        for (int j = i + 1; j < lines.length; j++) {
          final next = lines[j].trim();
          if (next.isNotEmpty && !next.contains(':')) return next.toUpperCase();
        }
      }
    }
    // Fallback: buscar nombre de estado conocido
    final estados = [
      'AGUASCALIENTES','BAJA CALIFORNIA','BAJA CALIFORNIA SUR','CAMPECHE',
      'CHIAPAS','CHIHUAHUA','CIUDAD DE MEXICO','COAHUILA','COLIMA','DURANGO',
      'GUANAJUATO','GUERRERO','HIDALGO','JALISCO','MEXICO','MICHOACAN',
      'MORELOS','NAYARIT','NUEVO LEON','OAXACA','PUEBLA','QUERETARO',
      'QUINTANA ROO','SAN LUIS POTOSI','SINALOA','SONORA','TABASCO',
      'TAMAULIPAS','TLAXCALA','VERACRUZ','YUCATAN','ZACATECAS',
    ];
    final allText = lines.join(' ').toUpperCase();
    for (final e in estados) {
      if (allText.contains(e)) return e;
    }
    return null;
  }

  // ── Fecha desde CURP (pos 4–9: AAMMDD) ───────────────────────────
  String? _decodeBirthDate(String curp) {
    if (curp.length < 10) return null;
    final yy = curp.substring(4, 6);
    final mm = curp.substring(6, 8);
    final dd = curp.substring(8, 10);
    final yearInt = int.tryParse(yy);
    if (yearInt == null) return null;
    final fullYear = yearInt < 30 ? '20$yy' : '19$yy';
    return '$dd/$mm/$fullYear';
  }

  // ── Sexo desde CURP (pos 10: H/M) ────────────────────────────────
  Sex? _decodeSex(String curp) {
    if (curp.length <= 10) return null;
    return switch (curp[10]) {
      'H' => Sex.male,
      'M' => Sex.female,
      _   => null,
    };
  }
}