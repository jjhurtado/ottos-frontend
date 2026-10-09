import 'package:equatable/equatable.dart';

import 'json.dart';

enum RemittanceType {
  delivery('DELIVERY'),
  pickup('PICKUP');

  const RemittanceType(this.code);

  final String code;

  static RemittanceType fromCode(String? code) =>
      values.firstWhere((type) => type.code == code, orElse: () => delivery);
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
    createdAt: parseDateTime(json['createdAt']),
    createdBy: json['createdBy'] as String?,
    completedAt: parseDateTime(json['completedAt']),
  );

  final String id;
  final String code;
  final RemittanceType type;
  final String status;
  final String statusName;
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
  final int postponements;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  bool get isPickup => type == RemittanceType.pickup;

  @override
  List<Object?> get props => [id, status, courierId, expectedDate, late, postponements, completedAt];
}
