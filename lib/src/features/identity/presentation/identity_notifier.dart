import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/doc_type.dart';
import '../../../providers.dart';
import '../domain/identity_controller.dart';
import '../domain/identity_data.dart';

enum IdentityStatus { idle, loading, success, error }

class IdentityState {
  const IdentityState({
    this.status = IdentityStatus.idle,
    this.data,
    this.referenceData,
    this.errorMessage,
  });
  final IdentityStatus status;
  final IdentityData? data;
  final IdentityData? referenceData;
  final String? errorMessage;
  bool get isLoading => status == IdentityStatus.loading;

  IdentityState copyWith({
    IdentityStatus? status,
    IdentityData? data,
    IdentityData? referenceData,
    String? errorMessage,
  }) => IdentityState(
    status: status ?? this.status,
    data: data ?? this.data,
    referenceData: referenceData ?? this.referenceData,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class IdentityNotifier extends StateNotifier<IdentityState> {
  IdentityNotifier(this._controller) : super(const IdentityState());
  final IdentityController _controller;

  // Ya no recibe BuildContext — CameraCropPage usa su propio navigatorKey global
  Future<void> verify(
    DocType type, {
    bool useCamera = false,
    bool isReference = false,
    bool skipCrossValidation = false,
  }) async {
    state = state.copyWith(status: IdentityStatus.loading);

    final authed = await _controller.authenticate();
    if (!authed) {
      state = state.copyWith(
        status: IdentityStatus.error,
        errorMessage: 'Autenticación biométrica cancelada o fallida.',
      );
      return;
    }

    final result = await _controller.processIdentity(type, useCamera: useCamera);

    switch (result) {
      case IdentityFailure(:final message):
        state = state.copyWith(status: IdentityStatus.error, errorMessage: message);
        return;
      case IdentitySuccess(:final data):
        if (isReference) {
          state = state.copyWith(status: IdentityStatus.idle, referenceData: data);
          return;
        }
        final validated = _controller.validate(
          data,
          reference: state.referenceData,
          skipCrossValidation: skipCrossValidation,
        );
        switch (validated) {
          case IdentitySuccess(:final data):
            state = state.copyWith(status: IdentityStatus.success, data: data);
          case IdentityFailure(:final message):
            state = state.copyWith(status: IdentityStatus.error, errorMessage: message);
        }
    }
  }

  void reset() => state = const IdentityState();
}

final identityNotifierProvider =
    StateNotifierProvider<IdentityNotifier, IdentityState>((ref) {
  return IdentityNotifier(ref.watch(identityControllerProvider));
});