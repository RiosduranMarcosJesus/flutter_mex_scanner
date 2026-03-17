import 'dart:io';

import '../../../common/biometric/biometric_service.dart';
import '../../../common/media/media_service.dart';
import '../../../common/ocr/ocr_service.dart';
import '../../../core/doc_type.dart';
import '../data/doc_parser_factory.dart';
import 'identity_data.dart';

sealed class IdentityResult { const IdentityResult(); }

class IdentitySuccess extends IdentityResult {
  const IdentitySuccess(this.data);
  final IdentityData data;
}

class IdentityFailure extends IdentityResult {
  const IdentityFailure(this.message);
  final String message;
}

enum _FileFormat { image, pdf, unknown }

class IdentityController {
  const IdentityController({
    required BiometricService biometricService,
    required MediaService mediaService,
    required OcrService ocrImage,
    required OcrService ocrPdf,
    required DocParserFactory parserFactory,
  })  : _bio = biometricService,
        _media = mediaService,
        _ocrImage = ocrImage,
        _ocrPdf = ocrPdf,
        _factory = parserFactory;

  final BiometricService _bio;
  final MediaService _media;
  final OcrService _ocrImage;
  final OcrService _ocrPdf;
  final DocParserFactory _factory;

  Future<bool> authenticate() => _bio.authenticate();

  Future<IdentityResult> processIdentity(
    DocType type, {
    bool useCamera = false,
  }) async {
    final File? file = await _captureFile(type, useCamera: useCamera);
    if (file == null) return const IdentityFailure('No se seleccionó ningún archivo.');

    final format = _detectFormat(file);
    if (format == _FileFormat.unknown) {
      _deleteFileSafely(file);
      return const IdentityFailure('Formato no soportado. Usa imagen (JPG/PNG) o PDF.');
    }

    final String ocrText;
    try {
      final strategy = _factory.getParser(type);
      final ocr = format == _FileFormat.pdf ? _ocrPdf : _ocrImage;
      ocrText = await ocr.extractPlainText(filePath: file.path, parserStrategy: strategy);
    } catch (e) {
      _deleteFileSafely(file);
      return IdentityFailure('Error al leer el documento: $e');
    }

    final IdentityData data;
    try {
      final strategy = _factory.getParser(type);
      data = await strategy.process(ocrText: ocrText, filePath: file.path);
    } catch (e) {
      _deleteFileSafely(file);
      return IdentityFailure('Error al interpretar el documento: $e');
    }

    _deleteFileSafely(file);
    return IdentitySuccess(data);
  }

  IdentityResult validate(
    IdentityData extracted, {
    IdentityData? reference,
    bool skipCrossValidation = false,
  }) {
    if (!extracted.isComplete) {
      return const IdentityFailure(
        'No se pudieron leer todos los datos. Intenta con una foto más nítida.',
      );
    }
    if (!skipCrossValidation && reference != null) {
      final mismatch = _crossValidate(extracted, reference);
      if (mismatch != null) return IdentityFailure(mismatch);
    }
    return IdentitySuccess(extracted);
  }

  Future<File?> _captureFile(DocType type, {required bool useCamera}) {
    return switch (type) {
      DocType.ine  => useCamera ? _media.takePhoto() : _media.pickFile(allowPdf: false),
      DocType.curp => _media.pickFile(allowPdf: true),
    };
  }

  _FileFormat _detectFormat(File file) {
    try {
      final bytes = file.readAsBytesSync();
      if (bytes.length < 4) return _FileFormat.unknown;
      if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) return _FileFormat.pdf;
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return _FileFormat.image;
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return _FileFormat.image;
      return _FileFormat.unknown;
    } catch (_) { return _FileFormat.unknown; }
  }

  String? _crossValidate(IdentityData a, IdentityData b) {
    if (a.idNumber != null && b.idNumber != null &&
        a.idNumber!.toUpperCase() != b.idNumber!.toUpperCase())
      return 'El número de identificación no coincide.';
    if (a.lastName != null && b.lastName != null && !_nameMatch(a.lastName!, b.lastName!))
      return 'El apellido paterno no coincide.';
    if (a.birthDate != null && b.birthDate != null && !_birthDateMatch(a.birthDate!, b.birthDate!))
      return 'La fecha de nacimiento no coincide.';
    if (a.sex != null && b.sex != null && a.sex != b.sex)
      return 'El sexo registrado no coincide.';
    return null;
  }

  bool _nameMatch(String a, String b) => _norm(a) == _norm(b);
  String _norm(String s) => s.toUpperCase().trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('Á','A').replaceAll('É','E')
      .replaceAll('Í','I').replaceAll('Ó','O')
      .replaceAll('Ú','U').replaceAll('Ü','U');

  bool _birthDateMatch(String a, String b) {
    final ma = _mmdd(a), mb = _mmdd(b);
    if (ma == null || mb == null) return true;
    return ma == mb;
  }
  String? _mmdd(String d) {
    final p = d.split(RegExp(r'[\/\-]'));
    return p.length >= 2 ? '${p[1]}${p[0]}' : null;
  }
  void _deleteFileSafely(File f) {
    try { if (f.existsSync()) f.deleteSync(); } catch (_) {}
  }
}