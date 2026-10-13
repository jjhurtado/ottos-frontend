import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum BeneficiaryListStatus { loading, success, failure }

final class BeneficiaryListState extends Equatable {
  const BeneficiaryListState({
    this.status = BeneficiaryListStatus.loading,
    this.query = '',
    this.beneficiaries = const [],
    this.error,
  });

  final BeneficiaryListStatus status;
  final String query;
  final List<Beneficiary> beneficiaries;
  final String? error;

  @override
  List<Object?> get props => [status, query, beneficiaries, error];
}

/// Every beneficiary, with a customer or not: the most recent ones without a
/// query, matches by name or phone with one (the backend returns at most 50).
class BeneficiaryListCubit extends Cubit<BeneficiaryListState> {
  BeneficiaryListCubit({required this._customers, this.searchDelay = const Duration(milliseconds: 300)})
    : super(const BeneficiaryListState());

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

  /// Puts an edited or new beneficiary in the list without searching again.
  void saved(Beneficiary beneficiary) {
    final index = state.beneficiaries.indexWhere((item) => item.id == beneficiary.id);
    final beneficiaries = [...state.beneficiaries];
    if (index == -1) {
      beneficiaries.insert(0, beneficiary);
    } else {
      beneficiaries[index] = beneficiary;
    }
    emit(BeneficiaryListState(status: state.status, query: state.query, beneficiaries: beneficiaries));
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    emit(BeneficiaryListState(query: query, beneficiaries: state.beneficiaries));
    try {
      final beneficiaries = await _customers.searchBeneficiaries(query);
      if (request == _request && !isClosed) {
        emit(BeneficiaryListState(status: BeneficiaryListStatus.success, query: query, beneficiaries: beneficiaries));
      }
    } on ApiException catch (error) {
      if (request == _request && !isClosed) {
        emit(BeneficiaryListState(status: BeneficiaryListStatus.failure, query: query, error: error.message));
      }
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
