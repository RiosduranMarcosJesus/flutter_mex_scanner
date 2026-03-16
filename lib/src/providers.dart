import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/biometric/android_biometric_service.dart';
import 'common/biometric/biometric_service.dart';
import 'common/biometric/ios_biometric_service.dart';
import 'common/media/android_media_service.dart';
import 'common/media/ios_media_service.dart';
import 'common/media/media_service.dart';
import 'common/ocr/image_ocr_service.dart';
import 'common/ocr/ocr_service.dart';
import 'common/ocr/pdf_ocr_service.dart';
import 'package:mi_app_verificadora/src/common/text_processor/text_procesor.dart';
import 'features/identity/data/doc_parser_factory.dart';
import 'features/identity/domain/identity_controller.dart';

// ── Biométrico ────────────────────────────────────────────────────────────────
/// El `if` de plataforma vive aquí — un solo lugar, no se reparte por el código.
/// Quien consuma [biometricServiceProvider] solo conoce [BiometricService].
final biometricServiceProvider = Provider<BiometricService>((ref) {
  if (Platform.isAndroid) return AndroidBiometricService();
  if (Platform.isIOS) return IosBiometricService();
  throw UnsupportedError('Plataforma no soportada para biometría');
});

// ── Media ─────────────────────────────────────────────────────────────────────
final mediaServiceProvider = Provider<MediaService>((ref) {
  if (Platform.isAndroid) return AndroidMediaService();
  if (Platform.isIOS) return IosMediaService();
  throw UnsupportedError('Plataforma no soportada para media');
});

// ── OCR ───────────────────────────────────────────────────────────────────────
final imageOcrProvider = Provider<OcrService>((_) => ImageOcrService());
final pdfOcrProvider = Provider<OcrService>((_) => PdfOcrService());

// ── Utilidades ────────────────────────────────────────────────────────────────
final textProcessorProvider = Provider<TextProcessor>((_) => const TextProcessor());
final docParserFactoryProvider = Provider<DocParserFactory>((_) => const DocParserFactory());

// ── Feature: Identity ─────────────────────────────────────────────────────────
/// [IdentityController] es una clase pura — Riverpod le inyecta todo.
/// Usamos [Provider] simple porque el controller no tiene estado propio;
/// el estado del flujo lo manejarás con un [StateNotifierProvider] en la UI.
final identityControllerProvider = Provider<IdentityController>((ref) {
  return IdentityController(
    biometricService: ref.watch(biometricServiceProvider),
    mediaService: ref.watch(mediaServiceProvider),
    ocrImage: ref.watch(imageOcrProvider),
    ocrPdf: ref.watch(pdfOcrProvider),
    parserFactory: ref.watch(docParserFactoryProvider),
  );
});