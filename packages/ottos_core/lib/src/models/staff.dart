import 'package:equatable/equatable.dart';

import 'json.dart';

/// A role as shown on a user (`RoleSummary`).
class RoleSummary extends Equatable {
  const RoleSummary({required this.id, required this.code, required this.name});

  factory RoleSummary.fromJson(Map<String, dynamic> json) => RoleSummary(
    id: json['id'] as String,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? json['code'] as String? ?? '',
  );

  final String id;
  final String code;
  final String name;

  @override
  List<Object?> get props => [id];
}

/// A role with its permissions (`RoleView`). Built-in roles cannot be edited or deleted.
class Role extends Equatable {
  const Role({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.builtIn = false,
    this.permissions = const [],
  });

  factory Role.fromJson(Map<String, dynamic> json) => Role(
    id: json['id'] as String,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? json['code'] as String? ?? '',
    description: json['description'] as String?,
    builtIn: json['builtIn'] as bool? ?? false,
    permissions: List<String>.from(json['permissions'] as List? ?? const []),
  );

  final String id;
  final String code;
  final String name;
  final String? description;
  final bool builtIn;
  final List<String> permissions;

  @override
  List<Object?> get props => [id, code, name, description, builtIn, permissions];
}

/// A staff user of the apps (`UserView`).
class StaffUser extends Equatable {
  const StaffUser({
    required this.id,
    required this.email,
    required this.name,
    this.active = true,
    this.roles = const [],
    this.createdAt,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) => StaffUser(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
    active: json['active'] as bool? ?? true,
    roles: (json['roles'] as List? ?? const [])
        .map((role) => RoleSummary.fromJson(role as Map<String, dynamic>))
        .toList(),
    createdAt: parseDateTime(json['createdAt']),
  );

  final String id;
  final String email;
  final String name;
  final bool active;
  final List<RoleSummary> roles;
  final DateTime? createdAt;

  String get displayName => name.isEmpty ? email : name;

  @override
  List<Object?> get props => [id, email, name, active, roles];
}

/// Data to create a staff user (`POST /users`).
class NewStaffUser extends Equatable {
  const NewStaffUser({required this.email, required this.name, required this.password, required this.roleIds});

  final String email;
  final String name;

  /// Initial password, 8 to 72 characters.
  final String password;
  final Set<String> roleIds;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'name': name.trim(),
    'password': password,
    'roleIds': roleIds.toList(),
  };

  @override
  List<Object?> get props => [email, name, roleIds];
}

/// Something a role can be granted (`PermissionView`), grouped by [module].
class PermissionInfo extends Equatable {
  const PermissionInfo({required this.code, required this.module, this.description});

  factory PermissionInfo.fromJson(Map<String, dynamic> json) => PermissionInfo(
    code: json['code'] as String,
    module: json['module'] as String? ?? '',
    description: json['description'] as String?,
  );

  final String code;
  final String module;

  /// In English, from the backend; shown when there is no Spanish label.
  final String? description;

  @override
  List<Object?> get props => [code];
}

/// Data of a new role (`POST /roles`).
class NewRole extends Equatable {
  const NewRole({required this.code, required this.name, this.description, this.permissions = const {}});

  /// UPPER_SNAKE_CASE, 2 to 50 characters; cannot change later.
  final String code;
  final String name;
  final String? description;
  final Set<String> permissions;

  Map<String, dynamic> toJson() => {
    'code': code.trim(),
    'name': name.trim(),
    'description': description == null || description!.trim().isEmpty ? null : description!.trim(),
    'permissions': permissions.toList(),
  };

  @override
  List<Object?> get props => [code, name, description, permissions];
}
