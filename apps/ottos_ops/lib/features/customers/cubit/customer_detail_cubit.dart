import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum CustomerDetailStatus { loading, success, failure }

final class CustomerDetailState extends Equatable {
  const CustomerDetailState({
    this.status = CustomerDetailStatus.loading,
    this.customer,
    this.beneficiaries = const [],
    this.stats,
    this.error,
    this.actionError,
  });

  final CustomerDetailStatus status;
  final Customer? customer;
  final List<Beneficiary> beneficiaries;

  /// Null when the user cannot read remittances or the numbers failed to load.
  final CustomerStats? stats;
  final String? error;

  /// Error of the last change (e.g. unlinking), for a snackbar.
  final String? actionError;

  CustomerDetailState copyWith({Customer? customer, List<Beneficiary>? beneficiaries, String? actionError}) =>
      CustomerDetailState(
        status: status,
        customer: customer ?? this.customer,
        beneficiaries: beneficiaries ?? this.beneficiaries,
        stats: stats,
        error: error,
        actionError: actionError,
      );

  @override
  List<Object?> get props => [status, customer, beneficiaries, stats, error, actionError];
}

class CustomerDetailCubit extends Cubit<CustomerDetailState> {
  CustomerDetailCubit({required this._customers, required this._id, this.loadStats = true})
    : super(const CustomerDetailState());

  final CustomerRepository _customers;
  final String _id;

  /// Whether to ask for the remittance numbers (needs `remittances:read`).
  final bool loadStats;

  Future<void> load() async {
    emit(const CustomerDetailState());
    try {
      final results = await Future.wait<Object>([_customers.get(_id), _customers.beneficiaries(_id)], eagerError: true);
      emit(
        CustomerDetailState(
          status: CustomerDetailStatus.success,
          customer: results[0] as Customer,
          beneficiaries: _sorted(results[1] as List<Beneficiary>),
          stats: loadStats ? await _stats() : null,
        ),
      );
    } on ApiException catch (error) {
      emit(CustomerDetailState(status: CustomerDetailStatus.failure, error: error.message));
    }
  }

  /// The numbers are a bonus: the page works without them.
  Future<CustomerStats?> _stats() async {
    try {
      return await _customers.stats(_id);
    } on ApiException {
      return null;
    }
  }

  void customerSaved(Customer customer) => emit(state.copyWith(customer: customer));

  /// Adds or replaces [beneficiary] in the list after the form saved it.
  void beneficiarySaved(Beneficiary beneficiary) => emit(
    state.copyWith(beneficiaries: _sorted([...state.beneficiaries.where((b) => b.id != beneficiary.id), beneficiary])),
  );

  Future<void> unlink(Beneficiary beneficiary) async {
    try {
      await _customers.unlinkBeneficiary(_id, beneficiary.id);
      emit(state.copyWith(beneficiaries: state.beneficiaries.where((b) => b.id != beneficiary.id).toList()));
    } on ApiException catch (error) {
      emit(state.copyWith(actionError: error.message));
    }
  }

  static List<Beneficiary> _sorted(List<Beneficiary> beneficiaries) =>
      [...beneficiaries]..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
}
