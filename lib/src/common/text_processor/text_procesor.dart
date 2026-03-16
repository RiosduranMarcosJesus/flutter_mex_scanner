import '../../features/identity/domain/identity_data.dart';

/// Utilidades puras para extraer y validar datos desde texto OCR.
/// Sin estado, sin dependencias externas — fácil de testear unitariamente.
/// Se registra como singleton en los providers de Riverpod.
class TextProcessor {
  const TextProcessor();

  /// Extrae un CURP válido (18 chars) del texto OCR.
  /// Retorna null si no encuentra ninguno.
  String? extractCurp(String textOCR) {
    final match = RegExp(
      r'\b[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d\b',
    ).firstMatch(textOCR.toUpperCase());
    return match?.group(0);
  }

  /// Intenta extraer el nombre completo del texto OCR.
  /// Busca la primera línea que parezca un nombre propio:
  /// solo letras, mínimo 2 palabras, mínimo 5 caracteres.
  String? extractName(String textOCR) {
    for (final line in textOCR.split('\n')) {
      final t = line.trim();
      if (t.length >= 5 &&
          RegExp(r'^[A-ZÁÉÍÓÚÜÑ ]+$').hasMatch(t.toUpperCase()) &&
          t.split(' ').length >= 2) {
        return t;
      }
    }
    return null;
  }

  /// Extrae el sexo desde una CURP.
  ///
  /// En la CURP el sexo está siempre en la posición 10:
  ///   H = Hombre, M = Mujer (criterio RENAPO).
  /// Retorna 'H', 'M', o null si la CURP es inválida / no se encontró.
  ///
  /// Funciona tanto para INE como para CURP porque ambos documentos
  /// contienen la CURP completa impresa.
  String? extractSexFromCurp(String textOCR) {
    final curp = extractCurp(textOCR);
    if (curp == null || curp.length < 11) return null;
    final char = curp[10]; // posición 10 = H o M
    return (char == 'H' || char == 'M') ? char : null;
  }

  /// Extrae la fecha de nacimiento COMPLETA desde una CURP.
  ///
  /// La CURP codifica la fecha como AAMMDD en las posiciones 4–9.
  /// El año solo tiene 2 dígitos, así que inferimos el siglo:
  ///   YY < 30  → 20YY  (nacido entre 2000–2029)
  ///   YY >= 30 → 19YY  (nacido entre 1930–1999)
  /// Este es el criterio oficial de RENAPO.
  ///
  /// Retorna la fecha en formato dd/MM/yyyy o null si no hay CURP.
  String? extractBirthDateFromCurp(String textOCR) {
    final curp = extractCurp(textOCR);
    if (curp == null || curp.length < 10) return null;

    final yy = curp.substring(4, 6); // pos 4-5 = año
    final mm = curp.substring(6, 8); // pos 6-7 = mes
    final dd = curp.substring(8, 10); // pos 8-9 = día

    final yearInt = int.tryParse(yy);
    if (yearInt == null) return null;

    // Criterio RENAPO para el siglo
    final fullYear = yearInt < 30 ? '20$yy' : '19$yy';
    return '$dd/$mm/$fullYear';
  }

  /// Extrae una fecha de nacimiento desde texto libre del OCR.
  ///
  /// Útil para INE donde la fecha aparece impresa en formato dd/mm/yyyy
  /// o dd-mm-yyyy, no solo codificada en la CURP.
  /// Si el documento tiene ambas, prefiere la impresa porque es más legible
  /// por el OCR que los caracteres pequeños de la CURP.
  String? extractBirthDateFromText(String textOCR) {
    // Busca el patrón dd/mm/yyyy o dd-mm-yyyy
    final match = RegExp(
      r'\b(\d{2})[\/\-](\d{2})[\/\-](\d{4})\b',
    ).firstMatch(textOCR);
    if (match == null) return null;

    // Validación básica de rango (mes 1-12, día 1-31)
    final mm = int.tryParse(match.group(2) ?? '');
    final dd = int.tryParse(match.group(1) ?? '');
    if (mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    return match.group(0);
  }

  /// Valida consistencia básica entre los datos extraídos.
  /// Un CURP empieza siempre con la inicial del apellido paterno.
  bool validateConsistency(IdentityData data) {
    final curp = data.idNumber?.toUpperCase();
    final lastInitial = data.lastName?.isNotEmpty == true
        ? data.lastName![0].toUpperCase()
        : null;
    if (curp == null || lastInitial == null) return false;
    return curp.startsWith(lastInitial);
  }
}