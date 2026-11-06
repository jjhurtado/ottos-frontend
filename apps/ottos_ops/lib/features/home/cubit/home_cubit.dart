import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

typedef _Pending = ({RemittanceFilter? filter, PendingTotals? totals, String? error});

enum HomeStatus { loading, success, failure }

final class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.loading,
    this.openByStatus = const [],
    this.late = 0,
    this.incidents = 0,
    this.toReview = 0,
    this.exchangesToReview = 0,
    this.pending,
    this.pendingFilter,
    this.pendingError,
    this.error,
  });

  final HomeStatus status;
  final List<StatusCount> openByStatus;
  final int late;
  final int incidents;
  final int toReview;

  /// Couriers' currency exchanges marked for review; 0 without cash:read.
  final int exchangesToReview;

  /// Money pending to deliver and to collect (REQ-021); null while it loads or
  /// when it failed, with [pendingError]. It fails on its own: the counters stay.
  final PendingTotals? pending;

  /// The open filter [pending] was summed with: its tiles open this list (REQ-021 BR-8, CR-7).
  final RemittanceFilter? pendingFilter;
  final String? pendingError;
  final String? error;

  HomeState withPending({PendingTotals? pending, RemittanceFilter? pendingFilter, String? pendingError}) => HomeState(
    status: status,
    openByStatus: openByStatus,
    late: late,
    incidents: incidents,
    toReview: toReview,
    exchangesToReview: exchangesToReview,
    pending: pending,
    pendingFilter: pendingFilter,
    pendingError: pendingError,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    openByStatus,
    late,
    incidents,
    toReview,
    exchangesToReview,
    pending,
    pendingFilter,
    pendingError,
    error,
  ];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required this._remittances, this._cash}) : super(const HomeState());

  final RemittanceRepository _remittances;

  /// Given to who can see the cash: counts the exchanges to review.
  final CashRepository? _cash;

  /// The counters (one summary call, REQ-022 OPT-F4), the exchanges and the
  /// money pending start together; the money pending still fails on its own
  /// (REQ-021 AC-1.8).
  Future<void> load() async {
    emit(const HomeState());
    final pending = _pending();
    try {
      // Future.wait, not a record's `.wait`: that one wraps the ApiException.
      final results = await Future.wait<Object>([_remittances.summary(), _exchangesToReview()]);
      final summary = results[0] as RemittanceSummary;
      emit(
        HomeState(
          status: HomeStatus.success,
          openByStatus: summary.openByStatus,
          late: summary.late,
          incidents: summary.incident,
          toReview: summary.review,
          exchangesToReview: results[1] as int,
        ),
      );
    } on ApiException catch (error) {
      emit(HomeState(status: HomeStatus.failure, error: error.message));
      return;
    }
    if (!isClosed) emit(_withPending(await pending));
  }

  /// Loads (or retries) the money pending alone (REQ-021 AC-1.8).
  Future<void> loadPending() async {
    emit(state.withPending());
    final result = await _pending();
    if (!isClosed) emit(_withPending(result));
  }

  HomeState _withPending(_Pending result) =>
      state.withPending(pending: result.totals, pendingFilter: result.filter, pendingError: result.error);

  /// The totals with the filter they were asked with, so the tiles link to the same list (CR-7).
  Future<_Pending> _pending() async {
    try {
      final filter = RemittanceFilter.pending((await _remittances.workflow()).statuses);
      return (filter: filter, totals: await _remittances.pendingTotals(filter: filter), error: null);
    } on ApiException catch (error) {
      return (filter: null, totals: null, error: error.message);
    }
  }

  Future<int> _exchangesToReview() async =>
      _cash == null ? 0 : (await _cash.exchanges(review: true, size: 1)).totalItems;
}
