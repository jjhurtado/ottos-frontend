import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockAuthBloc extends Mock implements AuthBloc {}

class _MockBiometrics extends Mock implements BiometricAuth {}

/// In memory, like the secure storage.
class _Memory implements LoginMemory {
  String? email;
  ({String email, String password})? credentials;

  @override
  Future<String?> rememberedEmail() async => email;

  @override
  Future<void> rememberEmail(String? email) async => this.email = email;

  @override
  Future<({String email, String password})?> biometricCredentials() async => credentials;

  @override
  Future<void> saveBiometricCredentials(String email, String password) async =>
      credentials = (email: email, password: password);

  @override
  Future<void> clearBiometricCredentials() async => credentials = null;
}

const _user = CurrentUser(
  id: 'u1',
  email: 'ana@ottos.test',
  name: 'Ana',
  type: 'STAFF',
  roles: ['DELIVERY'],
  permissions: {},
);

void main() {
  late _MockAuth auth;
  late _MockAuthBloc authBloc;
  late _MockBiometrics biometrics;
  late _Memory memory;

  setUpAll(() => registerFallbackValue(const AuthStarted()));

  setUp(() {
    auth = _MockAuth();
    authBloc = _MockAuthBloc();
    biometrics = _MockBiometrics();
    memory = _Memory();
    when(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _user);
    when(() => biometrics.isAvailable()).thenAnswer((_) async => true);
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => true);
  });

  LoginCubit cubit({BiometricAuth? withBiometrics}) => LoginCubit(
    authRepository: auth,
    authBloc: authBloc,
    accessPolicy: (_) => true,
    memory: memory,
    biometrics: withBiometrics,
  );

  test('remembers the email unless unticked', () async {
    final login = cubit()..rememberChanged(true);
    await login.submit(email: ' ana@ottos.test ', password: 'secret');
    expect(memory.email, 'ana@ottos.test');
    verify(() => authBloc.add(const AuthLoggedIn(_user))).called(1);

    login.rememberChanged(false);
    await login.submit(email: 'ana@ottos.test', password: 'secret');
    expect(memory.email, isNull);
  });

  test('start fills the remembered email and offers the fingerprint only with saved credentials', () async {
    memory.email = 'ana@ottos.test';
    final login = cubit(withBiometrics: biometrics);
    await login.start();
    expect(login.state.rememberedEmail, 'ana@ottos.test');
    expect(login.state.biometricsReady, isFalse);

    memory.credentials = (email: 'ana@ottos.test', password: 'secret');
    await login.start();
    expect(login.state.biometricsReady, isTrue);
  });

  test('after a password login asks about the fingerprint and saves on yes', () async {
    final login = cubit(withBiometrics: biometrics);
    await login.submit(email: 'ana@ottos.test', password: 'secret');
    expect(login.state.offerBiometrics, isTrue);
    verifyNever(() => authBloc.add(any()));

    await login.answerBiometrics(use: true);
    expect(memory.credentials, (email: 'ana@ottos.test', password: 'secret'));
    verify(() => authBloc.add(const AuthLoggedIn(_user))).called(1);
  });

  test('saying no enters without saving', () async {
    final login = cubit(withBiometrics: biometrics);
    await login.submit(email: 'ana@ottos.test', password: 'secret');
    await login.answerBiometrics(use: false);
    expect(memory.credentials, isNull);
    verify(() => authBloc.add(const AuthLoggedIn(_user))).called(1);
  });

  test('without a sensor there is no question', () async {
    when(() => biometrics.isAvailable()).thenAnswer((_) async => false);
    final login = cubit(withBiometrics: biometrics);
    await login.submit(email: 'ana@ottos.test', password: 'secret');
    expect(login.state.offerBiometrics, isFalse);
    verify(() => authBloc.add(const AuthLoggedIn(_user))).called(1);
  });

  test('the fingerprint logs in with the saved credentials', () async {
    memory.credentials = (email: 'ana@ottos.test', password: 'secret');
    final login = cubit(withBiometrics: biometrics);
    await login.submitWithBiometrics();
    verify(() => auth.login(email: 'ana@ottos.test', password: 'secret')).called(1);
    verify(() => authBloc.add(const AuthLoggedIn(_user))).called(1);
  });

  test('a failed fingerprint does not log in', () async {
    memory.credentials = (email: 'ana@ottos.test', password: 'secret');
    when(() => biometrics.authenticate(any())).thenAnswer((_) async => false);
    await cubit(withBiometrics: biometrics).submitWithBiometrics();
    verifyNever(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('a changed password forgets the saved credentials', () async {
    memory.credentials = (email: 'ana@ottos.test', password: 'old');
    when(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const ApiException(CoreTexts.invalidCredentials, statusCode: 401, code: 'INVALID_CREDENTIALS'));
    final login = cubit(withBiometrics: biometrics);
    await login.submitWithBiometrics();
    expect(memory.credentials, isNull);
    expect(login.state.error, CoreTexts.biometricOutdated);
    expect(login.state.biometricsReady, isFalse);
  });

  test('no connection keeps the saved credentials', () async {
    memory.credentials = (email: 'ana@ottos.test', password: 'secret');
    when(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const ApiException(CoreTexts.networkError));
    final login = cubit(withBiometrics: biometrics);
    await login.submitWithBiometrics();
    expect(memory.credentials, isNotNull);
    expect(login.state.error, CoreTexts.networkError);
  });
}
