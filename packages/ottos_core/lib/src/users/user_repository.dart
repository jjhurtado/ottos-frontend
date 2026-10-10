import '../api/api_client.dart';
import '../models/staff.dart';

/// Staff users (`users:read`, changes need `users:write`).
class UserRepository {
  UserRepository({required this._api});

  final ApiClient _api;

  Future<List<StaffUser>> list() async {
    final json = await _api.get<List<dynamic>>('/users');
    return json.map((item) => StaffUser.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<StaffUser> get(String id) async => StaffUser.fromJson(await _api.get<Map<String, dynamic>>('/users/$id'));

  /// Creates a user; the email must be free (`EMAIL_TAKEN`).
  Future<StaffUser> create(NewStaffUser user) async =>
      StaffUser.fromJson(await _api.post<Map<String, dynamic>>('/users', body: user.toJson()));

  Future<StaffUser> rename(String id, String name) async =>
      StaffUser.fromJson(await _api.put<Map<String, dynamic>>('/users/$id', body: {'name': name.trim()}));

  /// Replaces the user's roles. Granting permissions the caller lacks is refused
  /// (`PERMISSION_ESCALATION`), and so is removing the last active admin (`LAST_ADMIN`).
  Future<StaffUser> replaceRoles(String id, Set<String> roleIds) async =>
      StaffUser.fromJson(await _api.put<Map<String, dynamic>>('/users/$id/roles', body: {'roleIds': roleIds.toList()}));

  /// Deactivates the user and ends their sessions; not allowed on yourself (`CANNOT_DEACTIVATE_SELF`).
  Future<StaffUser> deactivate(String id) async =>
      StaffUser.fromJson(await _api.post<Map<String, dynamic>>('/users/$id/deactivate'));

  Future<StaffUser> activate(String id) async =>
      StaffUser.fromJson(await _api.post<Map<String, dynamic>>('/users/$id/activate'));

  /// Sets a new password (8 to 72 characters) and ends the user's sessions.
  Future<void> resetPassword(String id, String password) =>
      _api.put<void>('/users/$id/password', body: {'password': password});
}
