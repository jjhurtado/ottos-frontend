import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_exception.dart';
import '../customers/customer_repository.dart';
import '../l10n/core_texts.dart';
import '../models/courier.dart';
import '../models/customer.dart';
import '../models/rates.dart';
import '../models/remittance.dart';
import '../rates/rate_repository.dart';
import 'remittance_repository.dart';

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
    this.couriers = const [],
    this.courier,
    this.pickupRate,
    this.pickupFee,
    this.onTheHouse = false,
    this.onTheHouseReason = '',
  });

  /// Longest reason the backend takes.
  static const onTheHouseReasonMaxLength = 500;

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

  /// Who it can be assigned to on registering; empty when the user cannot assign.
  final List<Courier> couriers;

  /// Assigned right after registering it; optional.
  final Courier? courier;

  /// The rate typed for this pickup; null keeps the configured one.
  final double? pickupRate;

  /// The fee typed for this pickup (may be 0); null applies the configured rule.
  final double? pickupFee;

  /// A delivery on the house: no fee. Only deliveries, and only for who has
  /// `remittances:on-the-house`; the page offers it accordingly.
  final bool onTheHouse;

  /// Why it goes on the house; required with [onTheHouse].
  final String onTheHouseReason;

  /// The reason is missing or too long while [onTheHouse] is on.
  bool get onTheHouseReasonMissing => onTheHouse && onTheHouseReason.trim().isEmpty;

  bool get onTheHouseReasonTooLong => onTheHouseReason.trim().length > onTheHouseReasonMaxLength;

  bool get canSubmit =>
      customer != null &&
      beneficiary != null &&
      targetCurrency != null &&
      quote != null &&
      !submitting &&
      // Never register on the house with a quote that still charges a fee
      // (e.g. a backend that does not know the field).
      (!onTheHouse || (quote!.onTheHouse && !onTheHouseReasonMissing && !onTheHouseReasonTooLong));

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
    couriers,
    courier,
    pickupRate,
    pickupFee,
    onTheHouse,
    onTheHouseReason,
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

  /// Loads the currencies and, with [customerId], starts with that customer
  /// chosen. With [canAssign] it also offers the couriers to assign it to.
  Future<void> load({String? customerId, bool canAssign = false}) async {
    if (canAssign) unawaited(_loadCouriers());
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

  Future<void> _loadCouriers() async {
    try {
      final couriers = await _remittances.couriers();
      if (!isClosed) _emit(couriers: couriers);
    } on ApiException {
      // Without the list the remittance is still registered, just not assigned.
    }
  }

  void courierSelected(Courier? courier) => _emit(courier: courier);

  Future<List<Customer>> searchCustomers(String query) => _customers.search(query);

  /// Changes the rate and fee that apply, so the quote is asked again.
  void typeChanged(RemittanceType type) {
    final currencies = _currenciesFor(type);
    final current = state.targetCurrency;
    _emit(
      type: type,
      pickupRate: null,
      pickupFee: null,
      // Only deliveries go on the house.
      onTheHouse: type == RemittanceType.delivery && state.onTheHouse,
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

  /// Any beneficiary, linked to the customer or not: registering the
  /// remittance links them.
  Future<List<Beneficiary>> searchBeneficiaries(String query) async =>
      (await _customers.searchBeneficiaries(query)).where((beneficiary) => beneficiary.active).toList();

  /// Picks a beneficiary just created or found, adding it to the list if it
  /// was not there.
  void beneficiaryCreated(Beneficiary beneficiary) {
    final known = state.beneficiaries.where((item) => item.id == beneficiary.id).firstOrNull;
    if (known != null) {
      _emit(beneficiary: known);
    } else {
      _emit(beneficiaries: [...state.beneficiaries, beneficiary], beneficiary: beneficiary);
    }
  }

  void targetCurrencyChanged(String? currency) {
    // Another currency has another configured rate.
    _emit(targetCurrency: currency, pickupRate: null);
    _scheduleQuote();
  }

  /// The configured pickup rate for the chosen currency, to prefill the field.
  double? get configuredPickupRate {
    final currency = state.targetCurrency;
    return _corridors
        .where((corridor) => corridor.sourceCurrency == sourceCurrency && corridor.targetCurrency == currency)
        .firstOrNull
        ?.pickupRate
        ?.rate;
  }

  /// A pickup's own rate; the configured one (or none) clears it.
  void pickupRateChanged(double? rate) {
    final configured = configuredPickupRate;
    final own = rate == null || rate <= 0 || rate == configured ? null : rate;
    if (own == state.pickupRate) return;
    _emit(pickupRate: own);
    _scheduleQuote();
  }

  /// A pickup's own fee; empty (null) or negative goes back to the configured rule.
  void pickupFeeChanged(double? fee) {
    final own = fee == null || fee < 0 ? null : fee;
    if (own == state.pickupFee) return;
    _emit(pickupFee: own);
    _scheduleQuote();
  }

  /// Marks or unmarks the delivery as on the house; the quote is asked again
  /// so the summary shows it without a fee.
  void onTheHouseChanged(bool onTheHouse) {
    final value = onTheHouse && state.type == RemittanceType.delivery;
    if (value == state.onTheHouse) return;
    _emit(onTheHouse: value, error: null);
    _scheduleQuote();
  }

  void onTheHouseReasonChanged(String reason) => _emit(onTheHouseReason: reason);

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
    final onTheHouse = type == RemittanceType.delivery && state.onTheHouse;
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
          rate: type == RemittanceType.pickup ? state.pickupRate : null,
          fee: type == RemittanceType.pickup ? state.pickupFee : null,
          onTheHouse: onTheHouse,
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
          rate: state.type == RemittanceType.pickup ? state.pickupRate : null,
          fee: state.type == RemittanceType.pickup ? state.pickupFee : null,
          notes: notes == null || notes.trim().isEmpty ? null : notes.trim(),
          onTheHouse: state.onTheHouse,
          onTheHouseReason: state.onTheHouse ? state.onTheHouseReason.trim() : null,
        ),
        idempotencyKey: _idempotencyKey,
      );
      final courier = state.courier;
      if (courier == null) {
        _emit(submitting: false, created: remittance);
        return;
      }
      try {
        _emit(submitting: false, created: await _remittances.assign(remittance.id, courierId: courier.id));
      } on ApiException catch (error) {
        // Registered all the same: say so, and open it so it can be assigned from there.
        _emit(submitting: false, created: remittance, error: CoreTexts.registeredNotAssigned(error.message));
      }
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
    List<Courier>? couriers,
    Object? courier = _keep,
    Object? pickupRate = _keep,
    Object? pickupFee = _keep,
    bool? onTheHouse,
    String? onTheHouseReason,
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
        couriers: couriers ?? s.couriers,
        courier: courier == _keep ? s.courier : courier as Courier?,
        pickupRate: pickupRate == _keep ? s.pickupRate : pickupRate as double?,
        pickupFee: pickupFee == _keep ? s.pickupFee : pickupFee as double?,
        onTheHouse: onTheHouse ?? s.onTheHouse,
        onTheHouseReason: onTheHouseReason ?? s.onTheHouseReason,
      ),
    );
  }

  @override
  Future<void> close() {
    _quoteTimer?.cancel();
    return super.close();
  }
}
