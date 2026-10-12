import 'package:equatable/equatable.dart';

/// A beneficiary to import; [municipality] is a code or a name.
class ImportBeneficiary extends Equatable {
  const ImportBeneficiary({
    required this.fullName,
    required this.phone,
    required this.street,
    required this.municipality,
    this.ref,
    this.alternatePhone,
    this.houseNumber,
    this.betweenStreets,
    this.neighborhood,
    this.reference,
    this.documentNumber,
    this.notes,
  });

  final String? ref;
  final String fullName;
  final String phone;
  final String? alternatePhone;
  final String street;
  final String? houseNumber;
  final String? betweenStreets;
  final String? neighborhood;
  final String municipality;
  final String? reference;
  final String? documentNumber;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'ref': ref,
    'fullName': fullName,
    'phone': phone,
    'alternatePhone': alternatePhone,
    'street': street,
    'houseNumber': houseNumber,
    'betweenStreets': betweenStreets,
    'neighborhood': neighborhood,
    'municipality': municipality,
    'reference': reference,
    'documentNumber': documentNumber,
    'notes': notes,
  };

  @override
  List<Object?> get props => [ref, fullName, phone, street, municipality];
}

/// A customer to import with their beneficiaries.
class ImportCustomer extends Equatable {
  const ImportCustomer({
    required this.fullName,
    required this.phone,
    this.ref,
    this.email,
    this.documentType,
    this.documentNumber,
    this.address,
    this.notes,
    this.beneficiaries = const [],
  });

  /// Where it is in the file ("fila 3"), returned as is to find it.
  final String? ref;
  final String fullName;
  final String phone;
  final String? email;
  final String? documentType;
  final String? documentNumber;
  final String? address;
  final String? notes;
  final List<ImportBeneficiary> beneficiaries;

  Map<String, dynamic> toJson() => {
    'ref': ref,
    'fullName': fullName,
    'phone': phone,
    'email': email,
    'documentType': documentType,
    'documentNumber': documentNumber,
    'address': address,
    'notes': notes,
    'beneficiaries': [for (final beneficiary in beneficiaries) beneficiary.toJson()],
  };

  @override
  List<Object?> get props => [ref, fullName, phone, address, beneficiaries];
}

enum ImportStatus {
  created('CREATED'),
  existing('EXISTING'),
  rejected('REJECTED');

  const ImportStatus(this.code);

  final String code;

  static ImportStatus fromCode(String? code) =>
      values.firstWhere((status) => status.code == code, orElse: () => rejected);
}

class ImportItemResult extends Equatable {
  const ImportItemResult({required this.status, this.ref, this.code, this.message, this.linked = false});

  factory ImportItemResult.fromJson(Map<String, dynamic> json) => ImportItemResult(
    status: ImportStatus.fromCode(json['status'] as String?),
    ref: json['ref'] as String?,
    code: json['code'] as String?,
    message: json['message'] as String?,
    linked: json['linked'] as bool? ?? false,
  );

  final ImportStatus status;
  final String? ref;
  final String? code;
  final String? message;

  /// For a beneficiary: newly linked to the customer.
  final bool linked;

  @override
  List<Object?> get props => [status, ref, code];
}

class ImportCustomerResult extends ImportItemResult {
  const ImportCustomerResult({
    required super.status,
    super.ref,
    super.code,
    super.message,
    this.beneficiaries = const [],
  });

  factory ImportCustomerResult.fromJson(Map<String, dynamic> json) => ImportCustomerResult(
    status: ImportStatus.fromCode(json['status'] as String?),
    ref: json['ref'] as String?,
    code: json['code'] as String?,
    message: json['message'] as String?,
    beneficiaries: [
      for (final item in json['beneficiaries'] as List? ?? const [])
        ImportItemResult.fromJson(item as Map<String, dynamic>),
    ],
  );

  final List<ImportItemResult> beneficiaries;
}

/// What an import did (or, as a preview, would do).
class ImportResult extends Equatable {
  const ImportResult({
    required this.dryRun,
    this.customersCreated = 0,
    this.customersExisting = 0,
    this.customersRejected = 0,
    this.beneficiariesCreated = 0,
    this.beneficiariesExisting = 0,
    this.beneficiariesRejected = 0,
    this.linksCreated = 0,
    this.results = const [],
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    int count(String key) => summary[key] as int? ?? 0;
    return ImportResult(
      dryRun: json['dryRun'] as bool? ?? false,
      customersCreated: count('customersCreated'),
      customersExisting: count('customersExisting'),
      customersRejected: count('customersRejected'),
      beneficiariesCreated: count('beneficiariesCreated'),
      beneficiariesExisting: count('beneficiariesExisting'),
      beneficiariesRejected: count('beneficiariesRejected'),
      linksCreated: count('linksCreated'),
      results: [
        for (final item in json['results'] as List? ?? const [])
          ImportCustomerResult.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final bool dryRun;
  final int customersCreated;
  final int customersExisting;
  final int customersRejected;
  final int beneficiariesCreated;
  final int beneficiariesExisting;
  final int beneficiariesRejected;
  final int linksCreated;
  final List<ImportCustomerResult> results;

  /// Adds the result of another batch of the same file.
  ImportResult operator +(ImportResult other) => ImportResult(
    dryRun: dryRun,
    customersCreated: customersCreated + other.customersCreated,
    customersExisting: customersExisting + other.customersExisting,
    customersRejected: customersRejected + other.customersRejected,
    beneficiariesCreated: beneficiariesCreated + other.beneficiariesCreated,
    beneficiariesExisting: beneficiariesExisting + other.beneficiariesExisting,
    beneficiariesRejected: beneficiariesRejected + other.beneficiariesRejected,
    linksCreated: linksCreated + other.linksCreated,
    results: [...results, ...other.results],
  );

  /// Every rejected customer or beneficiary, with where it is in the file.
  List<ImportItemResult> get rejected => [
    for (final customer in results) ...[
      if (customer.status == ImportStatus.rejected) customer,
      for (final beneficiary in customer.beneficiaries)
        if (beneficiary.status == ImportStatus.rejected) beneficiary,
    ],
  ];

  @override
  List<Object?> get props => [dryRun, customersCreated, customersRejected, beneficiariesCreated, results.length];
}

/// What a beneficiaries-only import did (or, as a preview, would do).
class BeneficiaryImportResult extends Equatable {
  const BeneficiaryImportResult({
    required this.dryRun,
    this.created = 0,
    this.existing = 0,
    this.rejectedCount = 0,
    this.results = const [],
  });

  factory BeneficiaryImportResult.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    int count(String key) => summary[key] as int? ?? 0;
    return BeneficiaryImportResult(
      dryRun: json['dryRun'] as bool? ?? false,
      created: count('created'),
      existing: count('existing'),
      rejectedCount: count('rejected'),
      results: [
        for (final item in json['results'] as List? ?? const [])
          ImportItemResult.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final bool dryRun;
  final int created;
  final int existing;
  final int rejectedCount;
  final List<ImportItemResult> results;

  /// Adds the result of another batch of the same file.
  BeneficiaryImportResult operator +(BeneficiaryImportResult other) => BeneficiaryImportResult(
    dryRun: dryRun,
    created: created + other.created,
    existing: existing + other.existing,
    rejectedCount: rejectedCount + other.rejectedCount,
    results: [...results, ...other.results],
  );

  List<ImportItemResult> get rejected => [
    for (final item in results)
      if (item.status == ImportStatus.rejected) item,
  ];

  @override
  List<Object?> get props => [dryRun, created, existing, rejectedCount, results.length];
}
