import 'package:equatable/equatable.dart';

import 'json.dart';
import 'remittance.dart';

/// An amount in a currency.
class Money extends Equatable {
  const Money({required this.currency, required this.amount});

  factory Money.fromJson(Map<String, dynamic> json) =>
      Money(currency: json['currency'] as String? ?? '', amount: parseDecimal(json['amount']) ?? 0);

  final String currency;
  final double amount;

  @override
  List<Object?> get props => [currency, amount];
}

/// One delivery currency in a month: what was sent, charged and handed over.
class ReportCurrencyLine extends Equatable {
  const ReportCurrencyLine({
    required this.currency,
    required this.remittances,
    required this.sent,
    required this.fees,
    required this.collected,
    required this.delivered,
    required this.deliveredUsd,
  });

  factory ReportCurrencyLine.fromJson(Map<String, dynamic> json) => ReportCurrencyLine(
    currency: json['currency'] as String? ?? '',
    remittances: json['remittances'] as int? ?? 0,
    sent: parseDecimal(json['sent']) ?? 0,
    fees: parseDecimal(json['fees']) ?? 0,
    collected: parseDecimal(json['collected']) ?? 0,
    delivered: parseDecimal(json['delivered']) ?? 0,
    deliveredUsd: parseDecimal(json['deliveredUsd']) ?? 0,
  );

  final String currency;
  final int remittances;

  /// In USD, as every amount but [delivered], which is in [currency].
  final double sent;
  final double fees;
  final double collected;
  final double delivered;
  final double deliveredUsd;

  @override
  List<Object?> get props => [currency, remittances, sent, fees, collected, delivered, deliveredUsd];
}

/// Deliveries or pickups in a month.
class ReportTypeLine extends Equatable {
  const ReportTypeLine({required this.type, required this.remittances, required this.collected, required this.fees});

  factory ReportTypeLine.fromJson(Map<String, dynamic> json) => ReportTypeLine(
    type: RemittanceType.fromCode(json['type'] as String?),
    remittances: json['remittances'] as int? ?? 0,
    collected: parseDecimal(json['collected']) ?? 0,
    fees: parseDecimal(json['fees']) ?? 0,
  );

  final RemittanceType type;
  final int remittances;
  final double collected;
  final double fees;

  @override
  List<Object?> get props => [type, remittances, collected, fees];
}

/// The month's sales (`GET /reports/monthly`): remittances counted by their
/// registration date, amounts in USD unless they say otherwise.
class MonthlyReport extends Equatable {
  const MonthlyReport({
    required this.month,
    this.from,
    this.to,
    this.generatedAt,
    this.remittances = 0,
    this.deliveries = 0,
    this.pickups = 0,
    this.completed = 0,
    this.open = 0,
    this.withIncident = 0,
    this.collected = 0,
    this.fees = 0,
    this.deliveredUsd = 0,
    this.difference = 0,
    this.roundingMargin = 0,
    this.pickupsCollected = 0,
    this.pickupsFees = 0,
    this.delivered = const [],
    this.byCurrency = const [],
    this.byType = const [],
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    final counts = (json['remittances'] as Map<String, dynamic>?) ?? const {};
    final pickups = (json['pickups'] as Map<String, dynamic>?) ?? const {};
    return MonthlyReport(
      month: json['month'] as String? ?? '',
      from: parseDateTime(json['from']),
      to: parseDateTime(json['to']),
      generatedAt: parseDateTime(json['generatedAt']),
      remittances: counts['total'] as int? ?? 0,
      deliveries: counts['delivery'] as int? ?? 0,
      pickups: counts['pickup'] as int? ?? 0,
      completed: counts['completed'] as int? ?? 0,
      open: counts['open'] as int? ?? 0,
      withIncident: counts['withIncident'] as int? ?? 0,
      collected: parseDecimal(json['collected']) ?? 0,
      fees: parseDecimal(json['fees']) ?? 0,
      deliveredUsd: parseDecimal(json['deliveredUsd']) ?? 0,
      difference: parseDecimal(json['difference']) ?? 0,
      roundingMargin: parseDecimal(json['roundingMargin']) ?? 0,
      pickupsCollected: parseDecimal(pickups['collected']) ?? 0,
      pickupsFees: parseDecimal(pickups['fees']) ?? 0,
      delivered: [
        for (final item in json['delivered'] as List? ?? const []) Money.fromJson(item as Map<String, dynamic>),
      ],
      byCurrency: [
        for (final item in json['byCurrency'] as List? ?? const [])
          ReportCurrencyLine.fromJson(item as Map<String, dynamic>),
      ],
      byType: [
        for (final item in json['byType'] as List? ?? const []) ReportTypeLine.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  /// `YYYY-MM`.
  final String month;
  final DateTime? from;
  final DateTime? to;
  final DateTime? generatedAt;

  final int remittances;
  final int deliveries;
  final int pickups;

  /// How the month's remittances stood when the report was made.
  final int completed;
  final int open;
  final int withIncident;

  /// Charged to senders for the deliveries: amount plus fee.
  final double collected;

  /// The earnings: fees of deliveries and pickups.
  final double fees;

  /// What the deliveries hand over, in USD at each remittance's rate.
  final double deliveredUsd;

  /// [collected] − [deliveredUsd], deliveries only.
  final double difference;

  /// What [difference] has beyond the deliveries' fees: rounding down what is
  /// delivered.
  final double roundingMargin;

  /// Pickups hand nothing over: what the couriers collected and their fees.
  final double pickupsCollected;
  final double pickupsFees;

  /// The deliveries' fees, the part of [fees] inside [difference].
  double get deliveryFees => fees - pickupsFees;

  /// What the deliveries hand over, in their currencies.
  final List<Money> delivered;
  final List<ReportCurrencyLine> byCurrency;
  final List<ReportTypeLine> byType;

  @override
  List<Object?> get props => [month, generatedAt, remittances, collected, fees, deliveredUsd, difference];
}
