import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum CustomerListStatus { loading, success, failure }

final class CustomerListState extends Equatable {
  const CustomerListState({
    this.status = CustomerListStatus.loading,
    this.query = '',
    this.customers = const [],
    this.error,
  });

  final CustomerListStatus status;
  final String query;
  final List<Customer> customers;
  final String? error;

  @override
  List<Object?> get props => [status, query, customers, error];
}

/// Customer search: the most recent ones without a query, matches by name or phone with one.
class CustomerListCubit extends Cubit<CustomerListState> {
  CustomerListCubit({required this._customers, this.searchDelay = const Duration(milliseconds: 300)})
    : super(const CustomerListState());

  final CustomerRepository _customers;

  /// Wait after the last keystroke before searching.
  final Duration searchDelay;
  Timer? _timer;
  int _request = 0;

  Future<void> load() => _search(state.query);

  void queryChanged(String query) {
    _timer?.cancel();
    _timer = Timer(searchDelay, () => _search(query));
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    emit(CustomerListState(query: query, customers: state.customers));
    try {
      final customers = await _customers.search(query);
      if (request == _request && !isClosed) {
        emit(CustomerListState(status: CustomerListStatus.success, query: query, customers: customers));
      }
    } on ApiException catch (error) {
      if (request == _request && !isClosed) {
        emit(CustomerListState(status: CustomerListStatus.failure, query: query, error: error.message));
      }
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
