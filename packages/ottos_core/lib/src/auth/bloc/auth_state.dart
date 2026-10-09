part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

final class AuthState extends Equatable {
  const AuthState._({required this.status, this.user, this.sessionExpired = false});

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated(CurrentUser user) : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated({bool sessionExpired = false})
    : this._(status: AuthStatus.unauthenticated, sessionExpired: sessionExpired);

  final AuthStatus status;
  final CurrentUser? user;

  /// True when the user was logged out because the session expired, so the
  /// login screen can say why.
  final bool sessionExpired;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => [status, user, sessionExpired];
}
