import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

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
    this.error,
  });

  final AssignedStatus status;

  /// In the order of [sort].
  final List<Remittance> items;
  final AssignedSort sort;
  final String? error;

  AssignedState copyWith({AssignedStatus? status, List<Remittance>? items, AssignedSort? sort, String? error}) =>
      AssignedState(
        status: status ?? this.status,
        items: sorted(items ?? this.items, sort ?? this.sort),
        sort: sort ?? this.sort,
        error: error,
      );

  /// [items] in the order of [sort]; ties by expected date, then code.
  static List<Remittance> sorted(List<Remittance> items, AssignedSort sort, {DateTime? now}) {
    int byDate(Remittance a, Remittance b) {
      final dates = (a.expectedDate ?? DateTime(9999)).compareTo(b.expectedDate ?? DateTime(9999));
      return dates != 0 ? dates : a.code.compareTo(b.code);
    }

    bool setAside(Remittance remittance) => remittance.late || remittance.incident != null;

    return [...items]..sort(
      (a, b) => switch (sort) {
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
  List<Object?> get props => [status, items, sort, error];
}

/// The courier's open remittances, and the actions on them from the list.
class AssignedCubit extends Cubit<AssignedState> {
  AssignedCubit({required this._remittances}) : super(const AssignedState());

  final RemittanceRepository _remittances;

  /// Loads the list; keeps the current items visible while refreshing.
  Future<void> load() async {
    if (state.items.isEmpty) emit(AssignedState(sort: state.sort));
    try {
      emit(state.copyWith(status: AssignedStatus.success, items: await _remittances.assignedToMe()));
    } on ApiException catch (error) {
      emit(state.copyWith(status: AssignedStatus.failure, error: error.message));
    }
  }

  void sortBy(AssignedSort sort) => emit(state.copyWith(sort: sort));

  /// Completes a remittance, checking [pin] when one was typed. Returns the
  /// error to show, or null when it went through.
  Future<String?> complete(Remittance remittance, {String? pin, String? note}) => _run(
    () => pin == null || pin.isEmpty
        ? _remittances.deliver(remittance.id, note: note)
        : _remittances.deliverWithPin(remittance.id, pin: pin, note: note),
  );

  Future<String?> reportIncident(Remittance remittance, {required IncidentReason reason, String? note}) =>
      _run(() => _remittances.reportIncident(remittance.id, reason: reason, note: note));

  Future<String?> _run(Future<Remittance> Function() action) async {
    try {
      await action();
    } on ApiException catch (error) {
      return error.message;
    }
    await load();
    return null;
  }
}
