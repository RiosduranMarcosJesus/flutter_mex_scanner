/// Tipos de documento de identidad que la app puede procesar.
///
/// Cada valor representa QUÉ documento es, no cómo está almacenado.
/// El formato del archivo (imagen JPG vs PDF) es un detalle que resuelve
/// el controller internamente — aquí solo importa el tipo de documento.
///
/// Flujo de selección para el usuario:
///   - INE   → abre cámara (foto directa) O galería (foto ya tomada)
///   - CURP  → galería o archivos (puede ser imagen o PDF del SAT/RENAPO)
///   - Futuros: pasaporte, título SAT, cartilla militar, etc.
///
/// El enum [_FileFormat] (privado al controller) maneja si el archivo
/// resultante es imagen o PDF — eso no le incumbe a este tipo.
enum DocType {
  ine,
  curp,
  // Próximos a implementar — solo agregar aquí y crear el parser:
  // pasaporte,
  // tituloSat,
  // cartillaMilitar,
}