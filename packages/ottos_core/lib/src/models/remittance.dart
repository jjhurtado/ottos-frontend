import 'package:equatable/equatable.dart';

import '../l10n/core_texts.dart';
import 'json.dart';

enum RemittanceType {
  delivery('DELIVERY'),
  pickup('PICKUP');

  const RemittanceType(this.code);

  final String code;

  static RemittanceType fromCode(String? code) =>
      values.firstWhere((type) => type.code == code, orElse: () => delivery);
}

/// Why a remittance was marked for sales to check (`ReviewReason`).
enum ReviewReason {
  /// Delivered while offline after it was reassigned to someone else.
  deliveredAfterReassignment('DELIVERED_AFTER_REASSIGNMENT'),

  /// Delivered offline with a PIN that did not match.
  pinMismatch('PIN_MISMATCH'),

  /// Two people say they delivered it.
  duplicateDelivery('DUPLICATE_DELIVERY'),

  /// Synced more than 7 days after it happened.
  lateSync('LATE_SYNC'),

  /// A courier's currency exchange far from the configured rate.
  unusualExchangeRate('UNUSUAL_EXCHANGE_RATE'),

  /// A reason this app does not know yet.
  other('');

  const ReviewReason(this.code);

  final String code;

  static ReviewReason fromCode(String? code) =>
      values.firstWhere((reason) => reason.code == code && reason != other, orElse: () => other);
}

/// A pending review of a remittance (`ReviewView`).
class Review extends Equatable {
  const Review({required this.reason, this.flaggedAt, this.actionId});

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    reason: ReviewReason.fromCode(json['reason'] as String?),
    flaggedAt: parseDateTime(json['flaggedAt']),
    actionId: json['actionId'] as String?,
  );

  final ReviewReason reason;
  final DateTime? flaggedAt;
  final String? actionId;

  @override
  List<Object?> get props => [reason, flaggedAt, actionId];
}

/// Why a delivery or pickup could not be done (`IncidentReason`).
enum IncidentReason {
  notHome('NOT_HOME'),
  wrongAddress('WRONG_ADDRESS'),
  unreachable('UNREACHABLE'),
  refused('REFUSED'),
  other('OTHER');

  const IncidentReason(this.code);

  final String code;

  static IncidentReason fromCode(String? code) =>
      values.firstWhere((reason) => reason.code == code, orElse: () => other);
}

/// The open incident of a remittance (`OpenIncident`): it stays until someone
/// reassigns, postpones, completes or otherwise moves the remittance.
class Incident extends Equatable {
  const Incident({required this.reason, this.note, this.reportedAt, this.reportedBy});

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
    reason: IncidentReason.fromCode(json['reason'] as String?),
    note: json['note'] as String?,
    reportedAt: parseDateTime(json['reportedAt']),
    reportedBy: json['reportedBy'] as String?,
  );

  final IncidentReason reason;
  final String? note;
  final DateTime? reportedAt;
  final String? reportedBy;

  @override
  List<Object?> get props => [reason, note, reportedAt, reportedBy];
}

/// A remittance as returned by the API (`RemittanceView`). Financial fields
/// of a pickup are null unless the user has `remittances:read-financials`.
class Remittance extends Equatable {
  const Remittance({
    required this.id,
    required this.code,
    required this.type,
    required this.status,
    required this.statusName,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.beneficiaryId,
    this.beneficiaryName,
    this.beneficiaryPhone,
    this.beneficiaryAlternatePhone,
    this.beneficiaryAddress,
    this.beneficiaryReference,
    this.municipalityCode,
    this.municipalityName,
    this.sourceCurrency,
    this.targetCurrency,
    this.amount,
    this.fee,
    this.total,
    this.rate,
    this.amountToDeliver,
    this.cashAmount,
    this.cashCurrency,
    this.pin,
    this.courierId,
    this.courierName,
    this.expectedDate,
    this.late = false,
    this.postponements = 0,
    this.notes,
    this.incident,
    this.review,
    this.createdAt,
    this.createdBy,
    this.completedAt,
  });

  factory Remittance.fromJson(Map<String, dynamic> json) => Remittance(
    id: json['id'] as String,
    code: json['code'] as String? ?? '',
    type: RemittanceType.fromCode(json['type'] as String?),
    status: json['status'] as String? ?? '',
    statusName: json['statusName'] as String? ?? json['status'] as String? ?? '',
    customerId: json['customerId'] as String?,
    customerName: json['customerName'] as String?,
    customerPhone: json['customerPhone'] as String?,
    beneficiaryId: json['beneficiaryId'] as String?,
    beneficiaryName: json['beneficiaryName'] as String?,
    beneficiaryPhone: json['beneficiaryPhone'] as String?,
    beneficiaryAlternatePhone: json['beneficiaryAlternatePhone'] as String?,
    beneficiaryAddress: json['beneficiaryAddress'] as String?,
    beneficiaryReference: json['beneficiaryReference'] as String?,
    municipalityCode: json['municipalityCode'] as String?,
    municipalityName: json['municipalityName'] as String?,
    sourceCurrency: json['sourceCurrency'] as String?,
    targetCurrency: json['targetCurrency'] as String?,
    amount: parseDecimal(json['amount']),
    fee: parseDecimal(json['fee']),
    total: parseDecimal(json['total']),
    rate: parseDecimal(json['rate']),
    amountToDeliver: parseDecimal(json['amountToDeliver']),
    cashAmount: parseDecimal(json['cashAmount']),
    cashCurrency: json['cashCurrency'] as String?,
    pin: json['pin'] as String?,
    courierId: json['courierId'] as String?,
    courierName: json['courierName'] as String?,
    expectedDate: parseDateTime(json['expectedDate']),
    late: json['late'] as bool? ?? false,
    postponements: json['postponements'] as int? ?? 0,
    notes: json['notes'] as String?,
    incident: json['incident'] == null ? null : Incident.fromJson(json['incident'] as Map<String, dynamic>),
    review: json['review'] == null ? null : Review.fromJson(json['review'] as Map<String, dynamic>),
    createdAt: parseDateTime(json['createdAt']),
    createdBy: json['createdBy'] as String?,
    completedAt: parseDateTime(json['completedAt']),
  );

  final String id;
  final String code;
  final RemittanceType type;
  final String status;

  /// The backend's name of [status]; only a fallback, see [displayStatus].
  final String statusName;

  /// [status] in Spanish, by code and type.
  String get displayStatus => CoreTexts.statusName(status, type: type, fallback: statusName);
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? beneficiaryId;
  final String? beneficiaryName;
  final String? beneficiaryPhone;
  final String? beneficiaryAlternatePhone;
  final String? beneficiaryAddress;
  final String? beneficiaryReference;
  final String? municipalityCode;
  final String? municipalityName;
  final String? sourceCurrency;
  final String? targetCurrency;
  final double? amount;
  final double? fee;
  final double? total;
  final double? rate;
  final double? amountToDeliver;

  /// Cash the courier hands over (delivery) or collects (pickup).
  final double? cashAmount;
  final String? cashCurrency;
  final String? pin;
  final String? courierId;
  final String? courierName;
  final DateTime? expectedDate;
  final bool late;

  /// Whole days past the expected date, by calendar day (hours do not count);
  /// 0 when it is due today or later, or has no date.
  int daysLate({DateTime? now}) {
    final expected = expectedDate?.toLocal();
    if (expected == null) return 0;
    final today = (now ?? DateTime.now()).toLocal();
    // UTC midnights: a daylight saving change cannot shorten a day.
    final days = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(expected.year, expected.month, expected.day)).inDays;
    return days > 0 ? days : 0;
  }

  final int postponements;
  final String? notes;

  /// The open incident, null when there is none.
  final Incident? incident;

  /// Set while sales has to check it, e.g. after an offline delivery with a wrong PIN.
  final Review? review;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  bool get isPickup => type == RemittanceType.pickup;

  @override
  List<Object?> get props => [id, status, courierId, expectedDate, late, postponements, incident, review, completedAt];
}
