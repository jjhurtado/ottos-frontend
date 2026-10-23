import 'package:equatable/equatable.dart';

import 'json.dart';
import 'remittance.dart';

/// Who voided a remittance of the report, when and why (the reason as typed).
class ReportVoid extends Equatable {
  const ReportVoid({this.at, this.byName, this.reason = ''});

  factory ReportVoid.fromJson(Map<String, dynamic> json) => ReportVoid(
    at: parseDateTime(json['at']),
    byName: json['byName'] as String?,
    reason: json['reason'] as String? ?? '',
  );

  final DateTime? at;
  final String? byName;
  final String reason;

  @override
  List<Object?> get props => [at, byName, reason];
}

/// One remittance of the month's detail (`GET /reports/monthly/remittances`).
/// No personal data: it is told apart by its [code]. Amounts in the business
/// currency except [amountToDeliver], in [targetCurrency].
class ReportRemittance extends Equatable {
  const ReportRemittance({
    required this.id,
    required this.code,
    this.type = RemittanceType.delivery,
    this.status = '',
    this.statusName = '',
    this.createdAt,
    this.expectedDate,
    this.completedAt,
    this.completedFromBusiness = false,
    this.municipalityCode,
    this.municipalityName,
    this.courierName,
    this.sourceCurrency = 'USD',
    this.targetCurrency = '',
    this.amount = 0,
    this.fee = 0,
    this.total = 0,
    this.rate = 0,
    this.amountToDeliver = 0,
    this.collected = 0,
    this.deliveredCurrency,
    this.onTheHouse = false,
    this.waivedFee,
    this.withIncident = false,
    this.voided,
  });

  factory ReportRemittance.fromJson(Map<String, dynamic> json) => ReportRemittance(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    type: RemittanceType.fromCode(json['type'] as String?),
    status: json['status'] as String? ?? '',
    statusName: json['statusName'] as String? ?? '',
    createdAt: parseDateTime(json['createdAt']),
    expectedDate: parseDateTime(json['expectedDate']),
    completedAt: parseDateTime(json['completedAt']),
    completedFromBusiness: json['completedFromBusiness'] as bool? ?? false,
    municipalityCode: json['municipalityCode'] as String?,
    municipalityName: json['municipalityName'] as String?,
    courierName: json['courierName'] as String?,
    sourceCurrency: json['sourceCurrency'] as String? ?? 'USD',
    targetCurrency: json['targetCurrency'] as String? ?? '',
    amount: parseDecimal(json['amount']) ?? 0,
    fee: parseDecimal(json['fee']) ?? 0,
    total: parseDecimal(json['total']) ?? 0,
    rate: parseDecimal(json['rate']) ?? 0,
    amountToDeliver: parseDecimal(json['amountToDeliver']) ?? 0,
    collected: parseDecimal(json['collected']) ?? 0,
    deliveredCurrency: parseDecimal(json['deliveredCurrency']),
    onTheHouse: json['onTheHouse'] as bool? ?? false,
    waivedFee: parseDecimal(json['waivedFee']),
    withIncident: json['withIncident'] as bool? ?? false,
    voided: switch (json['voided']) {
      final Map<String, dynamic> voided => ReportVoid.fromJson(voided),
      _ => null,
    },
  );

  final String id;
  final String code;
  final RemittanceType type;
  final String status;
  final String statusName;

  /// Instants in UTC; shown in Cuba time.
  final DateTime? createdAt;
  final DateTime? expectedDate;
  final DateTime? completedAt;

  /// Delivered or collected by the business, without a courier.
  final bool completedFromBusiness;
  final String? municipalityCode;
  final String? municipalityName;

  /// The courier assigned now (or who completed it); null without one.
  final String? courierName;
  final String sourceCurrency;
  final String targetCurrency;
  final double amount;
  final double fee;
  final double total;

  /// Informative only in a pickup.
  final double rate;
  final double amountToDeliver;

  /// What counts as charged: amount + fee in a delivery, what was collected in a pickup.
  final double collected;

  /// What was delivered in the business currency; null in a pickup.
  final double? deliveredCurrency;
  final bool onTheHouse;

  /// The fee not charged, only on the house.
  final double? waivedFee;

  /// With an incident open now.
  final bool withIncident;

  /// Null unless voided: then it is listed but counts in no sum.
  final ReportVoid? voided;

  bool get isVoided => voided != null;
  bool get isPickup => type == RemittanceType.pickup;
  bool get isCompleted => status == 'DELIVERED';

  @override
  List<Object?> get props => [id, code, status, voided, withIncident, courierName, amount, fee];
}

/// Every remittance registered in a month, voided ones included and marked
/// (`GET /reports/monthly/remittances`), in registration order.
class MonthlyReportDetail extends Equatable {
  const MonthlyReportDetail({
    required this.month,
    this.from,
    this.to,
    this.generatedAt,
    this.businessCurrency = 'USD',
    this.lines = 0,
    this.voided = 0,
    this.total = 0,
    this.deliveries = 0,
    this.pickups = 0,
    this.completed = 0,
    this.open = 0,
    this.withIncident = 0,
    this.remittances = const [],
  });

  factory MonthlyReportDetail.fromJson(Map<String, dynamic> json) {
    final counts = (json['counts'] as Map<String, dynamic>?) ?? const {};
    return MonthlyReportDetail(
      month: json['month'] as String? ?? '',
      from: parseDateTime(json['from']),
      to: parseDateTime(json['to']),
      generatedAt: parseDateTime(json['generatedAt']),
      businessCurrency: json['businessCurrency'] as String? ?? 'USD',
      lines: counts['lines'] as int? ?? 0,
      voided: counts['voided'] as int? ?? 0,
      total: counts['total'] as int? ?? 0,
      deliveries: counts['delivery'] as int? ?? 0,
      pickups: counts['pickup'] as int? ?? 0,
      completed: counts['completed'] as int? ?? 0,
      open: counts['open'] as int? ?? 0,
      withIncident: counts['withIncident'] as int? ?? 0,
      remittances: [
        for (final item in json['remittances'] as List? ?? const [])
          ReportRemittance.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  /// `YYYY-MM`.
  final String month;
  final DateTime? from;
  final DateTime? to;
  final DateTime? generatedAt;
  final String businessCurrency;

  /// Rows of [remittances], voided ones included.
  final int lines;
  final int voided;

  /// The rest count the ones not voided, as the monthly report.
  final int total;
  final int deliveries;
  final int pickups;
  final int completed;
  final int open;
  final int withIncident;
  final List<ReportRemittance> remittances;

  @override
  List<Object?> get props => [month, generatedAt, lines, remittances];
}
