import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum MovementLedgerStatus { loading, success, failure }

final class MovementLedgerState extends Equatable {
  const MovementLedgerState({
    this.status = MovementLedgerStatus.loading,
    this.filter = const MovementFilter(),
    this.result,
    this.error,
  });

  final MovementLedgerStatus status;
  final MovementFilter filter;

  /// The page shown; kept while the next one loads.
  final PageResult<CashMovement>? result;
  final String? error;

  @override
  List<Object?> get props => [status, filter, result?.page, result?.items, result?.totalItems, error];
}

/// Reads one page of a cash ledger.
typedef MovementPageFetch = Future<PageResult<CashMovement>> Function(MovementFilter filter, {int page, int size});

/// A cash ledger (the business's or a courier's), newest first, filtered and a
/// page at a time (REQ-024 BR-3).
class MovementLedgerCubit extends Cubit<MovementLedgerState> {
  MovementLedgerCubit(this._fetch) : super(const MovementLedgerState());

  final MovementPageFetch _fetch;

  static const pageSize = 50;

  /// Loads [page], or the current one again.
  Future<void> load({int? page}) async {
    final index = page ?? state.result?.page ?? 0;
    emit(MovementLedgerState(filter: state.filter, result: state.result));
    try {
      final result = await _fetch(state.filter, page: index, size: pageSize);
      if (isClosed) return;
      emit(MovementLedgerState(status: MovementLedgerStatus.success, filter: state.filter, result: result));
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(
          MovementLedgerState(
            status: MovementLedgerStatus.failure,
            filter: state.filter,
            result: state.result,
            error: error.message,
          ),
        );
      }
    }
  }

  /// A new filter starts again at the first page (AC-2.2).
  Future<void> filter(MovementFilter filter) {
    emit(MovementLedgerState(filter: filter, result: state.result));
    return load(page: 0);
  }
}
