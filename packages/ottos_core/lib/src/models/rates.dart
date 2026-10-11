import 'package:equatable/equatable.dart';

import 'json.dart';
import 'remittance.dart';

/// An exchange rate of a corridor for deliveries or for pickups, valid from
/// [validFrom] until the next one of the same type (`RateView`).
class ExchangeRate extends Equatable {
  const ExchangeRate({
    required this.id,
    required this.rate,
    this.validFrom,
    this.remittanceType = RemittanceType.delivery,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => ExchangeRate(
    id: json['id'] as String? ?? '',
    rate: parseDecimal(json['rate']) ?? 0,
    validFrom: parseDateTime(json['validFrom']),
    remittanceType: RemittanceType.fromCode(json['remittanceType'] as String?),
  );

  final String id;
  final double rate;
  final DateTime? validFrom;
  final RemittanceType remittanceType;

  @override
  List<Object?> get props => [id, rate, validFrom, remittanceType];
}

enum FeeType {
  /// [FeeRule.value] is a percent of the amount sent (10 = 10 %).
  percentage('PERCENTAGE'),

  /// [FeeRule.value] is a fixed amount in the source currency.
  fixed('FIXED');

  const FeeType(this.code);

  final String code;

  static FeeType fromCode(String? code) => values.firstWhere((type) => type.code == code, orElse: () => percentage);
}

/// How the fee of a corridor is calculated for deliveries or for pickups,
/// valid from [validFrom] (`FeeRuleView`).
class FeeRule extends Equatable {
  const FeeRule({
    required this.id,
    required this.type,
    required this.value,
    this.minFee,
    this.maxFee,
    this.validFrom,
    this.remittanceType = RemittanceType.delivery,
  });

  factory FeeRule.fromJson(Map<String, dynamic> json) => FeeRule(
    id: json['id'] as String? ?? '',
    type: FeeType.fromCode(json['type'] as String?),
    value: parseDecimal(json['value']) ?? 0,
    minFee: parseDecimal(json['minFee']),
    maxFee: parseDecimal(json['maxFee']),
    validFrom: parseDateTime(json['validFrom']),
    remittanceType: RemittanceType.fromCode(json['remittanceType'] as String?),
  );

  final String id;
  final FeeType type;
  final double value;

  /// Bounds of the fee, in the source currency; null when there is none.
  final double? minFee;
  final double? maxFee;
  final DateTime? validFrom;
  final RemittanceType remittanceType;

  @override
  List<Object?> get props => [id, type, value, minFee, maxFee, validFrom, remittanceType];
}

/// A new fee rule (`POST /corridors/{code}/fee-rules`).
class FeeRuleInput extends Equatable {
  const FeeRuleInput({required this.type, required this.value, this.minFee, this.maxFee});

  final FeeType type;
  final double value;
  final double? minFee;
  final double? maxFee;

  Map<String, dynamic> toJson() => {'type': type.code, 'value': value, 'minFee': minFee, 'maxFee': maxFee};

  @override
  List<Object?> get props => [type, value, minFee, maxFee];
}

/// A currency pair the business operates, e.g. USD-CUP, with the rate and
/// fee rule in force for deliveries and, separately, for pickups (`CorridorView`).
class Corridor extends Equatable {
  const Corridor({
    required this.code,
    required this.sourceCurrency,
    required this.targetCurrency,
    this.active = true,
    this.deliveryRounding,
    this.rate,
    this.feeRule,
    this.pickupRate,
    this.pickupFeeRule,
  });

  factory Corridor.fromJson(Map<String, dynamic> json) {
    final rate = json['currentRate'] as Map<String, dynamic>?;
    final feeRule = json['currentFeeRule'] as Map<String, dynamic>?;
    final pickupRate = json['currentPickupRate'] as Map<String, dynamic>?;
    final pickupFeeRule = json['currentPickupFeeRule'] as Map<String, dynamic>?;
    return Corridor(
      code: json['code'] as String,
      sourceCurrency: json['sourceCurrency'] as String? ?? '',
      targetCurrency: json['targetCurrency'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      deliveryRounding: parseDecimal(json['deliveryRounding']),
      rate: rate == null ? null : ExchangeRate.fromJson(rate),
      feeRule: feeRule == null ? null : FeeRule.fromJson(feeRule),
      pickupRate: pickupRate == null ? null : ExchangeRate.fromJson(pickupRate),
      pickupFeeRule: pickupFeeRule == null ? null : FeeRule.fromJson(pickupFeeRule),
    );
  }

  final String code;
  final String sourceCurrency;
  final String targetCurrency;
  final bool active;

  /// The amount to deliver is rounded down to a multiple of this (50 CUP; 0.01 means no rounding).
  final double? deliveryRounding;

  /// For deliveries. Null until an administrator sets one; such a corridor
  /// cannot be quoted for deliveries.
  final ExchangeRate? rate;
  final FeeRule? feeRule;

  /// For pickups, set apart from the delivery ones.
  final ExchangeRate? pickupRate;
  final FeeRule? pickupFeeRule;

  double? get currentRate => rate?.rate;

  ExchangeRate? rateFor(RemittanceType type) => type == RemittanceType.pickup ? pickupRate : rate;

  FeeRule? feeRuleFor(RemittanceType type) => type == RemittanceType.pickup ? pickupFeeRule : feeRule;

  bool get canQuote => canQuoteFor(RemittanceType.delivery);

  bool canQuoteFor(RemittanceType type) => active && rateFor(type) != null;

  /// Same-currency corridors (USD-USD) always use rate 1.
  bool get hasFixedRate => sourceCurrency == targetCurrency;

  @override
  List<Object?> get props => [code, active, rate, feeRule, pickupRate, pickupFeeRule];
}

/// What a remittance of [amount] costs and delivers today (`POST /quotes`).
class Quote extends Equatable {
  const Quote({
    required this.sourceCurrency,
    required this.targetCurrency,
    required this.amount,
    required this.fee,
    required this.total,
    required this.rate,
    required this.amountToDeliver,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    sourceCurrency: json['sourceCurrency'] as String? ?? '',
    targetCurrency: json['targetCurrency'] as String? ?? '',
    amount: parseDecimal(json['amount']) ?? 0,
    fee: parseDecimal(json['fee']) ?? 0,
    total: parseDecimal(json['total']) ?? 0,
    rate: parseDecimal(json['rate']) ?? 0,
    amountToDeliver: parseDecimal(json['amountToDeliver']) ?? 0,
  );

  final String sourceCurrency;
  final String targetCurrency;
  final double amount;
  final double fee;
  final double total;
  final double rate;
  final double amountToDeliver;

  @override
  List<Object?> get props => [sourceCurrency, targetCurrency, amount, fee, total, rate, amountToDeliver];
}

/// Business-wide settings (`GET /configuration/settings`).
class Settings extends Equatable {
  const Settings({this.minimumAmount = 0, this.minimumAmountCurrency = 'USD', this.defaultDeliveryDays = 2});

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    minimumAmount: parseDecimal(json['minimumAmount']) ?? 0,
    minimumAmountCurrency: json['minimumAmountCurrency'] as String? ?? 'USD',
    defaultDeliveryDays: json['defaultDeliveryDays'] as int? ?? 2,
  );

  /// Smallest amount a remittance can send; 0 means no minimum.
  final double minimumAmount;
  final String minimumAmountCurrency;

  /// Days from registration to a new remittance's expected date.
  final int defaultDeliveryDays;

  @override
  List<Object?> get props => [minimumAmount, minimumAmountCurrency, defaultDeliveryDays];
}
