import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum RemittanceDetailStatus { loading, success, failure }

/// Result of the last action, for one-off feedback (snackbars).
enum RemittanceAction { none, assigned, completed, postponed, incidentReported, reviewResolved, voided, failed }

final class RemittanceDetailState extends Equatable {
  const RemittanceDetailState({
    this.status = RemittanceDetailStatus.loading,
    this.remittance,
    this.events = const [],
    this.workflow,
    this.error,
    this.submitting = false,
    this.action = RemittanceAction.none,
    this.actionError,
  });

  final RemittanceDetailStatus status;
  final Remittance? remittance;
  final List<RemittanceEvent> events;
  final Workflow? workflow;
  final String? error;
  final bool submitting;
  final RemittanceAction action;
  final String? actionError;

  /// A status of the history, named for this remittance's type.
  String statusName(String? code) =>
      code == null ? '' : CoreTexts.statusName(code, type: remittance?.type, fallback: workflow?.nameOf(code));

  /// Copies the state; [action] and [actionError] reset unless given.
  RemittanceDetailState copyWith({
    Remittance? remittance,
    List<RemittanceEvent>? events,
    bool? submitting,
    RemittanceAction action = RemittanceAction.none,
    String? actionError,
  }) => RemittanceDetailState(
    status: status,
    remittance: remittance ?? this.remittance,
    events: events ?? this.events,
    workflow: workflow,
    error: error,
    submitting: submitting ?? this.submitting,
    action: action,
    actionError: actionError,
  );

  @override
  List<Object?> get props => [status, remittance, events, error, submitting, action, actionError];
}

class RemittanceDetailCubit extends Cubit<RemittanceDetailState> {
  RemittanceDetailCubit({required this._remittances, required this._id}) : super(const RemittanceDetailState());

  final RemittanceRepository _remittances;
  final String _id;

  Future<void> load() async {
    emit(const RemittanceDetailState());
    try {
      final results = await Future.wait<Object>([
        _remittances.get(_id),
        _remittances.events(_id),
        _remittances.workflow(),
      ], eagerError: true);
      emit(
        RemittanceDetailState(
          status: RemittanceDetailStatus.success,
          remittance: results[0] as Remittance,
          events: (results[1] as List<RemittanceEvent>).reversed.toList(),
          workflow: results[2] as Workflow,
        ),
      );
    } on ApiException catch (error) {
      emit(RemittanceDetailState(status: RemittanceDetailStatus.failure, error: error.message));
    }
  }

  Future<void> assign({required String courierId, String? note}) =>
      _run(RemittanceAction.assigned, () => _remittances.assign(_id, courierId: courierId, note: note));

  /// Completes the remittance, checking [pin] when one was typed.
  Future<void> complete({String? pin, String? note}) => _run(
    RemittanceAction.completed,
    () => pin == null || pin.isEmpty
        ? _remittances.deliver(_id, note: note)
        : _remittances.deliverWithPin(_id, pin: pin, note: note),
  );

  /// Delivers or collects it from the business's cash, without a courier.
  Future<void> completeFromBusiness({String? note}) =>
      _run(RemittanceAction.completed, () => _remittances.completeFromBusiness(_id, note: note));

  Future<void> postpone({required DateTime newDate, required String reason}) =>
      _run(RemittanceAction.postponed, () => _remittances.postpone(_id, newDate: newDate, reason: reason));

  Future<void> reportIncident({required IncidentReason reason, String? note}) =>
      _run(RemittanceAction.incidentReported, () => _remittances.reportIncident(_id, reason: reason, note: note));

  Future<void> resolveReview({required String note}) =>
      _run(RemittanceAction.reviewResolved, () => _remittances.resolveReview(_id, note: note));

  Future<void> voidRemittance({required String reason}) =>
      _run(RemittanceAction.voided, () => _remittances.voidRemittance(_id, reason: reason));

  Future<void> _run(RemittanceAction action, Future<Remittance> Function() request) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true));
    final Remittance remittance;
    try {
      remittance = await request();
    } on ApiException catch (error) {
      emit(state.copyWith(submitting: false, action: RemittanceAction.failed, actionError: error.message));
      return;
    }
    emit(state.copyWith(remittance: remittance, events: await _reloadEvents(), submitting: false, action: action));
  }

  /// The history after an action; null (keep the old one) if it cannot be reloaded,
  /// since the action itself already succeeded.
  Future<List<RemittanceEvent>?> _reloadEvents() async {
    try {
      return (await _remittances.events(_id)).reversed.toList();
    } on ApiException {
      return null;
    }
  }
}
