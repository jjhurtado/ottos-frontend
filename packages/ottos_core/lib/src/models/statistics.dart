import 'package:equatable/equatable.dart';

import 'json.dart';
import 'monthly_report.dart';

/// The sales figures of a period or of one of its groups, voided remittances
/// aside, in the business currency (`GET /reports/statistics`).
class SalesFigures extends Equatable {
  const SalesFigures({
    this.remittances = 0,
    this.deliveries = 0,
    this.pickups = 0,
    this.deliveryAmount = 0,
    this.averageAmount = 0,
    this.collected = 0,
    this.fees = 0,
    this.deliveredCurrency = 0,
    this.pickupCollected = 0,
    this.onTheHouse = const ReportOnTheHouse(),
  });

  factory SalesFigures.fromJson(Map<String, dynamic> json) => SalesFigures(
    remittances: json['remittances'] as int? ?? 0,
    deliveries: json['deliveries'] as int? ?? 0,
    pickups: json['pickups'] as int? ?? 0,
    deliveryAmount: parseDecimal(json['deliveryAmount']) ?? 0,
    averageAmount: parseDecimal(json['averageAmount']) ?? 0,
    collected: parseDecimal(json['collected']) ?? 0,
    fees: parseDecimal(json['fees']) ?? 0,
    deliveredCurrency: parseDecimal(json['deliveredCurrency']) ?? 0,
    pickupCollected: parseDecimal(json['pickupCollected']) ?? 0,
    onTheHouse: switch (json['onTheHouse']) {
      final Map<String, dynamic> block => ReportOnTheHouse.fromJson(block),
      _ => const ReportOnTheHouse(),
    },
  );

  final int remittances;
  final int deliveries;
  final int pickups;

  /// What the deliveries sent.
  final double deliveryAmount;

  /// [deliveryAmount] ÷ [deliveries]; 0 without deliveries.
  final double averageAmount;

  /// Charged for the deliveries: amount + fee.
  final double collected;

  /// Fees of deliveries and pickups: the earnings.
  final double fees;
  final double deliveredCurrency;

  /// What the couriers collected in the pickups.
  final double pickupCollected;
  final ReportOnTheHouse onTheHouse;

  /// What a pickup collects on average; 0 without pickups.
  double get averagePickup => pickups == 0 ? 0 : pickupCollected / pickups;

  @override
  List<Object?> get props => [
    remittances,
    deliveries,
    pickups,
    deliveryAmount,
    averageAmount,
    collected,
    fees,
    deliveredCurrency,
    pickupCollected,
    onTheHouse,
  ];
}

/// The days of the week as the backend names them, Monday first.
enum DayOfWeek {
  monday('MONDAY'),
  tuesday('TUESDAY'),
  wednesday('WEDNESDAY'),
  thursday('THURSDAY'),
  friday('FRIDAY'),
  saturday('SATURDAY'),
  sunday('SUNDAY');

  const DayOfWeek(this.code);

  final String code;

  static DayOfWeek? fromCode(String? code) => values.where((day) => day.code == code).firstOrNull;
}

/// A week, month, day of the week or municipality with its figures.
class StatisticsGroup extends Equatable {
  const StatisticsGroup({
    required this.key,
    this.name,
    this.from,
    this.to,
    this.partial = false,
    this.figures = const SalesFigures(),
  });

  /// [keyField] names the group's key: `week`, `month`, `dayOfWeek` or `municipalityCode`.
  factory StatisticsGroup.fromJson(Map<String, dynamic> json, String keyField) => StatisticsGroup(
    key: json[keyField] as String? ?? '',
    name: json['municipalityName'] as String?,
    from: parseDateTime(json['from']),
    to: parseDateTime(json['to']),
    partial: json['partial'] as bool? ?? false,
    figures: SalesFigures.fromJson(json),
  );

  /// `2026-W40`, `2026-10`, `MONDAY` or a municipality code.
  final String key;

  /// The municipality's name; null in the other groups.
  final String? name;

  /// The days of a week or month inside the period (dates, Cuba time).
  final DateTime? from;
  final DateTime? to;

  /// Cut by the period: not the whole week or month.
  final bool partial;
  final SalesFigures figures;

  @override
  List<Object?> get props => [key, name, from, to, partial, figures];
}

/// Sales statistics of a period (`GET /reports/statistics`): registered
/// remittances, voided ones aside, both days included, Cuba time.
class Statistics extends Equatable {
  const Statistics({
    required this.from,
    required this.to,
    this.generatedAt,
    this.businessCurrency = 'USD',
    this.totals = const SalesFigures(),
    this.byWeek = const [],
    this.byMonth = const [],
    this.byDayOfWeek = const [],
    this.byMunicipality = const [],
  });

  factory Statistics.fromJson(Map<String, dynamic> json) {
    List<StatisticsGroup> groups(String field, String keyField) => [
      for (final item in json[field] as List? ?? const [])
        StatisticsGroup.fromJson(item as Map<String, dynamic>, keyField),
    ];
    return Statistics(
      from: parseDateTime(json['from']) ?? DateTime(2000),
      to: parseDateTime(json['to']) ?? DateTime(2000),
      generatedAt: parseDateTime(json['generatedAt']),
      businessCurrency: json['businessCurrency'] as String? ?? 'USD',
      totals: switch (json['totals']) {
        final Map<String, dynamic> totals => SalesFigures.fromJson(totals),
        _ => const SalesFigures(),
      },
      byWeek: groups('byWeek', 'week'),
      byMonth: groups('byMonth', 'month'),
      byDayOfWeek: groups('byDayOfWeek', 'dayOfWeek'),
      byMunicipality: groups('byMunicipality', 'municipalityCode'),
    );
  }

  final DateTime from;
  final DateTime to;
  final DateTime? generatedAt;
  final String businessCurrency;
  final SalesFigures totals;

  /// Every ISO week of the period, also without sales; the first and last cut to it.
  final List<StatisticsGroup> byWeek;

  /// Every month of the period, cut the same way.
  final List<StatisticsGroup> byMonth;

  /// Always seven, Monday first.
  final List<StatisticsGroup> byDayOfWeek;

  /// Only municipalities with remittances, most first.
  final List<StatisticsGroup> byMunicipality;

  /// Below this many remittances averages and comparisons say little.
  static const fewDataThreshold = 10;

  bool get hasFewData => totals.remittances < fewDataThreshold;

  @override
  List<Object?> get props => [from, to, generatedAt, totals, byWeek, byMonth, byDayOfWeek, byMunicipality];
}
