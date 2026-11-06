import '../api/api_client.dart';
import '../models/rates.dart';
import '../models/remittance.dart';
import '../utils/business_time.dart';

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

  /// The settings; their business time zone goes to [BusinessTime].
  Future<Settings> settings() async =>
      _useZone(Settings.fromJson(await _api.get<Map<String, dynamic>>('/configuration/settings')));

  /// Changes the settings given; the others keep their value. A new
  /// [businessTimeZone] (`UTC-05:00`) applies here at once (AC-2.3).
  Future<Settings> updateSettings({
    double? minimumAmount,
    int? defaultDeliveryDays,
    double? exchangeRateTolerancePercent,
    String? businessTimeZone,
  }) async => _useZone(
    Settings.fromJson(
      await _api.put<Map<String, dynamic>>(
        '/configuration/settings',
        body: {
          'minimumAmount': ?minimumAmount,
          'defaultDeliveryDays': ?defaultDeliveryDays,
          'exchangeRateTolerancePercent': ?exchangeRateTolerancePercent,
          'businessTimeZone': ?businessTimeZone,
        },
      ),
    ),
  );

  /// The business time zone (`GET /configuration/business-time`, any session),
  /// applied to [BusinessTime]. Null from a server older than REQ-006, which
  /// keeps the zone in use.
  Future<BusinessTimeZone?> businessTime() async {
    final zone = BusinessTimeZone.fromJson(await _api.get<Map<String, dynamic>>('/configuration/business-time'));
    BusinessTime.setZone(zone);
    return zone;
  }

  static Settings _useZone(Settings settings) {
    BusinessTime.setZone(settings.businessTime);
    return settings;
  }

  /// Deliveries and pickups have their own rate and fee. [onTheHouse] quotes
  /// a delivery without a fee, telling the fee left uncharged.
  Future<Quote> quote({
    required String sourceCurrency,
    required String targetCurrency,
    required double amount,
    RemittanceType type = RemittanceType.delivery,
    double? rate,
    double? fee,
    bool onTheHouse = false,
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
        'fee': ?fee,
        if (onTheHouse) 'onTheHouse': true,
      },
    ),
  );
}
