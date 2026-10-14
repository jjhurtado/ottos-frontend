import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum CustomerListStatus { loading, success, failure }

final class CustomerListState extends Equatable {
  const CustomerListState({this.status = CustomerListStatus.loading, this.query = '', this.result, this.error});

  final CustomerListStatus status;
  final String query;

  /// The page on screen; kept while the next one loads.
  final PageResult<Customer>? result;
  final String? error;

  List<Customer> get customers => result?.items ?? const [];

  @override
  List<Object?> get props => [status, query, result, error];
}

/// Customers by pages, the most recent first: all of them without a query,
/// matches by name or phone with one.
class CustomerListCubit extends Cubit<CustomerListState> {
  CustomerListCubit({
    required this._customers,
    this.searchDelay = const Duration(milliseconds: 300),
    this.pageSize = 50,
  }) : super(const CustomerListState());

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

  Future<void> _search(String query, int page) async {
    final request = ++_request;
    emit(CustomerListState(query: query, result: state.result));
    try {
      final result = await _customers.customerPage(query, page: page, size: pageSize);
      if (request == _request && !isClosed) {
        emit(CustomerListState(status: CustomerListStatus.success, query: query, result: result));
      }
    } on ApiException catch (error) {
      if (request == _request && !isClosed) {
        emit(
          CustomerListState(
            status: CustomerListStatus.failure,
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
