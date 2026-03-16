import 'dart:io';

import '../../../common/biometric/biometric_service.dart';
import '../../../common/media/media_service.dart';
import '../../../common/ocr/ocr_service.dart';
import '../../../core/doc_type.dart';
import '../data/doc_parser_factory.dart';
import 'identity_data.dart';

/// Resultado sellado del flujo de verificación.
sealed class IdentityResult {
  const IdentityResult();
}

class IdentitySuccess extends IdentityResult {
  const IdentitySuccess(this.data);
  final IdentityData data;
}

class IdentityFailure extends IdentityResult {
  const IdentityFailure(this.message);
  final String message;
}

/// Formato real del archivo capturado.
/// Es un detalle interno del controller — la UI y el dominio no lo conocen.
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

  // ── Paso 1: Biometría ───────────────────────────────────────────
  Future<bool> authenticate() => _bio.authenticate();

  // ── Pasos 2-4: Captura → OCR → Parseo ──────────────────────────
  Future<IdentityResult> processIdentity(
    DocType type, {
    bool useCamera = false, // true = cámara, false = galería/archivos
  }) async {
    // 2. Captura del archivo
    final File? file = await _captureFile(type, useCamera: useCamera);
    if (file == null) {
      return const IdentityFailure('No se seleccionó ningún archivo.');
    }

    // Detectamos el formato real del archivo
    final format = _detectFormat(file);
    if (format == _FileFormat.unknown) {
      _deleteFileSafely(file);
      return const IdentityFailure(
        'Formato de archivo no soportado. '
        'Usa una imagen (JPG/PNG) o un PDF.',
      );
    }

    // 3. OCR
    final String ocrText;
    try {
      final strategy = _factory.getParser(type);
      final ocr = format == _FileFormat.pdf ? _ocrPdf : _ocrImage;
      ocrText = await ocr.extractPlainText(
        filePath: file.path,
        parserStrategy: strategy,
      );
    } catch (e) {
      _deleteFileSafely(file);
      return IdentityFailure('Error al leer el documento: $e');
    }

    // 4. Parseo
    final IdentityData data;
    try {
      final strategy = _factory.getParser(type);
      data = await strategy.process(
        ocrText: ocrText,
        filePath: file.path,
      );
    } catch (e) {
      _deleteFileSafely(file);
      return IdentityFailure('Error al interpretar el documento: $e');
    }

    // Archivo temporal ya no se necesita
    _deleteFileSafely(file);
    return IdentitySuccess(data);
  }

  // ── Paso 5: Validación ──────────────────────────────────────────
  IdentityResult validate(
    IdentityData extracted, {
    IdentityData? reference,
    bool skipCrossValidation = false,
  }) {
    if (!extracted.isComplete) {
      return const IdentityFailure(
        'No se pudieron leer todos los datos del documento. '
        'Intenta con una foto más nítida.',
      );
    }
    if (!skipCrossValidation && reference != null) {
      final mismatch = _crossValidate(extracted, reference);
      if (mismatch != null) return IdentityFailure(mismatch);
    }
    return IdentitySuccess(extracted);
  }

  // ── Helpers privados ─────────────────────────────────────────────

  Future<File?> _captureFile(DocType type, {required bool useCamera}) {
    return switch (type) {
      // INE: cámara si useCamera=true, galería si false
      DocType.ine  => useCamera
          ? _media.takePhoto()
          : _media.pickFile(allowPdf: false),
      // CURP: siempre galería/archivos, puede ser imagen o PDF
      DocType.curp => _media.pickFile(allowPdf: true),
    };
  }

  /// Detecta el formato real leyendo los primeros bytes del archivo (magic bytes).
  /// No confiamos en la extensión — el usuario puede renombrar archivos.
  _FileFormat _detectFormat(File file) {
    try {
      final bytes = file.readAsBytesSync();
      if (bytes.length < 4) return _FileFormat.unknown;

      // PDF: empieza con "%PDF" (0x25 0x50 0x44 0x46)
      if (bytes[0] == 0x25 && bytes[1] == 0x50 &&
          bytes[2] == 0x44 && bytes[3] == 0x46) {
        return _FileFormat.pdf;
      }

      // JPEG: empieza con 0xFF 0xD8
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return _FileFormat.image;
      }

      // PNG: empieza con 0x89 0x50 0x4E 0x47
      if (bytes[0] == 0x89 && bytes[1] == 0x50 &&
          bytes[2] == 0x4E && bytes[3] == 0x47) {
        return _FileFormat.image;
      }

      return _FileFormat.unknown;
    } catch (_) {
      return _FileFormat.unknown;
    }
  }

  String? _crossValidate(IdentityData a, IdentityData b) {
    if (a.idNumber != null && b.idNumber != null) {
      if (a.idNumber!.toUpperCase() != b.idNumber!.toUpperCase()) {
        return 'El número de identificación no coincide entre documentos.';
      }
    }
    if (a.lastName != null && b.lastName != null) {
      if (!_nameMatch(a.lastName!, b.lastName!)) {
        return 'El apellido paterno no coincide entre documentos.';
      }
    }
    if (a.birthDate != null && b.birthDate != null) {
      if (!_birthDateMatch(a.birthDate!, b.birthDate!)) {
        return 'La fecha de nacimiento no coincide entre documentos.';
      }
    }
    if (a.sex != null && b.sex != null && a.sex != b.sex) {
      return 'El sexo registrado no coincide entre documentos.';
    }
    return null;
  }

  bool _nameMatch(String a, String b) => _normalize(a) == _normalize(b);

  String _normalize(String s) => s
      .toUpperCase().trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('Á', 'A').replaceAll('É', 'E')
      .replaceAll('Í', 'I').replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U').replaceAll('Ü', 'U');

  bool _birthDateMatch(String a, String b) {
    final mmddA = _extractMmDd(a);
    final mmddB = _extractMmDd(b);
    if (mmddA == null || mmddB == null) return true;
    return mmddA == mmddB;
  }

  String? _extractMmDd(String date) {
    final parts = date.split(RegExp(r'[\/\-]'));
    if (parts.length < 2) return null;
    return '${parts[1]}${parts[0]}';
  }

  void _deleteFileSafely(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}