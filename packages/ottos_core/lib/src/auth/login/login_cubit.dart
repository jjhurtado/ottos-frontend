import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/api_exception.dart';
import '../../l10n/core_texts.dart';
import '../auth_repository.dart';
import '../bloc/auth_bloc.dart';

enum LoginStatus { idle, submitting, failure }

final class LoginState extends Equatable {
  const LoginState({this.status = LoginStatus.idle, this.error});

  final LoginStatus status;
  final String? error;

  bool get isSubmitting => status == LoginStatus.submitting;

  @override
  List<Object?> get props => [status, error];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required this._authRepository, required this._authBloc, required this._accessPolicy})
    : super(const LoginState());

  final AuthRepository _authRepository;
  final AuthBloc _authBloc;
  final AccessPolicy _accessPolicy;

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    emit(const LoginState(status: LoginStatus.submitting));
    try {
      final user = await _authRepository.login(email: email, password: password);
      if (!_accessPolicy(user)) {
        await _authRepository.logout();
        emit(const LoginState(status: LoginStatus.failure, error: CoreTexts.noAccessToApp));
        return;
      }
      emit(const LoginState());
      _authBloc.add(AuthLoggedIn(user));
    } on ApiException catch (error) {
      emit(LoginState(status: LoginStatus.failure, error: error.message));
    }
  }
}
