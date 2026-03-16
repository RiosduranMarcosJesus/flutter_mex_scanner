/// Sexo tal como lo codifica RENAPO en la CURP y aparece en documentos oficiales.
/// 'H' = Hombre / male, 'M' = Mujer / female.
/// Lo definimos como enum propio (no de ninguna librería) porque es un dato
/// de dominio puro de este proyecto.
enum Sex { male, female }

/// Datos extraídos de un documento de identidad.
/// Clase de dominio pura — sin dependencias de Flutter ni de librerías.
/// Inmutable; usa [copyWith] para construir versiones modificadas.
///
/// Los campos son todos opcionales porque no todos los documentos
/// contienen todos los datos:
///   - CURP: tiene idNumber, birthDate, sex, state — NO trae address.
///   - INE : tiene todo incluyendo address y domicilio completo.
///   - Futuros documentos (pasaporte, título SAT): llenarán lo que puedan.
class IdentityData {
  const IdentityData({
    this.firstName,
    this.secondFirstName,
    this.lastName,
    this.secondLastName,
    this.birthDate,
    this.idNumber,
    this.sex,
    this.state,
    this.address,
  });

  final String? firstName;
  final String? secondFirstName; // segundo nombre, si tiene
  final String? lastName;        // apellido paterno
  final String? secondLastName;  // apellido materno
  final String? birthDate;       // formato dd/MM/yyyy
  final String? idNumber;        // CURP, clave de elector, etc.
  final Sex? sex;                // H = male, M = female (codificado en CURP pos 10)
  final String? state;           // entidad federativa (CURP pos 11-12)
  final String? address;         // solo documentos como INE traen domicilio

  IdentityData copyWith({
    String? firstName,
    String? secondFirstName,
    String? lastName,
    String? secondLastName,
    String? birthDate,
    String? idNumber,
    Sex? sex,
    String? state,
    String? address,
  }) =>
      IdentityData(
        firstName: firstName ?? this.firstName,
        secondFirstName: secondFirstName ?? this.secondFirstName,
        lastName: lastName ?? this.lastName,
        secondLastName: secondLastName ?? this.secondLastName,
        birthDate: birthDate ?? this.birthDate,
        idNumber: idNumber ?? this.idNumber,
        sex: sex ?? this.sex,
        state: state ?? this.state,
        address: address ?? this.address,
      );

  /// Mínimo requerido para considerar una extracción útil.
  /// No exigimos address ni secondFirstName porque son opcionales por naturaleza.
  bool get isComplete =>
      firstName != null &&
      lastName != null &&
      idNumber != null &&
      birthDate != null;

  @override
  String toString() => 'IdentityData('
      'firstName: $firstName, '
      'secondFirstName: $secondFirstName, '
      'lastName: $lastName, '
      'secondLastName: $secondLastName, '
      'birthDate: $birthDate, '
      'idNumber: $idNumber, '
      'sex: $sex, '
      'state: $state, '
      'address: $address)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Strategy Pattern — cada tipo de documento tiene su propio parser.
// ─────────────────────────────────────────────────────────────────────────────

/// Contrato que deben cumplir todos los parsers de documentos.
abstract class DocumentParserStrategy {
  Future<IdentityData> process({
    required String ocrText,
    required String filePath,
  });
}