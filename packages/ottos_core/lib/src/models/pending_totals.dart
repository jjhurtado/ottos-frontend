import 'package:equatable/equatable.dart';

import 'json.dart';
import 'remittance.dart';

/// Cash still to change hands in one currency (`PendingAmount`), and how many
/// remittances add up to it (REQ-021).
class PendingAmount extends Equatable {
  const PendingAmount({required this.currency, required this.remittances, required this.amount});

  factory PendingAmount.fromJson(Map<String, dynamic> json) => PendingAmount(
    currency: json['currency'] as String? ?? '',
    remittances: json['remittances'] as int? ?? 0,
    amount: parseDecimal(json['amount']) ?? 0,
  );

  final String currency;
  final int remittances;
  final double amount;

  @override
  List<Object?> get props => [currency, remittances, amount];
}

/// Money pending to deliver and to collect, one entry per currency, sorted by
/// currency (`PageTotals`). Currencies are never added together (BR-2).
class PendingTotals extends Equatable {
  const PendingTotals({this.toDeliver = const [], this.toCollect = const []});

  factory PendingTotals.fromJson(Map<String, dynamic>? json) =>
      PendingTotals(toDeliver: _amounts(json?['toDeliver']), toCollect: _amounts(json?['toCollect']));

  /// Summed on the phone from [remittances] (the courier's, BR-7): the cash of
  /// each open one, voided and completed ones left out (BR-1, BR-2).
  factory PendingTotals.sum(Iterable<Remittance> remittances) {
    final deliver = <String, PendingAmount>{};
    final collect = <String, PendingAmount>{};
    for (final remittance in remittances) {
      final amount = remittance.cashAmount;
      final currency = remittance.cashCurrency;
      if (amount == null || currency == null || remittance.isVoided || remittance.isCompleted) continue;
      final into = remittance.isPickup ? collect : deliver;
      final before = into[currency];
      into[currency] = PendingAmount(
        currency: currency,
        remittances: (before?.remittances ?? 0) + 1,
        amount: (before?.amount ?? 0) + amount,
      );
    }
    List<PendingAmount> sorted(Map<String, PendingAmount> amounts) =>
        amounts.values.toList()..sort((a, b) => a.currency.compareTo(b.currency));
    return PendingTotals(toDeliver: sorted(deliver), toCollect: sorted(collect));
  }

  final List<PendingAmount> toDeliver;
  final List<PendingAmount> toCollect;

  static List<PendingAmount> _amounts(Object? json) => [
    for (final item in json as List? ?? const []) PendingAmount.fromJson(item as Map<String, dynamic>),
  ];

  @override
  List<Object?> get props => [toDeliver, toCollect];
}
