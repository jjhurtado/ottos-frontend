import '../api/api_client.dart';
import '../models/rates.dart';

class RateRepository {
  RateRepository({required this._api});

  final ApiClient _api;

  Future<List<Corridor>> corridors() async {
    final json = await _api.get<List<dynamic>>('/corridors');
    return json.map((item) => Corridor.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Exchange rates of a corridor, newest first.
  Future<List<ExchangeRate>> rateHistory(String corridorCode) async {
    final json = await _api.get<List<dynamic>>('/corridors/$corridorCode/rates');
    return json.map((item) => ExchangeRate.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Sets a new exchange rate for a corridor; it applies from now on (`rates:write`).
  Future<ExchangeRate> setRate(String corridorCode, double rate) async => ExchangeRate.fromJson(
    await _api.post<Map<String, dynamic>>('/corridors/$corridorCode/rates', body: {'rate': rate}),
  );

  /// Fee rules of a corridor, newest first.
  Future<List<FeeRule>> feeRuleHistory(String corridorCode) async {
    final json = await _api.get<List<dynamic>>('/corridors/$corridorCode/fee-rules');
    return json.map((item) => FeeRule.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Sets a new fee rule for a corridor; it applies from now on (`rates:write`).
  Future<FeeRule> setFeeRule(String corridorCode, FeeRuleInput input) async => FeeRule.fromJson(
    await _api.post<Map<String, dynamic>>('/corridors/$corridorCode/fee-rules', body: input.toJson()),
  );

  Future<Quote> quote({required String sourceCurrency, required String targetCurrency, required double amount}) async =>
      Quote.fromJson(
        await _api.post<Map<String, dynamic>>(
          '/quotes',
          body: {'sourceCurrency': sourceCurrency, 'targetCurrency': targetCurrency, 'amount': amount},
        ),
      );
}
