import 'package:ottos_core/ottos_core.dart';

/// The customers' CSV: one row per beneficiary repeating the customer's data
/// (a customer without beneficiaries is one row). Column names in Spanish.
abstract final class CustomerCsv {
  static const customerColumns = [
    'cliente_nombre',
    'cliente_telefono',
    'cliente_email',
    'cliente_tipo_documento',
    'cliente_documento',
    'cliente_direccion',
    'cliente_notas',
  ];
  static const beneficiaryColumns = [
    'beneficiario_nombre',
    'beneficiario_telefono',
    'beneficiario_telefono_alternativo',
    'beneficiario_calle',
    'beneficiario_numero',
    'beneficiario_entre_calles',
    'beneficiario_reparto',
    'beneficiario_municipio',
    'beneficiario_referencia',
    'beneficiario_documento',
    'beneficiario_notas',
  ];

  /// Only in the export, for reading; the import ignores them.
  static const statusColumns = ['cliente_activo', 'beneficiario_activo'];

  static const required = ['cliente_nombre', 'cliente_telefono'];

  /// The export (`GET /customers/export`) as CSV text.
  static String export(List<Map<String, dynamic>> customers) {
    String? text(Object? value) => value?.toString();
    String yesNo(Object? active) => active == false ? 'no' : 'sí';
    final rows = <List<String?>>[
      [...customerColumns, ...beneficiaryColumns, ...statusColumns],
    ];
    for (final customer in customers) {
      final customerCells = [
        text(customer['fullName']),
        text(customer['phone']),
        text(customer['email']),
        text(customer['documentType']),
        text(customer['documentNumber']),
        text(customer['address']),
        text(customer['notes']),
      ];
      final beneficiaries = [
        for (final item in customer['beneficiaries'] as List? ?? const []) item as Map<String, dynamic>,
      ];
      if (beneficiaries.isEmpty) {
        rows.add([...customerCells, for (final _ in beneficiaryColumns) null, yesNo(customer['active']), null]);
      }
      for (final beneficiary in beneficiaries) {
        rows.add([
          ...customerCells,
          text(beneficiary['fullName']),
          text(beneficiary['phone']),
          text(beneficiary['alternatePhone']),
          text(beneficiary['street']),
          text(beneficiary['houseNumber']),
          text(beneficiary['betweenStreets']),
          text(beneficiary['neighborhood']),
          // The name reads better and imports the same (code or name).
          text(beneficiary['municipalityName'] ?? beneficiary['municipalityCode']),
          text(beneficiary['reference']),
          text(beneficiary['documentNumber']),
          text(beneficiary['notes']),
          yesNo(customer['active']),
          yesNo(beneficiary['active']),
        ]);
      }
    }
    return Csv.encode(rows);
  }

  /// The file's customers to import, grouping the consecutive or scattered
  /// rows of the same customer (same name, phone and address). Throws a
  /// [FormatException] in Spanish if the file is not this CSV.
  static List<ImportCustomer> parse(String text) {
    final rows = Csv.decode(text);
    if (rows.isEmpty) throw const FormatException('El archivo está vacío.');
    final header = [for (final name in rows.first) name.trim().toLowerCase()];
    final missing = required.where((column) => !header.contains(column)).toList();
    if (missing.isNotEmpty) {
      throw FormatException('Faltan las columnas ${missing.join(', ')}. Usa el formato de «Exportar CSV».');
    }
    String? cell(List<String> row, String column) {
      final index = header.indexOf(column);
      if (index < 0 || index >= row.length) return null;
      final value = row[index].trim();
      return value.isEmpty ? null : value;
    }

    String key(String? value) => (value ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    final customers = <String, ({ImportCustomer customer, List<ImportBeneficiary> beneficiaries})>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (Csv.isBlank(row)) continue;
      // Row 1 is the header, as a spreadsheet numbers it.
      final ref = 'fila ${i + 1}';
      final name = cell(row, 'cliente_nombre') ?? '';
      final phone = cell(row, 'cliente_telefono') ?? '';
      final address = cell(row, 'cliente_direccion');
      final id = '${key(name)}|${key(phone)}|${key(address)}';
      final entry = customers.putIfAbsent(
        id,
        () => (
          customer: ImportCustomer(
            ref: ref,
            fullName: name,
            phone: phone,
            email: cell(row, 'cliente_email'),
            documentType: cell(row, 'cliente_tipo_documento'),
            documentNumber: cell(row, 'cliente_documento'),
            address: address,
            notes: cell(row, 'cliente_notas'),
          ),
          beneficiaries: <ImportBeneficiary>[],
        ),
      );
      final beneficiaryName = cell(row, 'beneficiario_nombre');
      if (beneficiaryName == null && cell(row, 'beneficiario_telefono') == null) continue;
      entry.beneficiaries.add(
        ImportBeneficiary(
          ref: ref,
          fullName: beneficiaryName ?? '',
          phone: cell(row, 'beneficiario_telefono') ?? '',
          alternatePhone: cell(row, 'beneficiario_telefono_alternativo'),
          street: cell(row, 'beneficiario_calle') ?? '',
          houseNumber: cell(row, 'beneficiario_numero'),
          betweenStreets: cell(row, 'beneficiario_entre_calles'),
          neighborhood: cell(row, 'beneficiario_reparto'),
          municipality: cell(row, 'beneficiario_municipio') ?? '',
          reference: cell(row, 'beneficiario_referencia'),
          documentNumber: cell(row, 'beneficiario_documento'),
          notes: cell(row, 'beneficiario_notas'),
        ),
      );
    }
    return [
      for (final entry in customers.values)
        ImportCustomer(
          ref: entry.customer.ref,
          fullName: entry.customer.fullName,
          phone: entry.customer.phone,
          email: entry.customer.email,
          documentType: entry.customer.documentType,
          documentNumber: entry.customer.documentNumber,
          address: entry.customer.address,
          notes: entry.customer.notes,
          beneficiaries: entry.beneficiaries,
        ),
    ];
  }
}

/// Beneficiaries without a customer: the `beneficiario_*` columns of
/// [CustomerCsv], one row each (an export of customers also works).
abstract final class BeneficiaryCsv {
  static const required = ['beneficiario_nombre', 'beneficiario_telefono'];

  /// Throws a [FormatException] in Spanish if the file is not this CSV.
  static List<ImportBeneficiary> parse(String text) {
    final rows = Csv.decode(text);
    if (rows.isEmpty) throw const FormatException('El archivo está vacío.');
    final header = [for (final name in rows.first) name.trim().toLowerCase()];
    final missing = required.where((column) => !header.contains(column)).toList();
    if (missing.isNotEmpty) {
      throw FormatException(
        'Faltan las columnas ${missing.join(', ')}. Columnas: ${CustomerCsv.beneficiaryColumns.join('; ')}.',
      );
    }
    String? cell(List<String> row, String column) {
      final index = header.indexOf(column);
      if (index < 0 || index >= row.length) return null;
      final value = row[index].trim();
      return value.isEmpty ? null : value;
    }

    return [
      for (var i = 1; i < rows.length; i++)
        if (cell(rows[i], 'beneficiario_nombre') != null || cell(rows[i], 'beneficiario_telefono') != null)
          ImportBeneficiary(
            // Row 1 is the header, as a spreadsheet numbers it.
            ref: 'fila ${i + 1}',
            fullName: cell(rows[i], 'beneficiario_nombre') ?? '',
            phone: cell(rows[i], 'beneficiario_telefono') ?? '',
            alternatePhone: cell(rows[i], 'beneficiario_telefono_alternativo'),
            street: cell(rows[i], 'beneficiario_calle') ?? '',
            houseNumber: cell(rows[i], 'beneficiario_numero'),
            betweenStreets: cell(rows[i], 'beneficiario_entre_calles'),
            neighborhood: cell(rows[i], 'beneficiario_reparto'),
            municipality: cell(rows[i], 'beneficiario_municipio') ?? '',
            reference: cell(rows[i], 'beneficiario_referencia'),
            documentNumber: cell(rows[i], 'beneficiario_documento'),
            notes: cell(rows[i], 'beneficiario_notas'),
          ),
    ];
  }
}
