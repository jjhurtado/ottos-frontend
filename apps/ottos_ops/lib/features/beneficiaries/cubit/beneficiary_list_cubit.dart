import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum BeneficiaryListStatus { loading, success, failure }

final class BeneficiaryListState extends Equatable {
  const BeneficiaryListState({this.status = BeneficiaryListStatus.loading, this.query = '', this.result, this.error});

  final BeneficiaryListStatus status;
  final String query;

  /// The page on screen; kept while the next one loads.
  final PageResult<Beneficiary>? result;
  final String? error;

  List<Beneficiary> get beneficiaries => result?.items ?? const [];

  @override
  List<Object?> get props => [status, query, result, error];
}

/// Every active beneficiary, with a customer or not, by pages and the most
/// recent first: all of them without a query, matches by name or phone with one.
class BeneficiaryListCubit extends Cubit<BeneficiaryListState> {
  BeneficiaryListCubit({
    required this._customers,
    this.searchDelay = const Duration(milliseconds: 300),
    this.pageSize = 50,
  }) : super(const BeneficiaryListState());

  final CustomerRepository _customers;

  /// Wait after the last keystroke before searching.
  final Duration searchDelay;
  final int pageSize;
  Timer? _timer;
  int _request = 0;

  /// Loads [page], or the current one again.
  Future<void> load({int? page}) => _search(state.query, page ?? state.result?.page ?? 0);

  /// A new search starts at the first page.
  void queryChanged(String query) {
    _timer?.cancel();
    _timer = Timer(searchDelay, () => _search(query, 0));
  }

  /// An edited beneficiary changes in place; a new one is the most recent, so
  /// the first page is loaded again to show it with the new total.
  Future<void> saved(Beneficiary beneficiary) async {
    final result = state.result;
    final index = state.beneficiaries.indexWhere((item) => item.id == beneficiary.id);
    if (result == null || index == -1) return load(page: 0);
    final items = [...result.items]..[index] = beneficiary;
    emit(
      BeneficiaryListState(
        status: state.status,
        query: state.query,
        result: PageResult(items: items, page: result.page, size: result.size, totalItems: result.totalItems),
      ),
    );
  }

  Future<void> _search(String query, int page) async {
    final request = ++_request;
    emit(BeneficiaryListState(query: query, result: state.result));
    try {
      final result = await _customers.beneficiaryPage(query, page: page, size: pageSize);
      if (request == _request && !isClosed) {
        emit(BeneficiaryListState(status: BeneficiaryListStatus.success, query: query, result: result));
      }
    } on ApiException catch (error) {
      if (request == _request && !isClosed) {
        emit(
          BeneficiaryListState(
            status: BeneficiaryListStatus.failure,
            query: query,
            result: state.result,
            error: error.message,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
