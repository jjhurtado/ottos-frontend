import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum LoadStatus { loading, success, failure }

final class NewRemittanceState extends Equatable {
  const NewRemittanceState({
    this.corridorsStatus = LoadStatus.loading,
    this.targetCurrencies = const [],
    this.type = RemittanceType.delivery,
    this.customer,
    this.beneficiariesStatus = LoadStatus.success,
    this.beneficiaries = const [],
    this.beneficiary,
    this.targetCurrency,
    this.amount,
    this.quoteStatus = LoadStatus.success,
    this.quote,
    this.submitting = false,
    this.created,
    this.error,
  });

  final LoadStatus corridorsStatus;

  /// Currencies a USD remittance can be delivered in (corridors with a rate).
  final List<String> targetCurrencies;
  final RemittanceType type;
  final Customer? customer;
  final LoadStatus beneficiariesStatus;
  final List<Beneficiary> beneficiaries;
  final Beneficiary? beneficiary;
  final String? targetCurrency;
  final double? amount;
  final LoadStatus quoteStatus;

  /// Quote for the current [amount] and [targetCurrency]; null while there is none.
  final Quote? quote;
  final bool submitting;

  /// The remittance just registered; the page opens it.
  final Remittance? created;
  final String? error;

  bool get canSubmit =>
      customer != null && beneficiary != null && targetCurrency != null && quote != null && !submitting;

  @override
  List<Object?> get props => [
    corridorsStatus,
    targetCurrencies,
    type,
    customer,
    beneficiariesStatus,
    beneficiaries,
    beneficiary,
    targetCurrency,
    amount,
    quoteStatus,
    quote,
    submitting,
    created,
    error,
  ];
}

class NewRemittanceCubit extends Cubit<NewRemittanceState> {
  NewRemittanceCubit({
    required this._remittances,
    required this._customers,
    required this._rates,
    this.quoteDelay = const Duration(milliseconds: 400),
  }) : super(const NewRemittanceState());

  static const sourceCurrency = 'USD';

  /// Offered first and preselected when there is a rate for it.
  static const defaultTargetCurrency = 'USD';

  final RemittanceRepository _remittances;
  final CustomerRepository _customers;
  final RateRepository _rates;

  /// Wait after the last change before asking for a quote.
  final Duration quoteDelay;

  /// One key per form: a double click or a retry registers a single remittance.
  final String _idempotencyKey = RemittanceRepository.newIdempotencyKey();
  Timer? _quoteTimer;
  int _quoteRequest = 0;

  /// Loads the currencies and, with [customerId], starts with that customer chosen.
  Future<void> load({String? customerId}) async {
    _emit(corridorsStatus: LoadStatus.loading, error: null);
    if (customerId != null && state.customer == null) {
      try {
        final customer = await _customers.get(customerId);
        if (customer.active) unawaited(customerSelected(customer));
      } on ApiException {
        // Start with an empty form; the user searches the customer.
      }
    }
    try {
      _corridors = await _rates.corridors();
      final currencies = _currenciesFor(state.type);
      _emit(
        corridorsStatus: LoadStatus.success,
        targetCurrencies: currencies,
        targetCurrency: currencies.isEmpty ? null : currencies.first,
      );
    } on ApiException catch (error) {
      _emit(corridorsStatus: LoadStatus.failure, error: error.message);
    }
  }

  List<Corridor> _corridors = const [];

  /// Deliveries and pickups have their own rates, so each offers the
  /// currencies it has a rate for.
  List<String> _currenciesFor(RemittanceType type) => [
    for (final corridor in _corridors)
      if (corridor.canQuoteFor(type) && corridor.sourceCurrency == sourceCurrency) corridor.targetCurrency,
  ]..sort((a, b) => a == defaultTargetCurrency ? -1 : (b == defaultTargetCurrency ? 1 : a.compareTo(b)));

  Future<List<Customer>> searchCustomers(String query) => _customers.search(query);

  /// Changes the rate and fee that apply, so the quote is asked again.
  void typeChanged(RemittanceType type) {
    final currencies = _currenciesFor(type);
    final current = state.targetCurrency;
    _emit(
      type: type,
      targetCurrencies: currencies,
      targetCurrency: currencies.contains(current) ? current : (currencies.isEmpty ? null : currencies.first),
    );
    _scheduleQuote();
  }

  Future<void> customerSelected(Customer? customer) async {
    _emit(customer: customer, beneficiaries: const [], beneficiary: null, error: null);
    if (customer == null) return;
    _emit(beneficiariesStatus: LoadStatus.loading);
    try {
      final beneficiaries = (await _customers.beneficiaries(customer.id)).where((b) => b.active).toList();
      if (state.customer != customer) return;
      _emit(
        beneficiariesStatus: LoadStatus.success,
        beneficiaries: beneficiaries,
        beneficiary: beneficiaries.length == 1 ? beneficiaries.single : null,
      );
    } on ApiException catch (error) {
      if (state.customer != customer) return;
      _emit(beneficiariesStatus: LoadStatus.failure, error: error.message);
    }
  }

  void beneficiarySelected(Beneficiary? beneficiary) => _emit(beneficiary: beneficiary);

  /// Adds a beneficiary just created for the chosen customer, and picks it.
  void beneficiaryCreated(Beneficiary beneficiary) =>
      _emit(beneficiaries: [...state.beneficiaries, beneficiary], beneficiary: beneficiary);

  void targetCurrencyChanged(String? currency) {
    _emit(targetCurrency: currency);
    _scheduleQuote();
  }

  void amountChanged(double? amount) {
    _emit(amount: amount);
    _scheduleQuote();
  }

  void _scheduleQuote() {
    _quoteTimer?.cancel();
    final request = ++_quoteRequest;
    final amount = state.amount;
    final currency = state.targetCurrency;
    final type = state.type;
    if (amount == null || amount <= 0 || currency == null) {
      _emit(quote: null, quoteStatus: LoadStatus.success);
      return;
    }
    _emit(quote: null, quoteStatus: LoadStatus.loading);
    _quoteTimer = Timer(quoteDelay, () async {
      try {
        final quote = await _rates.quote(
          sourceCurrency: sourceCurrency,
          targetCurrency: currency,
          amount: amount,
          type: type,
        );
        if (request == _quoteRequest && !isClosed) _emit(quote: quote, quoteStatus: LoadStatus.success);
      } on ApiException catch (error) {
        if (request == _quoteRequest && !isClosed) _emit(quoteStatus: LoadStatus.failure, error: error.message);
      }
    });
  }

  Future<void> submit({String? notes}) async {
    if (!state.canSubmit) return;
    _emit(submitting: true, error: null);
    try {
      final remittance = await _remittances.register(
        NewRemittance(
          type: state.type,
          customerId: state.customer!.id,
          beneficiaryId: state.beneficiary!.id,
          amount: state.quote!.amount,
          targetCurrency: state.targetCurrency!,
          notes: notes == null || notes.trim().isEmpty ? null : notes.trim(),
        ),
        idempotencyKey: _idempotencyKey,
      );
      _emit(submitting: false, created: remittance);
    } on ApiException catch (error) {
      _emit(submitting: false, error: error.message);
    }
  }

  static const _keep = Object();

  /// Emits a copy; pass `null` explicitly to clear a nullable field.
  void _emit({
    LoadStatus? corridorsStatus,
    List<String>? targetCurrencies,
    RemittanceType? type,
    Object? customer = _keep,
    LoadStatus? beneficiariesStatus,
    List<Beneficiary>? beneficiaries,
    Object? beneficiary = _keep,
    Object? targetCurrency = _keep,
    Object? amount = _keep,
    LoadStatus? quoteStatus,
    Object? quote = _keep,
    bool? submitting,
    Object? created = _keep,
    Object? error = _keep,
  }) {
    final s = state;
    emit(
      NewRemittanceState(
        corridorsStatus: corridorsStatus ?? s.corridorsStatus,
        targetCurrencies: targetCurrencies ?? s.targetCurrencies,
        type: type ?? s.type,
        customer: customer == _keep ? s.customer : customer as Customer?,
        beneficiariesStatus: beneficiariesStatus ?? s.beneficiariesStatus,
        beneficiaries: beneficiaries ?? s.beneficiaries,
        beneficiary: beneficiary == _keep ? s.beneficiary : beneficiary as Beneficiary?,
        targetCurrency: targetCurrency == _keep ? s.targetCurrency : targetCurrency as String?,
        amount: amount == _keep ? s.amount : amount as double?,
        quoteStatus: quoteStatus ?? s.quoteStatus,
        quote: quote == _keep ? s.quote : quote as Quote?,
        submitting: submitting ?? s.submitting,
        created: created == _keep ? s.created : created as Remittance?,
        error: error == _keep ? s.error : error as String?,
      ),
    );
  }

  @override
  Future<void> close() {
    _quoteTimer?.cancel();
    return super.close();
  }
}
