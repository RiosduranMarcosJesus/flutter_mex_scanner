// Archivo: lib/src/features/identity_verification/presentation/widgets/verification_widgets.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mi_app_verificadora/src/features/identity_verification/data/identity_model.dart';

// ── Enum ─────────────────────────────────────────────────────────────────────

/// Tipos de documento soportados por el escáner.
///
/// Definido aquí para que tanto [VerificationScreen] como los widgets
/// puedan importarlo desde un único lugar.
enum TipoDocumento { ine, curp }

// ── Paleta compartida ─────────────────────────────────────────────────────────

/// Color de fondo para tarjetas y diálogos.
const kBgCard        = Color(0xFF161B22);

/// Acento verde esmeralda usado para documentos INE.
const kAccentINE     = Color(0xFF00C896);

/// Acento azul eléctrico usado para documentos CURP.
const kAccentCURP    = Color(0xFF4F8EF7);

/// Color principal de texto sobre fondos oscuros.
const kTextPrimary   = Color(0xFFF0F6FC);

/// Color secundario de texto para etiquetas y placeholders.
const kTextSecondary = Color(0xFF8B949E);

/// Color de líneas divisoras entre secciones.
const kDividerColor  = Color(0xFF21262D);

// ── SourcePickerDialog ────────────────────────────────────────────────────────

/// Diálogo estilizado para que el usuario elija entre cámara y galería.
///
/// Retorna el [ImageSource] seleccionado al hacer `Navigator.pop`.
/// Si el usuario toca fuera del diálogo retorna `null`.
///
/// Uso:
/// ```dart
/// final source = await showDialog<ImageSource>(
///   context: context,
///   builder: (_) => SourcePickerDialog(accentColor: _accentColor),
/// );
/// ```
class SourcePickerDialog extends StatelessWidget {
  /// Color de acento del tipo de documento activo.
  final Color accentColor;

  /// Crea un [SourcePickerDialog] con el [accentColor] dado.
  const SourcePickerDialog({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kBgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Cómo cargar el documento?',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SourceOption(
                  icon: Icons.document_scanner_outlined,
                  label: 'Cámara',
                  source: ImageSource.camera,
                  accentColor: accentColor,
                ),
                _SourceOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Galería',
                  source: ImageSource.gallery,
                  accentColor: accentColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opción individual dentro de [SourcePickerDialog].
class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final ImageSource source;
  final Color accentColor;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.source,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: accentColor, size: 36),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── DocumentTypeSelector ──────────────────────────────────────────────────────

/// Toggle animado para seleccionar el tipo de documento (INE / CURP).
///
/// Recibe el [selectedType] actual y notifica cambios mediante [onTypeChanged].
///
/// Uso:
/// ```dart
/// DocumentTypeSelector(
///   selectedType: _selectedType,
///   onTypeChanged: (t) => setState(() => _selectedType = t),
/// )
/// ```
class DocumentTypeSelector extends StatelessWidget {
  /// Tipo de documento actualmente seleccionado.
  final TipoDocumento selectedType;

  /// Callback invocado cuando el usuario selecciona un tipo distinto.
  final ValueChanged<TipoDocumento> onTypeChanged;

  /// Crea un [DocumentTypeSelector].
  const DocumentTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDividerColor),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: TipoDocumento.values.map((type) {
          final isSelected = selectedType == type;
          final label = type == TipoDocumento.ine ? 'INE' : 'CURP';
          final icon  = type == TipoDocumento.ine
              ? Icons.credit_card_outlined
              : Icons.badge_outlined;
          final color =
              type == TipoDocumento.ine ? kAccentINE : kAccentCURP;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTypeChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: color.withOpacity(0.5))
                      : Border.all(color: Colors.transparent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 18,
                        color: isSelected ? color : kTextSecondary),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? color : kTextSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── DocumentImagePreview ──────────────────────────────────────────────────────

/// Previsualización animada de la imagen del documento capturado.
///
/// Anima la altura de 0 a 200 px cuando [image] pasa de `null` a un archivo.
class DocumentImagePreview extends StatelessWidget {
  /// Imagen a mostrar. Si es `null` el widget colapsa a altura cero.
  final File? image;

  /// Crea un [DocumentImagePreview].
  const DocumentImagePreview({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: image != null ? 300 : 0,
      child: image != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(image!,
                  fit: BoxFit.cover, width: double.infinity),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ── ResultsCard ───────────────────────────────────────────────────────────────

/// Tarjeta animada (slide desde abajo + fade) con los datos extraídos por OCR.
///
/// Recibe las animaciones [slideAnimation] y [fadeAnimation] del controlador
/// del padre para coordinar la entrada. Los datos provienen de [data].
///
/// Los campos futuros están comentados: descoméntalos al ampliar [IdentityData].
class ResultsCard extends StatelessWidget {
  /// Datos de identidad extraídos para mostrar.
  final IdentityData data;

  /// Color de acento del tipo de documento activo.
  final Color accentColor;

  /// Etiqueta corta del tipo de documento ("INE" o "CURP").
  final String typeLabel;

  /// Animación de posición (slide desde abajo).
  final Animation<Offset> slideAnimation;

  /// Animación de opacidad (fade in).
  final Animation<double> fadeAnimation;

  /// Crea un [ResultsCard].
  const ResultsCard({
    super.key,
    required this.data,
    required this.accentColor,
    required this.typeLabel,
    required this.slideAnimation,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kBgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: badge de tipo + título + check
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Datos extraídos',
                      style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.check_circle_outline,
                      color: accentColor, size: 20),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: kDividerColor, height: 1),
              ),

              // ── Campos de datos ──────────────────────────────────────────
              _DataRow(
                icon: Icons.person_outline,
                label: 'NOMBRE COMPLETO',
                value: data.nombre,
                accentColor: accentColor,
              ),
              Divider(color: kDividerColor, height: 1),
              _DataRow(
                icon: Icons.fingerprint,
                label: 'CURP',
                value: data.curp,
                accentColor: accentColor,
              ),

              // Campos futuros — descomenta al ampliar IdentityData:
              // Divider(color: kDividerColor, height: 1),
              // _DataRow(icon: Icons.cake_outlined,        label: 'FECHA DE NACIMIENTO', value: data.fechaNacimiento, accentColor: accentColor),
              // Divider(color: kDividerColor, height: 1),
              // _DataRow(icon: Icons.location_on_outlined, label: 'DOMICILIO',            value: data.domicilio,        accentColor: accentColor),
              // Divider(color: kDividerColor, height: 1),
              // _DataRow(icon: Icons.tag_outlined,         label: 'CLAVE DE ELECTOR',    value: data.claveElector,     accentColor: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila individual de dato dentro de [ResultsCard].
class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == 'No detectado' || value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: isEmpty ? kTextSecondary : kTextPrimary,
                    fontSize: 15,
                    fontWeight:
                        isEmpty ? FontWeight.w400 : FontWeight.w600,
                    fontStyle:
                        isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}