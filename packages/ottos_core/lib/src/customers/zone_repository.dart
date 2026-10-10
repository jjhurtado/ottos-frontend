import '../api/api_client.dart';
import '../models/zones.dart';

/// Provinces and municipalities; they rarely change, so they load once per session.
class ZoneRepository {
  ZoneRepository({required this._api});

  final ApiClient _api;
  Future<List<Province>>? _provinces;
  Future<List<Municipality>>? _municipalities;

  Future<List<Province>> provinces() => _provinces ??= _api
      .get<List<dynamic>>('/provinces')
      .then((json) => json.map((item) => Province.fromJson(item as Map<String, dynamic>)).toList())
      .catchError((Object error) {
        _provinces = null;
        throw error;
      });

  /// All municipalities; filter by [Municipality.provinceCode].
  Future<List<Municipality>> municipalities() => _municipalities ??= _api
      .get<List<dynamic>>('/municipalities')
      .then((json) => json.map((item) => Municipality.fromJson(item as Map<String, dynamic>)).toList())
      .catchError((Object error) {
        _municipalities = null;
        throw error;
      });
}
