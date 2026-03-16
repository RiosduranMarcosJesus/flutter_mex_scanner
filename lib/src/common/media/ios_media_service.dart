import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'media_service.dart';

/// Implementación iOS de [MediaService].
///
/// iOS requiere NSCameraUsageDescription y NSPhotoLibraryUsageDescription
/// en Info.plist. En iOS 14+ la galería puede mostrar acceso limitado
/// (PHPickerViewController) — image_picker lo maneja automáticamente.
class IosMediaService implements MediaService {
  final _picker = ImagePicker();

  @override
  Future<File?> takePhoto() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      // iOS presenta el selector frontal/trasero en la UI nativa,
      // no necesitamos forzar CameraDevice aquí.
    );
    return xFile == null ? null : File(xFile.path);
  }

  @override
  Future<File?> pickFile({bool allowPdf = false}) async {
    if (allowPdf) {
      // PHPickerViewController de iOS no expone PDFs por default.
      // TODO: integrar file_picker para documentos en iOS.
      return null;
    }
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    return xFile == null ? null : File(xFile.path);
  }
}