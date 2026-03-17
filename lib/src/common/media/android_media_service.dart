import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'media_service.dart';

class AndroidMediaService implements MediaService {
  final _picker = ImagePicker();

  @override
  Future<File?> takePhoto() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
      // maxWidth y maxHeight ayudan a que el sistema ofrezca recorte
      // después de tomar la foto en algunos dispositivos Android.
      // El usuario puede ajustar el encuadre antes de confirmar.
      maxWidth: 1800,
      maxHeight: 1200,
    );
    return xFile == null ? null : File(xFile.path);
  }

  @override
  Future<File?> pickFile({bool allowPdf = false}) async {
    if (allowPdf) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      final path = result?.files.single.path;
      return path != null ? File(path) : null;
    }
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    return xFile == null ? null : File(xFile.path);
  }
}