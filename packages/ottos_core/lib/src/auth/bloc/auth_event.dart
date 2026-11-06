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

/// The user logs out; with [forgetBiometricLogin] the fingerprint login saved
/// on this device is forgotten too.
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested({this.forgetBiometricLogin = false});

  final bool forgetBiometricLogin;

  @override
  List<Object?> get props => [forgetBiometricLogin];
}

/// The user changed their password: the backend signed them out everywhere,
/// so the app does too and the login says why.
final class AuthPasswordChanged extends AuthEvent {
  const AuthPasswordChanged();
}

/// The token could not be refreshed.
final class _AuthSessionExpired extends AuthEvent {
  const _AuthSessionExpired();
}
