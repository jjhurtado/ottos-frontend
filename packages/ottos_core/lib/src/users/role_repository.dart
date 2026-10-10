import '../api/api_client.dart';
import '../models/staff.dart';

/// Roles and their permissions (`roles:read`).
class RoleRepository {
  RoleRepository({required this._api});

  final ApiClient _api;

  Future<List<Role>> list() async {
    final json = await _api.get<List<dynamic>>('/roles');
    return json.map((item) => Role.fromJson(item as Map<String, dynamic>)).toList();
  }
}
