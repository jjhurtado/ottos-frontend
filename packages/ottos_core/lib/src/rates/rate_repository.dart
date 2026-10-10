import '../api/api_client.dart';
import '../models/rates.dart';

class RateRepository {
  RateRepository({required this._api});

  final ApiClient _api;

  Future<List<Corridor>> corridors() async {
    final json = await _api.get<List<dynamic>>('/corridors');
    return json.map((item) => Corridor.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Quote> quote({required String sourceCurrency, required String targetCurrency, required double amount}) async =>
      Quote.fromJson(
        await _api.post<Map<String, dynamic>>(
          '/quotes',
          body: {'sourceCurrency': sourceCurrency, 'targetCurrency': targetCurrency, 'amount': amount},
        ),
      );
}
