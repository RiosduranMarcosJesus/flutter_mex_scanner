import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'media_service.dart';

/// Implementación Android de [MediaService].
///
/// Los permisos de cámara ya están declarados en AndroidManifest.xml.
/// `image_picker` en Android usa Intent para cámara y MediaStore para galería,
/// no necesita permisos en runtime en Android 13+ para imágenes propias.
class AndroidMediaService implements MediaService {
  final _picker = ImagePicker();

  @override
  Future<File?> takePhoto() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    return xFile == null ? null : File(xFile.path);
  }

  @override
  Future<File?> pickFile({bool allowPdf = false}) async {
    if (allowPdf) {
      // image_picker no soporta PDF. Alternativa futura: file_picker.
      // Por ahora retornamos null y la UI muestra mensaje al usuario.
      // TODO: integrar file_picker para PDF en Android.
      return null;
    }
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    return xFile == null ? null : File(xFile.path);
  }
}