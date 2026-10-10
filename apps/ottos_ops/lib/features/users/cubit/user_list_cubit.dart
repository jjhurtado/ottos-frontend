import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum UserListStatus { loading, success, failure }

final class UserListState extends Equatable {
  const UserListState({
    this.status = UserListStatus.loading,
    this.users = const [],
    this.query = '',
    this.showInactive = false,
    this.error,
  });

  final UserListStatus status;

  /// Every user, sorted by name.
  final List<StaffUser> users;
  final String query;
  final bool showInactive;
  final String? error;

  /// The users to show: matching [query] by name, email or role, and active
  /// unless [showInactive].
  List<StaffUser> get visible {
    final text = query.trim().toLowerCase();
    return users.where((user) {
      if (!showInactive && !user.active) return false;
      if (text.isEmpty) return true;
      return user.name.toLowerCase().contains(text) ||
          user.email.toLowerCase().contains(text) ||
          user.roles.any((role) => role.displayName.toLowerCase().contains(text));
    }).toList();
  }

  int get inactiveCount => users.where((user) => !user.active).length;

  UserListState copyWith({String? query, bool? showInactive}) => UserListState(
    status: status,
    users: users,
    query: query ?? this.query,
    showInactive: showInactive ?? this.showInactive,
    error: error,
  );

  @override
  List<Object?> get props => [status, users, query, showInactive, error];
}

/// Staff users; the backend returns all of them, so search and filters run here.
class UserListCubit extends Cubit<UserListState> {
  UserListCubit({required this._users}) : super(const UserListState());

  final UserRepository _users;

  Future<void> load() async {
    if (state.status != UserListStatus.success) {
      emit(UserListState(query: state.query, showInactive: state.showInactive));
    }
    try {
      final users = await _users.list()
        ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      emit(
        UserListState(
          status: UserListStatus.success,
          users: users,
          query: state.query,
          showInactive: state.showInactive,
        ),
      );
    } on ApiException catch (error) {
      emit(
        UserListState(
          status: UserListStatus.failure,
          query: state.query,
          showInactive: state.showInactive,
          error: error.message,
        ),
      );
    }
  }

  void queryChanged(String query) => emit(state.copyWith(query: query));

  void showInactiveChanged(bool show) => emit(state.copyWith(showInactive: show));
}
