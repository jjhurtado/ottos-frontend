import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/api_exception.dart';
import '../../l10n/core_texts.dart';
import '../auth_repository.dart';
import '../bloc/auth_bloc.dart';
import '../current_user.dart';
import 'login_memory.dart';

enum LoginStatus { idle, submitting, failure }

final class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.idle,
    this.error,
    this.rememberedEmail,
    this.rememberEmail = true,
    this.biometricsReady = false,
    this.offerBiometrics = false,
  });

  final LoginStatus status;
  final String? error;

  /// Filled in the form when the person asked to be remembered.
  final String? rememberedEmail;
  final bool rememberEmail;

  /// "Entrar con huella" is offered: the device can and has saved credentials.
  final bool biometricsReady;

  /// Logged in with the password: ask whether to use the fingerprint next time.
  final bool offerBiometrics;

  bool get isSubmitting => status == LoginStatus.submitting;

  LoginState copyWith({
    LoginStatus? status,
    String? error,
    String? rememberedEmail,
    bool? rememberEmail,
    bool? biometricsReady,
    bool? offerBiometrics,
  }) => LoginState(
    status: status ?? this.status,
    error: error,
    rememberedEmail: rememberedEmail ?? this.rememberedEmail,
    rememberEmail: rememberEmail ?? this.rememberEmail,
    biometricsReady: biometricsReady ?? this.biometricsReady,
    offerBiometrics: offerBiometrics ?? false,
  );

  @override
  List<Object?> get props => [status, error, rememberedEmail, rememberEmail, biometricsReady, offerBiometrics];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({
    required this._authRepository,
    required this._authBloc,
    required this._accessPolicy,
    this._memory,
    this._biometrics,
  }) : super(const LoginState());

  final AuthRepository _authRepository;
  final AuthBloc _authBloc;
  final AccessPolicy _accessPolicy;
  final LoginMemory? _memory;
  final BiometricAuth? _biometrics;

  /// The user and password of a login waiting for the fingerprint question.
  ({CurrentUser user, String email, String password})? _pending;

  /// The backend code of the last failed login.
  String? _failureCode;

  /// Loads the remembered email and whether the fingerprint can be used.
  Future<void> start() async {
    final memory = _memory;
    if (memory == null) return;
    final email = await memory.rememberedEmail();
    final ready = await _biometricsAvailable() && await memory.biometricCredentials() != null;
    if (isClosed) return;
    emit(state.copyWith(rememberedEmail: email, rememberEmail: true, biometricsReady: ready));
  }

  void rememberChanged(bool remember) => emit(state.copyWith(rememberEmail: remember));

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(status: LoginStatus.submitting));
    final user = await _login(email.trim(), password);
    if (user == null) return;
    await _memory?.rememberEmail(state.rememberEmail ? email.trim() : null);
    // Offer the fingerprint once there is none saved for this device.
    if (_memory != null && await _biometricsAvailable() && await _memory.biometricCredentials() == null) {
      _pending = (user: user, email: email.trim(), password: password);
      emit(state.copyWith(offerBiometrics: true));
      return;
    }
    _enter(user);
  }

  /// The answer to "¿Entrar con huella la próxima vez?".
  Future<void> answerBiometrics({required bool use}) async {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    if (use && await _biometrics!.authenticate(CoreTexts.biometricEnableReason)) {
      await _memory!.saveBiometricCredentials(pending.email, pending.password);
    }
    _enter(pending.user);
  }

  /// Logs in with the credentials saved for the fingerprint, after checking it.
  Future<void> submitWithBiometrics() async {
    final memory = _memory;
    final biometrics = _biometrics;
    if (state.isSubmitting || memory == null || biometrics == null) return;
    final saved = await memory.biometricCredentials();
    if (saved == null) return;
    if (!await biometrics.authenticate(CoreTexts.biometricLoginReason)) return;
    emit(state.copyWith(status: LoginStatus.submitting));
    final user = await _login(saved.email, saved.password);
    if (user == null) {
      // The password changed since it was saved: ask for it once more.
      if (_failureCode == 'INVALID_CREDENTIALS') {
        await memory.clearBiometricCredentials();
        emit(state.copyWith(status: LoginStatus.failure, error: CoreTexts.biometricOutdated, biometricsReady: false));
      }
      return;
    }
    _enter(user);
  }

  Future<CurrentUser?> _login(String email, String password) async {
    _failureCode = null;
    try {
      final user = await _authRepository.login(email: email, password: password);
      if (!_accessPolicy(user)) {
        await _authRepository.logout();
        emit(state.copyWith(status: LoginStatus.failure, error: CoreTexts.noAccessToApp));
        return null;
      }
      return user;
    } on ApiException catch (error) {
      _failureCode = error.code;
      emit(state.copyWith(status: LoginStatus.failure, error: error.message));
      return null;
    }
  }

  Future<bool> _biometricsAvailable() async => _biometrics != null && await _biometrics.isAvailable();

  void _enter(CurrentUser user) {
    emit(state.copyWith(status: LoginStatus.idle));
    _authBloc.add(AuthLoggedIn(user));
  }
}
