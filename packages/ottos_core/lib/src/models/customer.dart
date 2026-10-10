import 'package:equatable/equatable.dart';

import 'json.dart';

/// A customer who sends or receives money through the business (`CustomerInfo`).
class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.documentType,
    this.documentNumber,
    this.address,
    this.notes,
    this.active = true,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    fullName: json['fullName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String?,
    documentType: json['documentType'] as String?,
    documentNumber: json['documentNumber'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
    active: json['active'] as bool? ?? true,
    createdAt: parseDateTime(json['createdAt']),
  );

  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? documentType;
  final String? documentNumber;
  final String? address;
  final String? notes;
  final bool active;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, fullName, phone, active];
}

/// Someone a customer sends money to, with the delivery address (`BeneficiaryInfo`).
class Beneficiary extends Equatable {
  const Beneficiary({
    required this.id,
    required this.fullName,
    required this.phone,
    this.alternatePhone,
    this.street,
    this.houseNumber,
    this.betweenStreets,
    this.neighborhood,
    this.municipalityCode,
    this.municipalityName,
    this.provinceName,
    this.reference,
    this.documentNumber,
    this.notes,
    this.active = true,
  });

  factory Beneficiary.fromJson(Map<String, dynamic> json) => Beneficiary(
    id: json['id'] as String,
    fullName: json['fullName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    alternatePhone: json['alternatePhone'] as String?,
    street: json['street'] as String?,
    houseNumber: json['houseNumber'] as String?,
    betweenStreets: json['betweenStreets'] as String?,
    neighborhood: json['neighborhood'] as String?,
    municipalityCode: json['municipalityCode'] as String?,
    municipalityName: json['municipalityName'] as String?,
    provinceName: json['provinceName'] as String?,
    reference: json['reference'] as String?,
    documentNumber: json['documentNumber'] as String?,
    notes: json['notes'] as String?,
    active: json['active'] as bool? ?? true,
  );

  final String id;
  final String fullName;
  final String phone;
  final String? alternatePhone;
  final String? street;
  final String? houseNumber;
  final String? betweenStreets;
  final String? neighborhood;
  final String? municipalityCode;
  final String? municipalityName;
  final String? provinceName;
  final String? reference;
  final String? documentNumber;
  final String? notes;
  final bool active;

  /// One line for lists: street and number, municipality, province.
  String get address => [
    [street, houseNumber].whereType<String>().where((part) => part.isNotEmpty).join(' #'),
    municipalityName,
    provinceName,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  @override
  List<Object?> get props => [id, fullName, phone, municipalityCode, active];
}

String? _blankToNull(String? value) => value == null || value.trim().isEmpty ? null : value.trim();

/// Editable data of a customer (`POST`/`PUT /customers`).
class CustomerInput extends Equatable {
  const CustomerInput({
    required this.fullName,
    required this.phone,
    this.email,
    this.documentType,
    this.documentNumber,
    this.address,
    this.notes,
  });

  factory CustomerInput.of(Customer customer) => CustomerInput(
    fullName: customer.fullName,
    phone: customer.phone,
    email: customer.email,
    documentType: customer.documentType,
    documentNumber: customer.documentNumber,
    address: customer.address,
    notes: customer.notes,
  );

  final String fullName;
  final String phone;
  final String? email;
  final String? documentType;
  final String? documentNumber;
  final String? address;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'fullName': fullName.trim(),
    'phone': phone.trim(),
    'email': _blankToNull(email),
    'documentType': _blankToNull(documentType),
    'documentNumber': _blankToNull(documentNumber),
    'address': _blankToNull(address),
    'notes': _blankToNull(notes),
  };

  @override
  List<Object?> get props => [fullName, phone, email, documentType, documentNumber, address, notes];
}

/// Editable data of a beneficiary (`POST /customers/{id}/beneficiaries`, `PUT /beneficiaries/{id}`).
class BeneficiaryInput extends Equatable {
  const BeneficiaryInput({
    required this.fullName,
    required this.phone,
    required this.street,
    required this.municipalityCode,
    this.alternatePhone,
    this.houseNumber,
    this.betweenStreets,
    this.neighborhood,
    this.reference,
    this.documentNumber,
    this.notes,
  });

  factory BeneficiaryInput.of(Beneficiary beneficiary) => BeneficiaryInput(
    fullName: beneficiary.fullName,
    phone: beneficiary.phone,
    street: beneficiary.street ?? '',
    municipalityCode: beneficiary.municipalityCode ?? '',
    alternatePhone: beneficiary.alternatePhone,
    houseNumber: beneficiary.houseNumber,
    betweenStreets: beneficiary.betweenStreets,
    neighborhood: beneficiary.neighborhood,
    reference: beneficiary.reference,
    documentNumber: beneficiary.documentNumber,
    notes: beneficiary.notes,
  );

  final String fullName;
  final String phone;
  final String street;
  final String municipalityCode;
  final String? alternatePhone;
  final String? houseNumber;
  final String? betweenStreets;
  final String? neighborhood;
  final String? reference;
  final String? documentNumber;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'fullName': fullName.trim(),
    'phone': phone.trim(),
    'street': street.trim(),
    'municipalityCode': municipalityCode,
    'alternatePhone': _blankToNull(alternatePhone),
    'houseNumber': _blankToNull(houseNumber),
    'betweenStreets': _blankToNull(betweenStreets),
    'neighborhood': _blankToNull(neighborhood),
    'reference': _blankToNull(reference),
    'documentNumber': _blankToNull(documentNumber),
    'notes': _blankToNull(notes),
  };

  @override
  List<Object?> get props => [
    fullName,
    phone,
    street,
    municipalityCode,
    alternatePhone,
    houseNumber,
    betweenStreets,
    neighborhood,
    reference,
    documentNumber,
    notes,
  ];
}

/// A customer's remittance history in numbers (`GET /customers/{id}/stats`).
/// Delivery amounts are in USD.
class CustomerStats extends Equatable {
  const CustomerStats({
    this.remittances = 0,
    this.open = 0,
    this.late = 0,
    this.deliveries = 0,
    this.amountSent = 0,
    this.charged = 0,
    this.pickups = 0,
    this.amountCollected = 0,
    this.firstAt,
    this.lastAt,
  });

  factory CustomerStats.fromJson(Map<String, dynamic> json) {
    final deliveries = json['deliveries'] as Map<String, dynamic>? ?? const {};
    final pickups = json['pickups'] as Map<String, dynamic>? ?? const {};
    return CustomerStats(
      remittances: json['remittances'] as int? ?? 0,
      open: json['open'] as int? ?? 0,
      late: json['late'] as int? ?? 0,
      deliveries: deliveries['count'] as int? ?? 0,
      amountSent: parseDecimal(deliveries['amountSent']) ?? 0,
      charged: parseDecimal(deliveries['charged']) ?? 0,
      pickups: pickups['count'] as int? ?? 0,
      amountCollected: parseDecimal(pickups['amountCollected']) ?? 0,
      firstAt: parseDateTime(json['firstAt']),
      lastAt: parseDateTime(json['lastAt']),
    );
  }

  final int remittances;
  final int open;
  final int late;
  final int deliveries;
  final double amountSent;
  final double charged;
  final int pickups;
  final double amountCollected;
  final DateTime? firstAt;
  final DateTime? lastAt;

  @override
  List<Object?> get props => [remittances, open, late, deliveries, amountSent, charged, pickups, amountCollected];
}
