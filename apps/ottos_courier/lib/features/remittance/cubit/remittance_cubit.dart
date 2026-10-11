import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum RemittanceLoadStatus { loading, success, failure }

/// Result of the last action, for one-off feedback (snackbars).
enum RemittanceActionResult { none, completed, postponed, incidentReported, assigned, failed }

final class RemittanceState extends Equatable {
  const RemittanceState({
    this.status = RemittanceLoadStatus.loading,
    this.remittance,
    this.submitting = false,
    this.actionResult = RemittanceActionResult.none,
    this.error,
  });

  final RemittanceLoadStatus status;
  final Remittance? remittance;
  final bool submitting;
  final RemittanceActionResult actionResult;
  final String? error;

  RemittanceState copyWith({
    RemittanceLoadStatus? status,
    Remittance? remittance,
    bool? submitting,
    RemittanceActionResult? actionResult,
    String? error,
  }) => RemittanceState(
    status: status ?? this.status,
    remittance: remittance ?? this.remittance,
    submitting: submitting ?? this.submitting,
    actionResult: actionResult ?? RemittanceActionResult.none,
    error: error,
  );

  @override
  List<Object?> get props => [status, remittance, submitting, actionResult, error];
}

class RemittanceCubit extends Cubit<RemittanceState> {
  RemittanceCubit({required this._remittances, required this._id}) : super(const RemittanceState());

  final RemittanceRepository _remittances;
  final String _id;

  Future<void> load() async {
    emit(const RemittanceState());
    try {
      emit(RemittanceState(status: RemittanceLoadStatus.success, remittance: await _remittances.get(_id)));
    } on ApiException catch (error) {
      emit(RemittanceState(status: RemittanceLoadStatus.failure, error: error.message));
    }
  }

  /// Completes the remittance, checking [pin] when the courier typed one.
  Future<void> complete({String? pin, String? note}) => _run(
    RemittanceActionResult.completed,
    () => pin == null || pin.isEmpty
        ? _remittances.deliver(_id, note: note)
        : _remittances.deliverWithPin(_id, pin: pin, note: note),
  );

  Future<void> postpone({required DateTime newDate, required String reason}) =>
      _run(RemittanceActionResult.postponed, () => _remittances.postpone(_id, newDate: newDate, reason: reason));

  Future<void> reportIncident({required IncidentReason reason, String? note}) =>
      _run(RemittanceActionResult.incidentReported, () => _remittances.reportIncident(_id, reason: reason, note: note));

  Future<void> assign({required String courierId, String? note}) =>
      _run(RemittanceActionResult.assigned, () => _remittances.assign(_id, courierId: courierId, note: note));

  Future<void> _run(RemittanceActionResult result, Future<Remittance> Function() action) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true));
    try {
      emit(state.copyWith(remittance: await action(), submitting: false, actionResult: result));
    } on ApiException catch (error) {
      emit(state.copyWith(submitting: false, actionResult: RemittanceActionResult.failed, error: error.message));
    }
  }
}
