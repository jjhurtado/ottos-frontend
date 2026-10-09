import 'package:equatable/equatable.dart';

/// The logged-in user, from `GET /auth/me`.
class CurrentUser extends Equatable {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.name,
    required this.type,
    required this.roles,
    required this.permissions,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? '',
    roles: List<String>.from(json['roles'] as List? ?? const []),
    permissions: Set<String>.from(json['permissions'] as List? ?? const []),
  );

  final String id;
  final String email;
  final String name;
  final String type;
  final List<String> roles;
  final Set<String> permissions;

  bool can(String permission) => permissions.contains(permission);

  bool canAny(Iterable<String> required) => required.any(permissions.contains);

  String get displayName => name.isEmpty ? email : name;

  @override
  List<Object?> get props => [id, email, name, type, roles, permissions];
}
