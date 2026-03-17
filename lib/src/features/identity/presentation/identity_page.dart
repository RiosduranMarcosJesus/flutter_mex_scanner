import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/doc_type.dart';
import '../domain/identity_data.dart';
import 'identity_notifier.dart';

class IdentityPage extends ConsumerWidget {
  const IdentityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(identityNotifierProvider);
    final notifier = ref.read(identityNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de Identidad'),
        centerTitle: true,
        actions: [
          if (state.status != IdentityStatus.idle)
            IconButton(icon: const Icon(Icons.refresh), onPressed: notifier.reset),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (state.status) {
            IdentityStatus.idle    => _IdleView(state: state, notifier: notifier),
            IdentityStatus.loading => const _LoadingView(),
            IdentityStatus.success => _SuccessView(state: state, onReset: notifier.reset),
            IdentityStatus.error   => _ErrorView(state: state, onRetry: notifier.reset),
          },
        ),
      ),
    );
  }
}

// ── Idle ──────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.state, required this.notifier});
  final IdentityState state;
  final IdentityNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final hasRef = state.referenceData != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Icon(
            hasRef ? Icons.find_in_page_outlined : Icons.verified_user_outlined,
            size: 72, color: Colors.indigo,
          ),
          const SizedBox(height: 16),
          Text(
            hasRef
                ? 'Referencia cargada.\nEscanea el segundo documento.'
                : 'Selecciona el documento a verificar',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (hasRef) ...[
            const SizedBox(height: 12),
            _ReferenceChip(data: state.referenceData!),
          ],
          const SizedBox(height: 28),

          // ── INE ──────────────────────────────────────────────
          _Label('INE / Credencial para Votar'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => notifier.verify(DocType.ine, useCamera: true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Tomar foto'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => notifier.verify(DocType.ine, useCamera: false),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined),
                    SizedBox(width: 8),
                    Text('Galería'),
                  ],
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Tip: encuadra solo la INE, buena luz y sin sombras.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.black45),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // ── CURP ─────────────────────────────────────────────
          _Label('CURP'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => notifier.verify(DocType.curp),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Seleccionar archivo (imagen o PDF)'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'El formato se detecta automáticamente.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.black45),
              textAlign: TextAlign.center,
            ),
          ),

          const Divider(height: 36),

          // ── Validación cruzada ────────────────────────────────
          Text('Validación cruzada (opcional)',
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'Escanea primero como referencia, luego el segundo documento.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => notifier.verify(DocType.curp, isReference: true),
                icon: const Icon(Icons.article_outlined, size: 18),
                label: const Text('CURP referencia'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => notifier.verify(DocType.ine, isReference: true, useCamera: true),
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('INE referencia'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => notifier.verify(DocType.ine, useCamera: true, skipCrossValidation: true),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Registrar otra persona'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: Colors.black54, letterSpacing: 0.5),
  );
}

// ── Reference chip ────────────────────────────────────────────────────────────

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({required this.data});
  final IdentityData data;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.indigo.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.indigo.shade200),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle, color: Colors.indigo, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '${data.lastName ?? '?'} ${data.firstName ?? '?'} — ${data.idNumber ?? '?'}',
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]),
  );
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 24),
      Text('Procesando documento…', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16)),
      SizedBox(height: 8),
      Text('Esto puede tardar unos segundos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black45)),
    ],
  );
}

// ── Success ───────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.state, required this.onReset});
  final IdentityState state;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final d = state.data!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 12),
          Text('Documento verificado',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            state.referenceData != null
                ? '✓ Validación cruzada superada'
                : 'Validación básica (sin referencia)',
            style: TextStyle(
              color: state.referenceData != null
                  ? Colors.green.shade700 : Colors.orange.shade700,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datos extraídos',
                      style: Theme.of(context).textTheme.labelLarge),
                  const Divider(height: 20),
                  _Row('Apellido paterno',  d.lastName),
                  _Row('Apellido materno',  d.secondLastName),
                  _Row('Primer nombre',     d.firstName),
                  _Row('Segundo nombre',    d.secondFirstName),
                  _Row('Fecha nacimiento',  d.birthDate),
                  _Row('CURP / ID',         d.idNumber),
                  _Row('Sexo', switch (d.sex) {
                    Sex.male   => 'H — Hombre',
                    Sex.female => 'M — Mujer',
                    null       => null,
                  }),
                  _Row('Estado',    d.state),
                  _Row('Domicilio', d.address),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Verificar otro documento'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 148,
          child: Text(label,
              style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value ?? '— no extraído',
            style: TextStyle(
              fontSize: 13,
              color: value != null ? Colors.black87 : Colors.grey,
              fontStyle: value == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.state, required this.onRetry});
  final IdentityState state;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.error_outline, size: 72, color: Colors.red),
      const SizedBox(height: 20),
      Text(state.errorMessage ?? 'Error inesperado.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center),
      const SizedBox(height: 32),
      FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Intentar de nuevo'),
      ),
    ],
  );
}