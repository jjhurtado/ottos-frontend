import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

part 'remittance_list_event.dart';
part 'remittance_list_state.dart';

/// Paginated, filtered list of remittances.
class RemittanceListBloc extends Bloc<RemittanceListEvent, RemittanceListState> {
  RemittanceListBloc({
    required this._remittances,
    RemittanceFilter initialFilter = const RemittanceFilter(),
    this.searchDelay = const Duration(milliseconds: 400),
  }) : super(RemittanceListState(filter: initialFilter, typed: initialFilter.beneficiaryQuery ?? '')) {
    // A newer request cancels the one in flight, so fast filter changes never
    // show stale results.
    on<RemittanceListLoadEvent>(
      (event, emit) => switch (event) {
        RemittanceListStarted() => _onStarted(emit),
        RemittanceListFilterChanged(:final filter) => _load(emit, filter: filter, page: 0),
        RemittanceListPageRequested(:final page) => _load(emit, filter: state.filter, page: page),
        RemittanceListSearchApplied() => _onSearchApplied(emit),
      },
      transformer: restartable(),
    );
    // Typing must not cancel a load in flight, so it has its own handler.
    on<RemittanceListSearchTyped>(_onTyped);
  }

  static const pageSize = 20;

  /// Wait after the last keystroke before searching.
  final Duration searchDelay;

  final RemittanceRepository _remittances;
  Timer? _timer;

  /// Number of the latest load; an answer to an older one is ignored, so it
  /// cannot touch [_shown] after a cancelled request.
  var _loadId = 0;

  /// Ids shown on each page of the current search, to drop repeats on later
  /// pages (pages are by number, so a row can move to the next one).
  final _shown = <int, Set<String>>{};

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  void _onTyped(RemittanceListSearchTyped event, Emitter<RemittanceListState> emit) {
    emit(state.copyWith(typed: event.text));
    _timer?.cancel();
    _timer = Timer(searchDelay, () => add(const RemittanceListSearchApplied()));
  }

  Future<void> _onSearchApplied(Emitter<RemittanceListState> emit) async {
    final trimmed = state.typed.trim();
    final query = isSearchable(trimmed) ? trimmed : null;
    // Too short to send: nothing changes, the hint stays.
    if (query == null && trimmed.isNotEmpty) return;
    if (query == state.filter.beneficiaryQuery) return;
    await _load(emit, filter: state.filter.copyWith(beneficiaryQuery: query), page: 0);
  }

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
    final loadId = ++_loadId;
    if (filter != state.filter) _shown.clear();
    // Cleared from outside (remove filters): the field empties too.
    final cleared = filter.beneficiaryQuery == null && state.filter.beneficiaryQuery != null;
    emit(state.copyWith(status: RemittanceListStatus.loading, filter: filter, typed: cleared ? '' : null));
    try {
      final result = await _remittances.search(filter, page: page, size: pageSize);
      if (loadId != _loadId) return;
      _shown.removeWhere((shownPage, _) => shownPage >= page);
      final earlier = {for (final ids in _shown.values) ...ids};
      final items = [
        for (final item in result.items)
          if (!earlier.contains(item.id)) item,
      ];
      _shown[page] = {for (final item in items) item.id};
      emit(
        state.copyWith(
          status: RemittanceListStatus.success,
          result: PageResult(items: items, page: result.page, size: result.size, totalItems: result.totalItems),
        ),
      );
    } on ApiException catch (error) {
      emit(state.copyWith(status: RemittanceListStatus.failure, error: error.message));
    }
  }
}
