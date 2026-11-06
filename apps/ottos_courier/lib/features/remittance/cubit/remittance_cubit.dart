import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../offline/remittance_source.dart';
import '../../../offline/sync_cubit.dart';

enum RemittanceLoadStatus { loading, success, failure }

/// Result of the last action, for one-off feedback (snackbars).
enum RemittanceActionResult {
  none,
  completed,
  completedByBusiness,
  postponed,
  incidentReported,
  assigned,
  queued,
  flagged,
  failed,
}

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
  RemittanceCubit({required this._source, required this._remittances, required this._id})
    : super(const RemittanceState());

  final RemittanceSource _source;

  /// For assigning and completing from the business, always online (sales).
  final RemittanceRepository _remittances;
  final String _id;

  Future<void> load() async {
    emit(const RemittanceState());
    try {
      emit(RemittanceState(status: RemittanceLoadStatus.success, remittance: await _source.get(_id)));
    } on ApiException catch (error) {
      emit(RemittanceState(status: RemittanceLoadStatus.failure, error: error.message));
    }
  }

  /// Completes the remittance, checking [pin] when the courier typed one.
  Future<void> complete({String? pin, String? note}) =>
      _perform(RemittanceActionResult.completed, (remittance) => _source.deliver(remittance, pin: pin, note: note));

  Future<void> postpone({required DateTime newDate, required String reason}) => _perform(
    RemittanceActionResult.postponed,
    (remittance) => _source.postpone(remittance, newDate: newDate, reason: reason),
  );

  Future<void> reportIncident({required IncidentReason reason, String? note}) => _perform(
    RemittanceActionResult.incidentReported,
    (remittance) => _source.reportIncident(remittance, reason: reason, note: note),
  );

  Future<void> assign({required String courierId, String? note}) =>
      _perform(RemittanceActionResult.assigned, (_) async {
        try {
          return Applied(await _remittances.assign(_id, courierId: courierId, note: note));
        } on ApiException catch (error) {
          return Rejected(error.message);
        }
      });

  /// Delivered (or collected) by the business, without a courier: its cash
  /// pays out or takes in, and an assigned courier loses it.
  Future<void> completeFromBusiness({String? note}) => _perform(RemittanceActionResult.completedByBusiness, (_) async {
    try {
      return Applied(await _remittances.completeFromBusiness(_id, note: note));
    } on ApiException catch (error) {
      return Rejected(error.message);
    }
  });

  Future<void> _perform(
    RemittanceActionResult result,
    Future<ActionOutcome> Function(Remittance remittance) action,
  ) async {
    final remittance = state.remittance;
    if (state.submitting || remittance == null) return;
    emit(state.copyWith(submitting: true));
    final outcome = await action(remittance);
    if (isClosed) return;
    emit(switch (outcome) {
      Applied(remittance: final updated, :final flaggedForReview) => state.copyWith(
        remittance: updated,
        submitting: false,
        actionResult: flaggedForReview ? RemittanceActionResult.flagged : result,
      ),
      Queued() => state.copyWith(submitting: false, actionResult: RemittanceActionResult.queued),
      Rejected(:final message) => state.copyWith(
        submitting: false,
        actionResult: RemittanceActionResult.failed,
        error: message,
      ),
    });
  }
}
