import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

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
  final String? pendingError;
  final String? error;

  HomeState withPending({PendingTotals? pending, String? pendingError}) => HomeState(
    status: status,
    openByStatus: openByStatus,
    late: late,
    incidents: incidents,
    toReview: toReview,
    exchangesToReview: exchangesToReview,
    pending: pending,
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
    final (totals, error) = await pending;
    if (!isClosed) emit(state.withPending(pending: totals, pendingError: error));
  }

  /// Loads (or retries) the money pending alone (REQ-021 AC-1.8).
  Future<void> loadPending() async {
    emit(state.withPending());
    final (totals, error) = await _pending();
    if (!isClosed) emit(state.withPending(pending: totals, pendingError: error));
  }

  Future<(PendingTotals?, String?)> _pending() async {
    try {
      return (await _remittances.pendingTotals(), null);
    } on ApiException catch (error) {
      return (null, error.message);
    }
  }

  Future<int> _exchangesToReview() async =>
      _cash == null ? 0 : (await _cash.exchanges(review: true, size: 1)).totalItems;
}
