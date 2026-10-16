import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

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
    this.error,
  });

  final AssignedStatus status;

  /// In the order of [sort].
  final List<Remittance> items;
  final AssignedSort sort;

  /// Also lists the delivered and collected remittances, after the open ones (sales).
  final bool showCompleted;

  /// How many pages of completed ones are loaded, and whether there are more.
  final int completedPages;
  final bool moreCompleted;

  /// Remittances with an action not sent yet (no network).
  final Set<String> pendingIds;
  final String? error;

  AssignedState copyWith({
    AssignedStatus? status,
    List<Remittance>? items,
    AssignedSort? sort,
    bool? showCompleted,
    int? completedPages,
    bool? moreCompleted,
    Set<String>? pendingIds,
    String? error,
  }) => AssignedState(
    status: status ?? this.status,
    items: sorted(items ?? this.items, sort ?? this.sort),
    sort: sort ?? this.sort,
    showCompleted: showCompleted ?? this.showCompleted,
    completedPages: completedPages ?? this.completedPages,
    moreCompleted: moreCompleted ?? this.moreCompleted,
    pendingIds: pendingIds ?? this.pendingIds,
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
  List<Object?> get props => [status, items, sort, showCompleted, completedPages, moreCompleted, pendingIds, error];
}

/// The open remittances of the courier, or all of them for who sees every
/// remittance (sales), and the actions on them from the list.
class AssignedCubit extends Cubit<AssignedState> {
  AssignedCubit({required this._source}) : super(const AssignedState()) {
    // A sync may bring new remittances or take some away.
    _changes = _source.changes.listen((_) => load());
  }

  final RemittanceSource _source;
  late final StreamSubscription<void> _changes;

  /// Loads the list; keeps the current items visible while refreshing.
  Future<void> load() async {
    if (state.items.isEmpty) {
      emit(
        AssignedState(sort: state.sort, showCompleted: state.showCompleted, completedPages: state.completedPages),
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

  void sortBy(AssignedSort sort) => emit(state.copyWith(sort: sort));

  /// Whether the source can list the completed ones too (sales).
  bool get canShowCompleted => _source.canShowCompleted;

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
    await _changes.cancel();
    return super.close();
  }
}
