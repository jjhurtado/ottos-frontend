import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

final class HistoricalRemittanceState extends Equatable {
  const HistoricalRemittanceState({
    this.customer,
    this.beneficiariesStatus = LoadStatus.loading,
    this.beneficiaries = const [],
    this.beneficiary,
    this.submitting = false,
    this.error,
    this.created,
  });

  final Customer? customer;
  final LoadStatus beneficiariesStatus;
  final List<Beneficiary> beneficiaries;
  final Beneficiary? beneficiary;
  final bool submitting;
  final String? error;

  /// Set once registered; the page opens it.
  final Remittance? created;

  HistoricalRemittanceState copyWith({
    Customer? Function()? customer,
    LoadStatus? beneficiariesStatus,
    List<Beneficiary>? beneficiaries,
    Beneficiary? Function()? beneficiary,
    bool? submitting,
    String? Function()? error,
    Remittance? created,
  }) => HistoricalRemittanceState(
    customer: customer == null ? this.customer : customer(),
    beneficiariesStatus: beneficiariesStatus ?? this.beneficiariesStatus,
    beneficiaries: beneficiaries ?? this.beneficiaries,
    beneficiary: beneficiary == null ? this.beneficiary : beneficiary(),
    submitting: submitting ?? this.submitting,
    error: error == null ? this.error : error(),
    created: created ?? this.created,
  );

  @override
  List<Object?> get props => [customer, beneficiariesStatus, beneficiaries, beneficiary, submitting, error, created];
}

/// An old remittance typed in from its ticket: sender, beneficiary and the
/// ticket's figures. The figures live in the form; this keeps who and the call.
class HistoricalRemittanceCubit extends Cubit<HistoricalRemittanceState> {
  HistoricalRemittanceCubit({required this._remittances, required this._customers})
    : super(const HistoricalRemittanceState());

  final RemittanceRepository _remittances;
  final CustomerRepository _customers;

  Future<List<Customer>> searchCustomers(String query) => _customers.search(query);

  Future<List<Beneficiary>> searchBeneficiaries(String query) => _customers.searchBeneficiaries(query);

  Future<void> customerSelected(Customer? customer) async {
    emit(
      HistoricalRemittanceState(
        customer: customer,
        beneficiariesStatus: customer == null ? LoadStatus.success : LoadStatus.loading,
      ),
    );
    if (customer == null) return;
    try {
      final beneficiaries = await _customers.beneficiaries(customer.id);
      if (isClosed || state.customer?.id != customer.id) return;
      emit(state.copyWith(beneficiariesStatus: LoadStatus.success, beneficiaries: beneficiaries));
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(beneficiariesStatus: LoadStatus.failure, error: () => error.message));
    }
  }

  void beneficiarySelected(Beneficiary? beneficiary) => emit(state.copyWith(beneficiary: () => beneficiary));

  /// One found among all, or just created: added to the list and chosen.
  void beneficiaryAdded(Beneficiary beneficiary) => emit(
    state.copyWith(
      beneficiaries: [beneficiary, ...state.beneficiaries.where((item) => item.id != beneficiary.id)],
      beneficiary: () => beneficiary,
    ),
  );

  Future<void> submit(HistoricalRemittance Function(String customerId, String beneficiaryId) build) async {
    final customer = state.customer;
    final beneficiary = state.beneficiary;
    if (customer == null || beneficiary == null || state.submitting) return;
    emit(state.copyWith(submitting: true, error: () => null));
    try {
      final created = await _remittances.registerHistorical(build(customer.id, beneficiary.id));
      if (!isClosed) emit(state.copyWith(submitting: false, created: created));
    } on ApiException catch (error) {
      if (!isClosed) emit(state.copyWith(submitting: false, error: () => error.message));
    }
  }
}
