import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum RemittanceDetailStatus { loading, success, failure }

final class RemittanceDetailState extends Equatable {
  const RemittanceDetailState({
    this.status = RemittanceDetailStatus.loading,
    this.remittance,
    this.events = const [],
    this.workflow,
    this.error,
  });

  final RemittanceDetailStatus status;
  final Remittance? remittance;
  final List<RemittanceEvent> events;
  final Workflow? workflow;
  final String? error;

  String statusName(String? code) => code == null ? '' : workflow?.nameOf(code) ?? code;

  @override
  List<Object?> get props => [status, remittance, events, error];
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
}
