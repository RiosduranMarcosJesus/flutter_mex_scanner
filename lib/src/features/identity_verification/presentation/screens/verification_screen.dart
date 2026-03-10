// Archivo: lib/src/features/identity_verification/presentation/screens/verification_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mi_app_verificadora/src/common/services/biometric_service.dart';
import 'package:mi_app_verificadora/src/common/services/ocr_service.dart';
import 'package:mi_app_verificadora/src/common/utils/text_processor.dart';
import 'package:mi_app_verificadora/src/features/identity_verification/data/identity_model.dart';

// TipoDocumento, todos los widgets visuales y la paleta (kBgCard, kAccentINE…)
// viven en verification_widgets.dart para evitar dependencias circulares.
import 'package:mi_app_verificadora/src/features/identity_verification/presentation/widgets/verification_widgets.dart';

/// Pantalla principal de verificación de identidad.
///
/// Orquesta el flujo completo:
/// 1. El usuario elige tipo de documento (INE / CURP) con [DocumentTypeSelector].
/// 2. Pulsa "Escanear" → autenticación biométrica / PIN via [BiometricService].
/// 3. Elige origen de imagen (cámara / galería) en [SourcePickerDialog].
/// 4. [OcrService] extrae el texto y [TextProcessor] obtiene nombre y CURP.
/// 5. Los resultados aparecen en [ResultsCard] con animación de entrada.
///
/// Los widgets visuales están en
/// `presentation/widgets/verification_widgets.dart`.
class VerificationScreen extends StatefulWidget {
  /// Crea una instancia de [VerificationScreen].
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────────────────────

  /// Gestiona la autenticación biométrica / PIN antes de cada escaneo.
  final _biometricService = BiometricService();

  /// Ejecuta el OCR sobre la imagen del documento.
  final _ocrService = OcrService();

  /// Selector de imágenes desde cámara o galería.
  final _picker = ImagePicker();

  // ── State ──────────────────────────────────────────────────────────────────

  /// Tipo de documento activo seleccionado por el usuario.
  TipoDocumento _selectedType = TipoDocumento.curp;

  /// Imagen del documento capturada o seleccionada.
  File? _documentImage;

  /// Datos de identidad extraídos tras el OCR.
  IdentityData _extractedData = IdentityData.vacio();

  /// `true` mientras el OCR está procesando la imagen.
  bool _isLoading = false;

  /// Controlador para la animación de entrada de [ResultsCard].
  late final AnimationController _animController;

  /// Animación de deslizamiento hacia arriba de [ResultsCard].
  late final Animation<Offset> _slideAnimation;

  /// Animación de opacidad de [ResultsCard].
  late final Animation<double> _fadeAnimation;

  // ── Color palette (locales) ────────────────────────────────────────────────

  static const _bgDark        = Color(0xFF0D1117);
  static const _accentWarning = Color(0xFFE3B341);
  static const _textSecondary = Color(0xFF8B949E);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Color de acento según el tipo de documento activo.
  Color get _accentColor =>
      _selectedType == TipoDocumento.ine ? kAccentINE : kAccentCURP;

  /// Etiqueta corta del tipo de documento activo ("INE" o "CURP").
  String get _typeLabel =>
      _selectedType == TipoDocumento.ine ? 'INE' : 'CURP';

  // ── Core scan flow ─────────────────────────────────────────────────────────

  /// Flujo principal: biometría → origen → imagen → OCR → resultados.
  ///
  /// Cada paso puede cancelar el flujo silenciosamente (retorno sin cambios).
  /// Los errores de OCR se muestran al usuario mediante [_showErrorSnackbar].
  Future<void> _startScanFlow() async {
    // Paso 1 — Autenticación biométrica / PIN.
    final bool authorized = await _requestBiometricAuth();
    if (!authorized) return;

    // Paso 2 — Selección de origen de imagen.
    if (!mounted) return;
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => SourcePickerDialog(accentColor: _accentColor),
    );
    if (source == null) return;

    // Paso 3 — Captura / selección de imagen.
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo == null) return;

    setState(() {
      _documentImage = File(photo.path);
      _isLoading = true;
      _extractedData = IdentityData.vacio();
      _animController.reset();
    });

    // Paso 4 — OCR + extracción de datos.
    try {
      final String rawText = await _ocrService.extraerTextoPlano(photo.path);
      final String curp    = TextProcessor.extraerCurp(rawText);
      final String name    = TextProcessor.extraerNombre(rawText);

      setState(() {
        _extractedData = IdentityData(nombre: name, curp: curp);
      });

      // Paso 5 — Animación de entrada de la tarjeta de resultados.
      _animController.forward();
    } on OcrException catch (e) {
      // Error conocido de OCR — mensaje amigable al usuario.
      if (mounted) _showErrorSnackbar(e.message);
    } catch (e) {
      // Error inesperado — mensaje genérico.
      if (mounted) {
        _showErrorSnackbar(
            'Ocurrió un error inesperado. Por favor intenta de nuevo.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Solicita autenticación biométrica o PIN al usuario.
  ///
  /// Retorna `true` si la autenticación fue exitosa o si el dispositivo
  /// no tiene biometría disponible ([BiometricResult.notAvailable]).
  /// Retorna `false` y muestra un [SnackBar] en caso de fallo o error.
  Future<bool> _requestBiometricAuth() async {
    final BiometricResult result = await _biometricService.authenticate(
      reason: 'Confirma tu identidad para escanear el $_typeLabel',
    );

    switch (result) {
      case BiometricResult.authenticated:
        return true;
      case BiometricResult.notAvailable:
        // Sin biometría en el dispositivo — continuamos sin bloquear.
        return true;
      case BiometricResult.failed:
        if (mounted) {
          _showErrorSnackbar(
              'Autenticación fallida. Intenta de nuevo o usa tu PIN.');
        }
        return false;
      case BiometricResult.error:
        if (mounted) {
          _showErrorSnackbar(
              'No se pudo verificar tu identidad. Intenta de nuevo.');
        }
        return false;
    }
  }

  /// Muestra un [SnackBar] flotante con ícono de advertencia y [message].
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kBgCard,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: _accentWarning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style:
                      const TextStyle(color: kTextPrimary, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  /// Construye la interfaz completa de la pantalla de verificación.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: _accentColor, size: 22),
            const SizedBox(width: 10),
            const Text('Verificación',
                style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona el tipo de documento\ny captura la imagen para extraer los datos.',
              style: TextStyle(
                  color: _textSecondary, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),

            // Toggle INE / CURP
            DocumentTypeSelector(
              selectedType: _selectedType,
              onTypeChanged: (t) => setState(() => _selectedType = t),
            ),
            const SizedBox(height: 24),

            // Previsualización de imagen
            DocumentImagePreview(image: _documentImage),
            if (_documentImage != null) const SizedBox(height: 20),

            // Indicador de carga durante el OCR
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _accentColor),
                    ),
                    const SizedBox(height: 12),
                    const Text('Procesando documento...',
                        style: TextStyle(
                            color: _textSecondary, fontSize: 13)),
                  ],
                ),
              ),

            // Tarjeta de resultados animada
            if (_documentImage != null && !_isLoading)
              ResultsCard(
                data: _extractedData,
                accentColor: _accentColor,
                typeLabel: _typeLabel,
                slideAnimation: _slideAnimation,
                fadeAnimation: _fadeAnimation,
              ),
          ],
        ),
      ),

      // FAB — etiqueta dinámica según tipo de documento
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startScanFlow,
        backgroundColor: _accentColor,
        foregroundColor: _bgDark,
        elevation: 6,
        label: Text(
          'Escanear $_typeLabel',
          style: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        icon: const Icon(Icons.document_scanner_outlined),
      ),
    );
  }
}