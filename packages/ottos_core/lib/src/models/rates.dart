import 'package:equatable/equatable.dart';

import 'json.dart';

/// A currency pair the business operates, e.g. USD-CUP (`CorridorView`).
class Corridor extends Equatable {
  const Corridor({
    required this.code,
    required this.sourceCurrency,
    required this.targetCurrency,
    this.active = true,
    this.currentRate,
  });

  factory Corridor.fromJson(Map<String, dynamic> json) => Corridor(
    code: json['code'] as String,
    sourceCurrency: json['sourceCurrency'] as String? ?? '',
    targetCurrency: json['targetCurrency'] as String? ?? '',
    active: json['active'] as bool? ?? true,
    currentRate: parseDecimal((json['currentRate'] as Map<String, dynamic>?)?['rate']),
  );

  final String code;
  final String sourceCurrency;
  final String targetCurrency;
  final bool active;

  /// Null until an administrator sets a rate; such a corridor cannot be quoted.
  final double? currentRate;

  bool get canQuote => active && currentRate != null;

  @override
  List<Object?> get props => [code, active, currentRate];
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
