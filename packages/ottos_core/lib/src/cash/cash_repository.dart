import '../api/api_client.dart';
import '../models/cash.dart';
import '../models/exchange.dart';
import '../models/page_result.dart';

class CashRepository {
  CashRepository({required this._api});

  final ApiClient _api;

  /// The logged-in courier's cash (`cash:read-own`).
  Future<CourierStatement> myStatement() async =>
      CourierStatement.fromJson(await _api.get<Map<String, dynamic>>('/cash/me'));

  /// The business cash box, per currency (`cash:read`).
  Future<List<Balance>> businessBalances() async =>
      _list(await _api.get<List<dynamic>>('/cash/business'), Balance.fromJson);

  /// The latest 100 movements of the business cash box, newest first (`cash:read`).
  Future<List<CashMovement>> businessMovements() async =>
      _list(await _api.get<List<dynamic>>('/cash/business/movements'), CashMovement.fromJson);

  /// Cash each courier carries (`cash:read`).
  Future<List<CourierCash>> couriers() async =>
      _list(await _api.get<List<dynamic>>('/cash/couriers'), CourierCash.fromJson);

  /// A courier's balances and latest 100 movements (`cash:read`).
  Future<CourierStatement> courierStatement(String courierId) async =>
      CourierStatement.fromJson(await _api.get<Map<String, dynamic>>('/cash/couriers/$courierId'));

  /// Cash movements caused by a remittance (`cash:read`).
  Future<List<CashMovement>> remittanceMovements(String remittanceId) async =>
      _list(await _api.get<List<dynamic>>('/cash/remittances/$remittanceId/movements'), CashMovement.fromJson);

  /// Hands cash from the business box to a courier (`cash:write`).
  Future<CashMovement> fundCourier(String courierId, CashInput input) =>
      _post('/cash/couriers/$courierId/funding', input);

  /// Registers cash a courier gave back to the business box (`cash:write`).
  Future<CashMovement> courierReturn(String courierId, CashInput input) =>
      _post('/cash/couriers/$courierId/returns', input);

  /// Puts money into the business box; the note is required (`cash:adjust`).
  Future<CashMovement> deposit(CashInput input) => _post('/cash/business/deposits', input);

  /// Takes money out of the business box; the note is required (`cash:adjust`).
  Future<CashMovement> withdraw(CashInput input) => _post('/cash/business/withdrawals', input);

  Future<CashMovement> _post(String path, CashInput input) async =>
      CashMovement.fromJson(await _api.post<Map<String, dynamic>>(path, body: input.toJson()));

  static List<T> _list<T>(List<dynamic> json, T Function(Map<String, dynamic>) fromJson) =>
      json.map((item) => fromJson(item as Map<String, dynamic>)).toList();

  /// The courier's own exchange (`cash:exchange-own`).
  Future<CurrencyExchange> exchangeOwn(ExchangeInput input) async =>
      CurrencyExchange.fromJson(await _api.post<Map<String, dynamic>>('/cash/me/exchanges', body: input.toJson()));

  /// Sales or admin, on behalf of a courier (`cash:write`).
  Future<CurrencyExchange> exchangeFor(String courierId, ExchangeInput input) async => CurrencyExchange.fromJson(
    await _api.post<Map<String, dynamic>>('/cash/couriers/$courierId/exchanges', body: input.toJson()),
  );

  /// Newest first; [review] true lists only the ones still waiting to be checked.
  Future<PageResult<CurrencyExchange>> exchanges({
    String? courierId,
    bool? review,
    int page = 0,
    int size = 20,
  }) async => PageResult.fromJson(
    await _api.get<Map<String, dynamic>>(
      '/cash/exchanges',
      query: {'courierId': courierId, 'review': review, 'page': page, 'size': size},
    ),
    CurrencyExchange.fromJson,
  );

  /// Clears the review, leaving [note] on the exchange (`cash:review`).
  Future<CurrencyExchange> resolveExchangeReview(String id, {required String note}) async => CurrencyExchange.fromJson(
    await _api.post<Map<String, dynamic>>('/cash/exchanges/$id/review/resolve', body: {'note': note.trim()}),
  );
}
