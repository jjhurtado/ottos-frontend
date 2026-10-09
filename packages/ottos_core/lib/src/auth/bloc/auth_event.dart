part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// The app started: restore the stored session, if any.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// The login form succeeded.
final class AuthLoggedIn extends AuthEvent {
  const AuthLoggedIn(this.user);

  final CurrentUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// The token could not be refreshed.
final class _AuthSessionExpired extends AuthEvent {
  const _AuthSessionExpired();
}
