import 'dart:io';

/// Contrato para obtener archivos del dispositivo.
/// Ya no recibe BuildContext — la cámara usa CameraCropPage.navigatorKey
/// que siempre es válido independientemente del estado del árbol de widgets.
abstract class MediaService {
  Future<File?> takePhoto();
  Future<File?> pickFile({bool allowPdf = false});
}