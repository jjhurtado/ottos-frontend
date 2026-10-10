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
