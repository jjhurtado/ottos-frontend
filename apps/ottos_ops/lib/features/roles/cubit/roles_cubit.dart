import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum RolesStatus { loading, success, failure }

final class RolesState extends Equatable {
  const RolesState({this.status = RolesStatus.loading, this.roles = const [], this.catalog = const [], this.error});

  final RolesStatus status;

  /// Built-in roles first, then by name.
  final List<Role> roles;

  /// Every permission a role can be granted.
  final List<PermissionInfo> catalog;
  final String? error;

  @override
  List<Object?> get props => [status, roles, catalog, error];
}

/// Roles with their permissions, and the permission catalog.
class RolesCubit extends Cubit<RolesState> {
  RolesCubit({required this._roles}) : super(const RolesState());

  final RoleRepository _roles;

  /// Loads everything; after a change it refreshes in place, keeping the page.
  Future<void> load() async {
    if (state.status != RolesStatus.success) emit(const RolesState());
    try {
      final results = await Future.wait<Object>([_roles.list(), _roles.permissions()], eagerError: true);
      final roles = [...results[0] as List<Role>]
        ..sort(
          (a, b) =>
              a.builtIn == b.builtIn ? a.name.toLowerCase().compareTo(b.name.toLowerCase()) : (a.builtIn ? -1 : 1),
        );
      emit(RolesState(status: RolesStatus.success, roles: roles, catalog: results[1] as List<PermissionInfo>));
    } on ApiException catch (error) {
      emit(RolesState(status: RolesStatus.failure, error: error.message));
    }
  }
}
