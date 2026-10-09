import 'package:equatable/equatable.dart';

import 'json.dart';

class Balance extends Equatable {
  const Balance({required this.currency, required this.amount});

  factory Balance.fromJson(Map<String, dynamic> json) =>
      Balance(currency: json['currency'] as String? ?? '', amount: parseDecimal(json['amount']) ?? 0);

  final String currency;
  final double amount;

  @override
  List<Object?> get props => [currency, amount];
}

enum CashMovementType {
  remittancePayment('REMITTANCE_PAYMENT'),
  courierFunding('COURIER_FUNDING'),
  deliveryPayout('DELIVERY_PAYOUT'),
  pickupCollection('PICKUP_COLLECTION'),
  courierReturn('COURIER_RETURN'),
  courierSurplus('COURIER_SURPLUS'),
  remittanceRefund('REMITTANCE_REFUND'),
  businessDeposit('BUSINESS_DEPOSIT'),
  businessWithdrawal('BUSINESS_WITHDRAWAL'),
  unknown('');

  const CashMovementType(this.code);

  final String code;

  static CashMovementType fromCode(String? code) =>
      values.firstWhere((type) => type.code == code, orElse: () => unknown);
}

/// A ledger movement (`MovementView`). [signedAmount] is positive when money
/// enters the account being looked at.
class CashMovement extends Equatable {
  const CashMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.signedAmount,
    required this.currency,
    this.remittanceId,
    this.note,
    this.occurredAt,
  });

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
    id: json['id'] as String,
    type: CashMovementType.fromCode(json['type'] as String?),
    amount: parseDecimal(json['amount']) ?? 0,
    signedAmount: parseDecimal(json['signedAmount']) ?? parseDecimal(json['amount']) ?? 0,
    currency: json['currency'] as String? ?? '',
    remittanceId: json['remittanceId'] as String?,
    note: json['note'] as String?,
    occurredAt: parseDateTime(json['occurredAt']),
  );

  final String id;
  final CashMovementType type;
  final double amount;
  final double signedAmount;
  final String currency;
  final String? remittanceId;
  final String? note;
  final DateTime? occurredAt;

  @override
  List<Object?> get props => [id];
}

/// Cash a courier holds, per currency (`CourierCash`).
class CourierCash extends Equatable {
  const CourierCash({required this.courierId, required this.name, required this.balances, required this.negative});

  factory CourierCash.fromJson(Map<String, dynamic> json) => CourierCash(
    courierId: json['courierId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    balances: (json['balances'] as List? ?? const [])
        .map((balance) => Balance.fromJson(balance as Map<String, dynamic>))
        .toList(),
    negative: json['negative'] as bool? ?? false,
  );

  final String courierId;
  final String name;
  final List<Balance> balances;

  /// True when the courier owes the business in some currency.
  final bool negative;

  @override
  List<Object?> get props => [courierId, balances, negative];
}

/// A courier's balances and movements (`CourierStatement`).
class CourierStatement {
  const CourierStatement({required this.cash, required this.movements});

  factory CourierStatement.fromJson(Map<String, dynamic> json) => CourierStatement(
    cash: CourierCash.fromJson(json['cash'] as Map<String, dynamic>? ?? const {}),
    movements: (json['movements'] as List? ?? const [])
        .map((movement) => CashMovement.fromJson(movement as Map<String, dynamic>))
        .toList(),
  );

  final CourierCash cash;
  final List<CashMovement> movements;
}
