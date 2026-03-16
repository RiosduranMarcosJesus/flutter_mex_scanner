import '../../../core/doc_type.dart';
import '../domain/identity_data.dart';
import 'parsers/curp_parser.dart';
import 'parsers/generic_image_parser.dart';
import 'parsers/ine_parser.dart';

/// Factory que devuelve el [DocumentParserStrategy] correcto para cada [DocType].
///
/// Depende de [DocType] (abstracción), no de los parsers concretos desde fuera.
/// Para agregar un nuevo tipo: 1) añade entrada en [DocType], 2) crea el parser,
/// 3) agrega el case aquí. El resto del código no se toca.
class DocParserFactory {
  const DocParserFactory();

  DocumentParserStrategy getParser(DocType type) {
    return switch (type) {
      DocType.ine   => const IneParser(),
      DocType.curp  => const CurpParser(),
    };
  }
}