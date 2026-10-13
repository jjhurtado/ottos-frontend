import '../api/api_client.dart';
import '../models/customer.dart';
import '../models/customer_transfer.dart';

class CustomerRepository {
  CustomerRepository({required this._api});

  final ApiClient _api;

  /// Customers whose name or phone contains [query] (at most 50); the most recent when empty.
  Future<List<Customer>> search(String query) async {
    final json = await _api.get<List<dynamic>>('/customers', query: {'q': query.trim().isEmpty ? null : query.trim()});
    return json.map((item) => Customer.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Customer> get(String id) async => Customer.fromJson(await _api.get<Map<String, dynamic>>('/customers/$id'));

  /// Registers a customer. Phone and document may repeat (a person with two
  /// addresses is two customers); only an identical name, phone and address is
  /// refused (`CUSTOMER_ALREADY_REGISTERED`).
  Future<Customer> create(CustomerInput input) async =>
      Customer.fromJson(await _api.post<Map<String, dynamic>>('/customers', body: input.toJson()));

  Future<Customer> update(String id, CustomerInput input) async =>
      Customer.fromJson(await _api.put<Map<String, dynamic>>('/customers/$id', body: input.toJson()));

  /// Remittance numbers for a customer (`remittances:read`).
  Future<CustomerStats> stats(String id) async =>
      CustomerStats.fromJson(await _api.get<Map<String, dynamic>>('/customers/$id/stats'));

  /// The beneficiaries linked to a customer.
  Future<List<Beneficiary>> beneficiaries(String customerId) async {
    final json = await _api.get<List<dynamic>>('/customers/$customerId/beneficiaries');
    return json.map((item) => Beneficiary.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Every active beneficiary whose name or phone contains [query] (at most
  /// 50), linked to a customer or not. A remittance links them by itself.
  Future<List<Beneficiary>> searchBeneficiaries(String query) async {
    final json = await _api.get<List<dynamic>>(
      '/beneficiaries',
      query: {'q': query.trim().isEmpty ? null : query.trim()},
    );
    return json.map((item) => Beneficiary.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Creates a beneficiary without a customer; a customer is linked later, or by its first remittance.
  Future<Beneficiary> createBeneficiary(BeneficiaryInput input) async =>
      Beneficiary.fromJson(await _api.post<Map<String, dynamic>>('/beneficiaries', body: input.toJson()));

  /// Creates a beneficiary linked to [customerId].
  Future<Beneficiary> addBeneficiary(String customerId, BeneficiaryInput input) async => Beneficiary.fromJson(
    await _api.post<Map<String, dynamic>>('/customers/$customerId/beneficiaries', body: input.toJson()),
  );

  /// Updates a beneficiary for every customer that sends to them.
  Future<Beneficiary> updateBeneficiary(String id, BeneficiaryInput input) async =>
      Beneficiary.fromJson(await _api.put<Map<String, dynamic>>('/beneficiaries/$id', body: input.toJson()));

  /// Stops [customerId] from sending to the beneficiary; past remittances stay as they are.
  Future<void> unlinkBeneficiary(String customerId, String beneficiaryId) =>
      _api.delete<void>('/customers/$customerId/beneficiaries/$beneficiaryId');

  /// Every customer with every linked beneficiary, as JSON (`customers:export`).
  Future<List<Map<String, dynamic>>> exportAll() async {
    final json = await _api.get<Map<String, dynamic>>('/customers/export');
    return [for (final item in json['customers'] as List? ?? const []) item as Map<String, dynamic>];
  }

  /// The backend's limit per request: longer files go in several.
  static const importBatch = 500;

  /// Imports [customers] (`customers:import`); with [dryRun] it only says what
  /// it would do. Existing ones are linked, never changed.
  Future<ImportResult> import(List<ImportCustomer> customers, {required bool dryRun}) async {
    var result = ImportResult(dryRun: dryRun);
    for (var start = 0; start < customers.length; start += importBatch) {
      final batch = customers.sublist(start, (start + importBatch).clamp(0, customers.length));
      result =
          result +
          ImportResult.fromJson(
            await _api.post<Map<String, dynamic>>(
              '/customers/import',
              body: {
                'dryRun': dryRun,
                'customers': [for (final customer in batch) customer.toJson()],
              },
            ),
          );
    }
    return result;
  }

  /// Imports beneficiaries without a customer (`customers:import`), linked
  /// later by their remittances; with [dryRun] it only says what it would do.
  Future<BeneficiaryImportResult> importBeneficiaries(
    List<ImportBeneficiary> beneficiaries, {
    required bool dryRun,
  }) async {
    var result = BeneficiaryImportResult(dryRun: dryRun);
    for (var start = 0; start < beneficiaries.length; start += importBatch) {
      final batch = beneficiaries.sublist(start, (start + importBatch).clamp(0, beneficiaries.length));
      result =
          result +
          BeneficiaryImportResult.fromJson(
            await _api.post<Map<String, dynamic>>(
              '/beneficiaries/import',
              body: {
                'dryRun': dryRun,
                'beneficiaries': [for (final beneficiary in batch) beneficiary.toJson()],
              },
            ),
          );
    }
    return result;
  }
}
