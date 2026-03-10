// Archivo: lib/src/common/utils/text_processor.dart
import 'package:flutter/foundation.dart';

/// Utilidad estática para extraer y normalizar datos de identidad
/// a partir de texto crudo generado por OCR.
///
/// Actualmente soporta la extracción de:
/// - **CURP** (Clave Única de Registro de Población) según la estructura
///   oficial del RENAPO.
/// - **Nombre completo** a partir de la etiqueta "NOMBRE" en el documento.
///
/// Todos los métodos son estáticos; no es necesario instanciar la clase.
class TextProcessor {
  /// Expresión regular que valida la estructura oficial de una CURP mexicana.
  ///
  /// Formato esperado (18 caracteres):
  /// ```
  /// [LETRA][VOCAL][LETRA]{2} [AÑO][MES][DÍA] [H/M] [ESTADO] [CONSONANTES]{3} [HOMOCLAVE] [VERIFICADOR]
  /// ```
  /// - Posiciones 1–4   : Iniciales del nombre y apellidos (letra + vocal + 2 letras).
  /// - Posiciones 5–10  : Fecha de nacimiento en formato `AAMMDD`.
  /// - Posición  11     : Sexo registrado (`H` hombre / `M` mujer).
  /// - Posiciones 12–13 : Clave de la entidad federativa de registro.
  /// - Posiciones 14–16 : Consonantes internas de apellidos y nombre.
  /// - Posición  17     : Homoclave alfanumérica asignada por el RENAPO.
  /// - Posición  18     : Dígito verificador numérico.
  static final RegExp _curpEstructural = RegExp(
    r'[A-Z][AEIOU][A-Z]{2}\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])[HM]'
    r'(?:AS|BC|BS|CC|CS|CH|CL|CM|DF|DG|GT|GR|HG|JC|MC|MN|MS|NT|NL|OC|PL|QT|QR|SP|SL|SR|TC|TS|TL|VZ|YN|ZS|NE)'
    r'[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d',
    caseSensitive: false,
  );

  /// Extrae la CURP del texto crudo producido por el OCR.
  ///
  /// Aplica tres estrategias en orden de menor a mayor tolerancia:
  ///
  /// 1. **Búsqueda directa**: aplica el regex estructural sobre todo el texto
  ///    normalizado. Es la más rápida y precisa.
  /// 2. **Búsqueda por ancla**: localiza palabras clave (`CLAVE:`, `CURP:`, etc.)
  ///    y evalúa el fragmento siguiente ignorando saltos de línea.
  /// 3. **Ventana deslizante**: recorre cada línea del texto con una ventana
  ///    de 18 caracteres para detectar CURPs sin contexto previo.
  ///
  /// Antes de aplicar cualquier estrategia, el texto pasa por [_preCorregirTexto]
  /// para subsanar confusiones comunes del OCR (p. ej. `O`→`0`, `I`→`1`).
  ///
  /// Retorna la CURP en mayúsculas si es encontrada, o `"No detectado"` en
  /// caso contrario.
  ///
  /// Ejemplo:
  /// ```dart
  /// final curp = TextProcessor.extraerCurp(textoOcr);
  /// print(curp); // "RIDM050419HPLSRRA7"
  /// ```
  static String extraerCurp(String textoOcr) {
    // Normalizamos a mayúsculas y corregimos errores OCR antes de buscar.
    String textoUpper = _preCorregirTexto(textoOcr.toUpperCase());
    debugPrint("--- Texto normalizado para búsqueda CURP ---");
    debugPrint(textoUpper);

    // ESTRATEGIA 1: Búsqueda directa del patrón en todo el texto.
    final match = _curpEstructural.firstMatch(textoUpper);
    if (match != null) {
      String curp = match.group(0)!.toUpperCase();
      debugPrint("✅ CURP encontrado directo: $curp");
      return curp;
    }

    // ESTRATEGIA 2: Búsqueda por palabras ancla del documento.
    // Eliminamos saltos de línea para no perder la CURP cuando está en la
    // línea inmediatamente siguiente a la etiqueta.
    String textoSinSaltos = textoUpper.replaceAll(RegExp(r'[\n\r]+'), ' ');

    List<String> anclas = ["CLAVE:", "CLAVE", "CURP:", "CURP"];
    for (String ancla in anclas) {
      int pos = textoSinSaltos.indexOf(ancla);
      if (pos == -1) continue;

      // Tomamos los 100 caracteres siguientes al ancla para tener margen.
      int inicio = pos + ancla.length;
      String fragmento = textoSinSaltos.substring(
        inicio,
        (inicio + 100).clamp(0, textoSinSaltos.length),
      );

      // Conservamos solo caracteres alfanuméricos para evitar ruido.
      String candidato = fragmento.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      debugPrint("Candidato tras '$ancla': $candidato");

      // Ventana deslizante de 18 chars sobre el candidato limpio.
      for (int i = 0; i <= candidato.length - 18; i++) {
        String ventana = candidato.substring(i, i + 18);
        if (_curpEstructural.hasMatch(ventana)) {
          debugPrint("✅ CURP encontrado por ancla '$ancla': $ventana");
          return ventana;
        }
      }
    }

    // ESTRATEGIA 3: Ventana deslizante línea por línea.
    // Útil cuando el OCR fragmenta o reordena el texto del documento.
    List<String> lineas = textoUpper.split(RegExp(r'[\n\r]+'));
    for (String linea in lineas) {
      String limpia = linea.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (limpia.length >= 18) {
        for (int i = 0; i <= limpia.length - 18; i++) {
          String ventana = limpia.substring(i, i + 18);
          if (_curpEstructural.hasMatch(ventana)) {
            debugPrint("✅ CURP encontrado por ventana: $ventana");
            return ventana;
          }
        }
      }
    }

    debugPrint("❌ CURP no detectado");
    return "No detectado";
  }

  /// Aplica correcciones previas al texto para compensar errores comunes del OCR.
  ///
  /// **Corrección 1 — Segmento de fecha:**
  /// Dentro de la estructura `[4 letras][6 caracteres]`, sustituye caracteres
  /// que el OCR confunde frecuentemente con dígitos:
  /// - `O` / `Q` → `0`
  /// - `I` / `L` → `1`
  ///
  /// **Corrección 2 — Dígito verificador:**
  /// El OCR suele leer el `7` final de la CURP como `Z`. Este método detecta
  /// secuencias de 17 caracteres válidos seguidas de `Z` y las corrige a `7`.
  ///
  /// Recibe el [texto] ya en mayúsculas y devuelve la versión corregida.
  static String _preCorregirTexto(String texto) {
    // Corrección 1: normalizar el bloque de fecha (posiciones 5–10 de la CURP).
    texto = texto.replaceAllMapped(
      RegExp(r'([A-Z][AEIOU][A-Z]{2})([A-Z0-9]{6})'),
      (m) {
        String fecha = m.group(2)!
            .replaceAll('O', '0')
            .replaceAll('Q', '0')
            .replaceAll('I', '1')
            .replaceAll('L', '1');
        return m.group(1)! + fecha;
      },
    );

    // Corrección 2: reemplazar Z final incorrecto por el dígito verificador 7.
    texto = texto.replaceAllMapped(
      RegExp(
        r'([A-Z][AEIOU][A-Z]{2}\d{6}[HM]'
        r'(?:AS|BC|BS|CC|CS|CH|CL|CM|DF|DG|GT|GR|HG|JC|MC|MN|MS|NT|NL|OC|PL|QT|QR|SP|SL|SR|TC|TS|TL|VZ|YN|ZS|NE)'
        r'[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9])Z',
        caseSensitive: false,
      ),
      (m) {
        debugPrint("🔧 Corrigiendo Z->7 al final de CURP: ${m.group(0)}");
        return m.group(1)! + '7';
      },
    );

    return texto;
  }

  /// Extrae el nombre completo del titular a partir del texto OCR.
  ///
  /// Busca la etiqueta `"NOMBRE"` (sin distinción de mayúsculas) y toma
  /// el contenido de la línea inmediatamente siguiente como nombre candidato.
  ///
  /// El resultado se formatea con [_formatearComoNombrePropio] para obtener
  /// la capitalización correcta (p. ej. `"MARCOS JESUS"` → `"Marcos Jesus"`).
  ///
  /// Retorna el nombre formateado si se encuentra, o `"No detectado"` si no
  /// existe la etiqueta o la línea siguiente está vacía.
  ///
  /// Ejemplo:
  /// ```dart
  /// final nombre = TextProcessor.extraerNombre(textoOcr);
  /// print(nombre); // "Marcos Jesus Rios Duran"
  /// ```
  static String extraerNombre(String textoOcr) {
    List<String> lineas = textoOcr.split('\n');
    for (int i = 0; i < lineas.length; i++) {
      if (lineas[i].toUpperCase().contains("NOMBRE") && i + 1 < lineas.length) {
        String posibleNombre = lineas[i + 1].trim();
        if (posibleNombre.isNotEmpty && posibleNombre.length > 3) {
          return _formatearComoNombrePropio(posibleNombre);
        }
      }
    }
    return "No detectado";
  }

  /// Convierte una cadena de texto a formato de nombre propio.
  ///
  /// Cada palabra recibe su primera letra en mayúscula y el resto en
  /// minúsculas, separadas por un único espacio.
  ///
  /// Retorna el [texto] original sin cambios si está vacío.
  ///
  /// Ejemplo:
  /// ```dart
  /// _formatearComoNombrePropio("MARCOS JESUS RIOS DURAN");
  /// // Retorna: "Marcos Jesus Rios Duran"
  /// ```
  static String _formatearComoNombrePropio(String texto) {
    if (texto.isEmpty) return texto;
    return texto
        .split(' ')
        .map((p) => p.isNotEmpty
            ? p[0].toUpperCase() + p.substring(1).toLowerCase()
            : "")
        .join(' ');
  }
}