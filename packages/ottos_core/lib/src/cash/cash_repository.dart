import '../api/api_client.dart';
import '../models/cash.dart';

class CashRepository {
  CashRepository({required this._api});

  final ApiClient _api;

  /// The logged-in courier's cash (`cash:read-own`).
  Future<CourierStatement> myStatement() async =>
      CourierStatement.fromJson(await _api.get<Map<String, dynamic>>('/cash/me'));
}
