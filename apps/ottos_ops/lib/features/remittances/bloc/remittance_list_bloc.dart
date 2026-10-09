import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

part 'remittance_list_event.dart';
part 'remittance_list_state.dart';

/// Paginated, filtered list of remittances.
class RemittanceListBloc extends Bloc<RemittanceListEvent, RemittanceListState> {
  RemittanceListBloc({required this._remittances, RemittanceFilter initialFilter = const RemittanceFilter()})
    : super(RemittanceListState(filter: initialFilter)) {
    // A newer request cancels the one in flight, so fast filter changes never
    // show stale results.
    on<RemittanceListEvent>(
      (event, emit) => switch (event) {
        RemittanceListStarted() => _onStarted(emit),
        RemittanceListFilterChanged(:final filter) => _load(emit, filter: filter, page: 0),
        RemittanceListPageRequested(:final page) => _load(emit, filter: state.filter, page: page),
      },
      transformer: restartable(),
    );
  }

  static const pageSize = 20;

  final RemittanceRepository _remittances;

  Future<void> _onStarted(Emitter<RemittanceListState> emit) async {
    try {
      final workflow = await _remittances.workflow();
      emit(state.copyWith(statuses: workflow.statuses));
    } on ApiException {
      // The list still works without the status filter.
    }
    await _load(emit, filter: state.filter, page: 0);
  }

  Future<void> _load(Emitter<RemittanceListState> emit, {required RemittanceFilter filter, required int page}) async {
    emit(state.copyWith(status: RemittanceListStatus.loading, filter: filter));
    try {
      final result = await _remittances.search(filter, page: page, size: pageSize);
      emit(state.copyWith(status: RemittanceListStatus.success, result: result));
    } on ApiException catch (error) {
      emit(state.copyWith(status: RemittanceListStatus.failure, error: error.message));
    }
  }
}
