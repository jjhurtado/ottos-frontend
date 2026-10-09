import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum AssignedStatus { loading, success, failure }

final class AssignedState extends Equatable {
  const AssignedState({this.status = AssignedStatus.loading, this.items = const [], this.error});

  final AssignedStatus status;
  final List<Remittance> items;
  final String? error;

  @override
  List<Object?> get props => [status, items, error];
}

/// The courier's open remittances, soonest expected date first.
class AssignedCubit extends Cubit<AssignedState> {
  AssignedCubit({required this._remittances}) : super(const AssignedState());

  final RemittanceRepository _remittances;

  /// Loads the list; keeps the current items visible while refreshing.
  Future<void> load() async {
    if (state.items.isEmpty) emit(const AssignedState());
    try {
      emit(AssignedState(status: AssignedStatus.success, items: await _remittances.assignedToMe()));
    } on ApiException catch (error) {
      emit(AssignedState(status: AssignedStatus.failure, items: state.items, error: error.message));
    }
  }
}
