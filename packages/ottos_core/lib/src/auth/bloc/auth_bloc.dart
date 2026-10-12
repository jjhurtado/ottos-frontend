import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/api_exception.dart';
import '../auth_repository.dart';
import '../current_user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Decides whether a user may use a given app (e.g. the courier app needs
/// `remittances:read-assigned`).
typedef AccessPolicy = bool Function(CurrentUser user);

/// Holds the session for the whole app.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository, required this._accessPolicy})
    : _authRepository = authRepository,
      super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoggedIn>((event, emit) => emit(AuthState.authenticated(event.user)));
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthPasswordChanged>(_onPasswordChanged);
    on<_AuthSessionExpired>((event, emit) => emit(const AuthState.unauthenticated(sessionExpired: true)));
    _sessionExpiredSubscription = authRepository.sessionExpired.listen((_) => add(const _AuthSessionExpired()));
  }

  final AuthRepository _authRepository;
  final AccessPolicy _accessPolicy;
  late final StreamSubscription<void> _sessionExpiredSubscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    try {
      final user = await _authRepository.restoreSession();
      if (user != null && _accessPolicy(user)) {
        emit(AuthState.authenticated(user));
      } else {
        if (user != null) await _authRepository.logout();
        emit(const AuthState.unauthenticated());
      }
    } on ApiException {
      // Offline or server down: ask for login again rather than blocking the app.
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.logout();
    emit(const AuthState.unauthenticated());
  }

  Future<void> _onPasswordChanged(AuthPasswordChanged event, Emitter<AuthState> emit) async {
    // The refresh token is already revoked; this only clears the local session.
    await _authRepository.logout();
    emit(const AuthState.unauthenticated(passwordChanged: true));
  }

  @override
  Future<void> close() {
    _sessionExpiredSubscription.cancel();
    return super.close();
  }
}
