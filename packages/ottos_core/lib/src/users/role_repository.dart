import '../api/api_client.dart';
import '../models/staff.dart';

/// Roles and their permissions (`roles:read`, changes need `roles:write`).
/// Built-in roles cannot be changed (`BUILT_IN_ROLE`).
class RoleRepository {
  RoleRepository({required this._api});

  final ApiClient _api;

  Future<List<Role>> list() async {
    final json = await _api.get<List<dynamic>>('/roles');
    return json.map((item) => Role.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Everything a role can be granted.
  Future<List<PermissionInfo>> permissions() async {
    final json = await _api.get<List<dynamic>>('/permissions');
    return json.map((item) => PermissionInfo.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Creates a role; the code must be free (`ROLE_CODE_TAKEN`), and only
  /// permissions the caller has can be granted (`PERMISSION_ESCALATION`).
  Future<Role> create(NewRole role) async =>
      Role.fromJson(await _api.post<Map<String, dynamic>>('/roles', body: role.toJson()));

  Future<Role> describe(String id, {required String name, String? description}) async => Role.fromJson(
    await _api.put<Map<String, dynamic>>(
      '/roles/$id',
      body: {
        'name': name.trim(),
        'description': description == null || description.trim().isEmpty ? null : description.trim(),
      },
    ),
  );

  /// Replaces the role's permissions; every permission added or removed must be one the caller has.
  Future<Role> replacePermissions(String id, Set<String> permissions) async => Role.fromJson(
    await _api.put<Map<String, dynamic>>('/roles/$id/permissions', body: {'permissions': permissions.toList()}),
  );

  /// Deletes a role no user holds (`ROLE_IN_USE` otherwise).
  Future<void> delete(String id) => _api.delete<void>('/roles/$id');
}
