// Archivo: lib/main.dart
import 'package:flutter/material.dart';
import 'package:mi_app_verificadora/src/features/identity_verification/presentation/screens/verification_screen.dart';

void main() {
  runApp(const MiAppVerificadora());
}

class MiAppVerificadora extends StatelessWidget {
  const MiAppVerificadora({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verificador de Identidad',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const VerificationScreen(),
    );
  }
}