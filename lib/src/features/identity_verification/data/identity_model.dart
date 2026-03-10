// Archivo: src/features/identity_verification/data/identity_model.dart

class IdentityData {
  final String nombre;
  final String curp;
  // Podrías agregar fechaEmision aquí más adelante si quieres aplicar la regla de los 3 meses.

  IdentityData({
    required this.nombre,
    required this.curp,
  });

  // Un constructor útil para cuando no encontramos nada
  IdentityData.vacio() : nombre = "No detectado", curp = "No detectado";
}