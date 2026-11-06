import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';
import '../../../offline/remittance_source.dart';
import '../../../offline/sync_cubit.dart';

enum AssignedStatus { loading, success, failure }

/// How the list is ordered.
enum AssignedSort {
  /// The day's work first: late remittances and those with an incident go last.
  byDay,

  /// Most days late first.
  mostLate,
}

final class AssignedState extends Equatable {
  const AssignedState({
    this.status = AssignedStatus.loading,
    this.items = const [],
    this.sort = AssignedSort.byDay,
    this.showCompleted = false,
    this.completedPages = 1,
    this.moreCompleted = false,
    this.pendingIds = const {},
    this.typed = '',
    this.query,
    this.results = const [],
    this.searchPages = 1,
    this.moreResults = false,
    this.searchOffline = false,
    this.error,
  });

  final AssignedStatus status;

  /// In the order of [sort].
  final List<Remittance> items;
  final AssignedSort sort;

  /// Also lists the delivered and collected remittances, after the open ones
  /// (sales; the courier's latest 20, REQ-017). Off by default, not remembered.
  final bool showCompleted;

  /// How many pages of completed ones are loaded, and whether there are more.
  final int completedPages;
  final bool moreCompleted;

  /// Remittances with an action not sent yet (no network).
  final Set<String> pendingIds;

  /// What is typed in the search field, and the text being searched (null when
  /// not searching: empty or too short to send; REQ-018).
  final String typed;
  final String? query;

  /// The server's results of [query], in its order (most recent first).
  final List<Remittance> results;
  final int searchPages;
  final bool moreResults;

  /// The last search failed for lack of connection.
  final bool searchOffline;
  final String? error;

  bool get searching => query != null;

  /// Something is typed but too short to search.
  bool get searchTooShort => typed.trim().isNotEmpty && !isBeneficiarySearchable(typed);

  AssignedState copyWith({
    AssignedStatus? status,
    List<Remittance>? items,
    AssignedSort? sort,
    bool? showCompleted,
    int? completedPages,
    bool? moreCompleted,
    Set<String>? pendingIds,
    String? typed,
    String? query,
    bool clearQuery = false,
    List<Remittance>? results,
    int? searchPages,
    bool? moreResults,
    bool? searchOffline,
    String? error,
  }) => AssignedState(
    status: status ?? this.status,
    items: sorted(items ?? this.items, sort ?? this.sort),
    sort: sort ?? this.sort,
    showCompleted: showCompleted ?? this.showCompleted,
    completedPages: completedPages ?? this.completedPages,
    moreCompleted: moreCompleted ?? this.moreCompleted,
    pendingIds: pendingIds ?? this.pendingIds,
    typed: typed ?? this.typed,
    query: clearQuery ? null : query ?? this.query,
    results: results ?? this.results,
    searchPages: searchPages ?? this.searchPages,
    moreResults: moreResults ?? this.moreResults,
    searchOffline: searchOffline ?? this.searchOffline,
    error: error,
  );

  /// [items] in the order of [sort]; ties by expected date, then code. Completed
  /// ones go after the open ones, the latest first.
  static List<Remittance> sorted(List<Remittance> items, AssignedSort sort, {DateTime? now}) {
    int byDate(Remittance a, Remittance b) {
      final dates = (a.expectedDate ?? DateTime(9999)).compareTo(b.expectedDate ?? DateTime(9999));
      return dates != 0 ? dates : a.code.compareTo(b.code);
    }

    bool setAside(Remittance remittance) => remittance.late || remittance.incident != null;

    return [...items]..sort(
      (a, b) => switch (sort) {
        _ when a.isCompleted != b.isCompleted => a.isCompleted ? 1 : -1,
        // Safe: isCompleted is completedAt != null, so both have a date here. One
        // without a date is not completed by definition and sorts with the open ones.
        _ when a.isCompleted => switch (b.completedAt!.compareTo(a.completedAt!)) {
          0 => a.code.compareTo(b.code),
          final order => order,
        },
        AssignedSort.byDay when setAside(a) != setAside(b) => setAside(a) ? 1 : -1,
        AssignedSort.byDay => byDate(a, b),
        AssignedSort.mostLate => switch (b.daysLate(now: now).compareTo(a.daysLate(now: now))) {
          0 => byDate(a, b),
          final order => order,
        },
      },
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    sort,
    showCompleted,
    completedPages,
    moreCompleted,
    pendingIds,
    typed,
    query,
    results,
    searchPages,
    moreResults,
    searchOffline,
    error,
  ];
}

/// The open remittances of the courier, or all of them for who sees every
/// remittance (sales), and the actions on them from the list.
class AssignedCubit extends Cubit<AssignedState> {
  AssignedCubit({required this._source, this.searchDelay = const Duration(milliseconds: 400)})
    : super(const AssignedState()) {
    // A sync may bring new remittances or take some away.
    _changes = _source.changes.listen((_) => load());
  }

  final RemittanceSource _source;

  /// Wait after the last keystroke before searching.
  final Duration searchDelay;
  Timer? _timer;
  late final StreamSubscription<void> _changes;

  /// Loads the list; keeps the current items visible while refreshing.
  Future<void> load() async {
    if (state.searching) return _loadSearch();
    if (state.items.isEmpty) {
      emit(
        AssignedState(
          sort: state.sort,
          showCompleted: state.showCompleted,
          completedPages: state.completedPages,
          typed: state.typed,
        ),
      );
    }
    try {
      final items = [...await _source.list()];
      var moreCompleted = false;
      if (state.showCompleted) {
        final open = {for (final remittance in items) remittance.id};
        for (var page = 0; page < state.completedPages; page++) {
          final result = await _source.completed(page: page);
          items.addAll(result.items.where((remittance) => !open.contains(remittance.id)));
          moreCompleted = page + 1 < result.totalPages;
          if (!moreCompleted) break;
        }
      }
      final pendingIds = await _source.pendingIds();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AssignedStatus.success,
          items: items,
          moreCompleted: moreCompleted,
          pendingIds: pendingIds,
        ),
      );
    } on ApiException catch (error) {
      if (!isClosed) emit(state.copyWith(status: AssignedStatus.failure, error: error.message));
    }
  }

  /// Pull to refresh: syncs first when the courier works offline.
  Future<void> refresh() async {
    await _source.refresh();
    await load();
  }

  /// Whether the source can search by beneficiary (sales).
  bool get canSearch => _source.canSearch;

  /// The search field changed: after [searchDelay] without typing, searches
  /// from 2 letters or 4 digits, and empty goes back to the list.
  void searchTyped(String text) {
    emit(state.copyWith(typed: text));
    _timer?.cancel();
    _timer = Timer(searchDelay, _applySearch);
  }

  /// Empties the search and goes back to the list.
  void clearSearch() {
    _timer?.cancel();
    emit(state.copyWith(typed: '', clearQuery: true, results: const [], searchOffline: false));
    unawaited(load());
  }

  Future<void> _applySearch() async {
    final trimmed = state.typed.trim();
    if (trimmed.isEmpty) return clearSearch();
    // Too short to send: nothing changes, the hint stays.
    if (!isBeneficiarySearchable(trimmed) || trimmed == state.query) return;
    emit(state.copyWith(query: trimmed, results: const [], searchPages: 1, moreResults: false, searchOffline: false));
    await _loadSearch();
  }

  /// The next page of results («Ver más»).
  Future<void> moreSearch() async {
    if (_loadingMore) return;
    _loadingMore = true;
    emit(state.copyWith(searchPages: state.searchPages + 1));
    try {
      await _loadSearch();
    } finally {
      _loadingMore = false;
    }
  }

  int _searchToken = 0;

  Future<void> _loadSearch() async {
    final query = state.query!;
    final token = ++_searchToken;
    emit(state.copyWith(status: AssignedStatus.loading, searchOffline: false));
    try {
      final results = <Remittance>[];
      var more = false;
      for (var page = 0; page < state.searchPages; page++) {
        final result = await _source.search(query, page: page);
        // Pages are by number, so a row can move to the next one: drop repeats.
        final seen = {for (final remittance in results) remittance.id};
        results.addAll(result.items.where((remittance) => !seen.contains(remittance.id)));
        more = page + 1 < result.totalPages;
        if (!more) break;
      }
      if (isClosed || token != _searchToken) return;
      emit(state.copyWith(status: AssignedStatus.success, results: results, moreResults: more));
    } on ApiException catch (error) {
      if (isClosed || token != _searchToken) return;
      // No status code and no error code: the request never reached the server.
      final offline = error.statusCode == null && error.code == null;
      emit(
        state.copyWith(
          status: AssignedStatus.failure,
          searchOffline: offline,
          error: offline ? CourierTexts.searchNeedsConnection : error.message,
        ),
      );
    }
  }

  void sortBy(AssignedSort sort) => emit(state.copyWith(sort: sort));

  /// Whether the source can list the completed ones too (sales, and the
  /// courier's latest ones).
  bool get canShowCompleted => _source.canShowCompleted;

  /// Whether the completed ones are only the latest few (the courier), with a heading.
  bool get completedAreLatest => _source.completedAreLatest;

  /// Shows or hides the completed remittances and reloads.
  Future<void> showCompleted(bool show) async {
    emit(state.copyWith(showCompleted: show, completedPages: 1, moreCompleted: false));
    await load();
  }

  /// The next page of completed ones («Ver más»).
  Future<void> moreCompleted() async {
    if (_loadingMore) return;
    _loadingMore = true;
    emit(state.copyWith(completedPages: state.completedPages + 1));
    try {
      await load();
    } finally {
      _loadingMore = false;
    }
  }

  bool _loadingMore = false;

  /// Completes a remittance, checking [pin] when one was typed.
  Future<ActionOutcome> complete(Remittance remittance, {String? pin, String? note}) =>
      _run(_source.deliver(remittance, pin: pin, note: note));

  Future<ActionOutcome> reportIncident(Remittance remittance, {required IncidentReason reason, String? note}) =>
      _run(_source.reportIncident(remittance, reason: reason, note: note));

  Future<ActionOutcome> _run(Future<ActionOutcome> action) async {
    final outcome = await action;
    if (outcome is! Rejected) await load();
    return outcome;
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _changes.cancel();
    return super.close();
  }
}
