import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_crop_page.dart';
import 'media_service.dart';

class AndroidMediaService implements MediaService {
  final _picker = ImagePicker();

  @override
  Future<File?> takePhoto() => CameraCropPage.capture(); // usa navigatorKey global

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
    final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    return xFile == null ? null : File(xFile.path);
  }
}