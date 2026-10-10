import '../api/api_client.dart';
import '../models/customer.dart';

class CustomerRepository {
  CustomerRepository({required this._api});

  final ApiClient _api;

  /// Customers whose name, phone or document matches [query]; all when empty.
  Future<List<Customer>> search(String query) async {
    final json = await _api.get<List<dynamic>>('/customers', query: {'q': query.trim().isEmpty ? null : query.trim()});
    return json.map((item) => Customer.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Customer> get(String id) async => Customer.fromJson(await _api.get<Map<String, dynamic>>('/customers/$id'));

  /// The beneficiaries linked to a customer.
  Future<List<Beneficiary>> beneficiaries(String customerId) async {
    final json = await _api.get<List<dynamic>>('/customers/$customerId/beneficiaries');
    return json.map((item) => Beneficiary.fromJson(item as Map<String, dynamic>)).toList();
  }
}
