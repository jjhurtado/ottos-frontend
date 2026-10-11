import '../api/api_client.dart';
import '../models/rates.dart';
import '../models/remittance.dart';

/// Corridors, rates, fee rules and settings (`configuration:read`, changes need
/// `configuration:write`), and quotes (`rates:read`).
class RateRepository {
  RateRepository({required this._api});

  final ApiClient _api;

  Future<List<Corridor>> corridors() async {
    final json = await _api.get<List<dynamic>>('/configuration/corridors');
    return json.map((item) => Corridor.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Exchange rates of a corridor for one type of remittance, newest first.
  Future<List<ExchangeRate>> rateHistory(String corridorCode, {RemittanceType type = RemittanceType.delivery}) async {
    final json = await _api.get<List<dynamic>>(
      '/configuration/corridors/$corridorCode/rates',
      query: {'remittanceType': type.code},
    );
    return json.map((item) => ExchangeRate.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Sets a new exchange rate of a corridor for one type of remittance; it
  /// applies from now on (`configuration:write`).
  Future<ExchangeRate> setRate(
    String corridorCode,
    double rate, {
    RemittanceType type = RemittanceType.delivery,
  }) async => ExchangeRate.fromJson(
    await _api.post<Map<String, dynamic>>(
      '/configuration/corridors/$corridorCode/rates',
      body: {'rate': rate, 'remittanceType': type.code},
    ),
  );

  /// Fee rules of a corridor for one type of remittance, newest first.
  Future<List<FeeRule>> feeRuleHistory(String corridorCode, {RemittanceType type = RemittanceType.delivery}) async {
    final json = await _api.get<List<dynamic>>(
      '/configuration/corridors/$corridorCode/fee-rules',
      query: {'remittanceType': type.code},
    );
    return json.map((item) => FeeRule.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Sets a new fee rule of a corridor for one type of remittance; it applies
  /// from now on (`configuration:write`).
  Future<FeeRule> setFeeRule(
    String corridorCode,
    FeeRuleInput input, {
    RemittanceType type = RemittanceType.delivery,
  }) async => FeeRule.fromJson(
    await _api.post<Map<String, dynamic>>(
      '/configuration/corridors/$corridorCode/fee-rules',
      body: {...input.toJson(), 'remittanceType': type.code},
    ),
  );

  Future<Settings> settings() async =>
      Settings.fromJson(await _api.get<Map<String, dynamic>>('/configuration/settings'));

  /// Changes the settings given; the others keep their value.
  Future<Settings> updateSettings({
    double? minimumAmount,
    int? defaultDeliveryDays,
    double? exchangeRateTolerancePercent,
  }) async => Settings.fromJson(
    await _api.put<Map<String, dynamic>>(
      '/configuration/settings',
      body: {
        'minimumAmount': ?minimumAmount,
        'defaultDeliveryDays': ?defaultDeliveryDays,
        'exchangeRateTolerancePercent': ?exchangeRateTolerancePercent,
      },
    ),
  );

  /// Deliveries and pickups have their own rate and fee.
  Future<Quote> quote({
    required String sourceCurrency,
    required String targetCurrency,
    required double amount,
    RemittanceType type = RemittanceType.delivery,
    double? rate,
  }) async => Quote.fromJson(
    await _api.post<Map<String, dynamic>>(
      '/quotes',
      body: {
        'sourceCurrency': sourceCurrency,
        'targetCurrency': targetCurrency,
        'amount': amount,
        'remittanceType': type.code,
        // Only pickups take their own rate.
        'rate': ?rate,
      },
    ),
  );
}
