import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pantalla con overlay guía para encuadrar la INE antes de tomar la foto.
class CameraCropPage extends StatelessWidget {
  const CameraCropPage({super.key});

  /// Usa [navigatorKey] global para evitar el problema de contexto desactivado
  /// que ocurre cuando la biometría consume tiempo antes de abrir la cámara.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Abre el overlay usando el navigator global — siempre válido.
  static Future<File?> capture() {
    final nav = navigatorKey.currentState;
    if (nav == null) return Future.value(null);
    return nav.push<File?>(
      MaterialPageRoute(builder: (_) => const CameraCropPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Coloca tu INE dentro del recuadro',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: CustomPaint(
                  painter: _IneOverlayPainter(),
                  child: const SizedBox(width: 320, height: 202),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  ),
                  GestureDetector(
                    onTap: () => _takePicture(context),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePicture(BuildContext context) async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (context.mounted) {
      Navigator.of(context).pop(xFile != null ? File(xFile.path) : null);
    }
  }
}

class _IneOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final corner = Paint()
      ..color = Colors.indigo.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const c = 24.0;
    final w = size.width, h = size.height;
    // esquinas
    canvas.drawLine(const Offset(0, c), Offset.zero, corner);
    canvas.drawLine(const Offset(c, 0), Offset.zero, corner);
    canvas.drawLine(Offset(w - c, 0), Offset(w, 0), corner);
    canvas.drawLine(Offset(w, 0), Offset(w, c), corner);
    canvas.drawLine(Offset(0, h - c), Offset(0, h), corner);
    canvas.drawLine(Offset(0, h), Offset(c, h), corner);
    canvas.drawLine(Offset(w - c, h), Offset(w, h), corner);
    canvas.drawLine(Offset(w, h - c), Offset(w, h), corner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}