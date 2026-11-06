import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockMemory extends Mock implements LoginMemory {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockAuth auth;
  late _MockMemory memory;

  setUp(() {
    auth = _MockAuth();
    memory = _MockMemory();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    when(() => auth.logout()).thenAnswer((_) async {});
    when(() => memory.clearBiometricCredentials()).thenAnswer((_) async {});
  });

  AuthBloc bloc() => AuthBloc(authRepository: auth, accessPolicy: (_) => true, loginMemory: memory);

  group('logout', () {
    test('SEC-1: logout forgets the fingerprint login only when asked', () async {
      final keep = bloc()..add(const AuthLogoutRequested());
      await keep.stream.firstWhere((state) => !state.isAuthenticated);
      verifyNever(() => memory.clearBiometricCredentials());
      await keep.close();

      final forget = bloc()..add(const AuthLogoutRequested(forgetBiometricLogin: true));
      await forget.stream.firstWhere((state) => !state.isAuthenticated);
      verify(() => memory.clearBiometricCredentials()).called(1);
      await forget.close();
    });

    Future<AuthBloc> pump(WidgetTester tester, {String? warning, Future<void> Function()? beforeLogout}) async {
      final authBloc = bloc();
      addTearDown(authBloc.close);
      await tester.pumpWidget(
        RepositoryProvider<LoginMemory>.value(
          value: memory,
          child: BlocProvider.value(
            value: authBloc,
            child: MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => confirmLogout(context, warning: warning, beforeLogout: beforeLogout),
                  child: const Text('salir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('salir'));
      await tester.pumpAndSettle();
      return authBloc;
    }

    testWidgets('SEC-1: logout offers to forget the saved fingerprint login', (tester) async {
      when(() => memory.biometricEmail()).thenAnswer((_) async => 'ana@ottos.test');
      await pump(tester);

      expect(find.text(CoreTexts.forgetBiometricLogin('ana@ottos.test')), findsOneWidget);
      await tester.tap(find.text(CoreTexts.forgetBiometricLogin('ana@ottos.test')));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, CoreTexts.logout));
      await tester.pumpAndSettle();

      verify(() => memory.clearBiometricCredentials()).called(1);
      verify(() => auth.logout()).called(1);
    });

    testWidgets('SEC-1: leaving the box unticked keeps the fingerprint login', (tester) async {
      when(() => memory.biometricEmail()).thenAnswer((_) async => 'ana@ottos.test');
      await pump(tester);
      await tester.tap(find.widgetWithText(TextButton, CoreTexts.logout));
      await tester.pumpAndSettle();

      verifyNever(() => memory.clearBiometricCredentials());
      verify(() => auth.logout()).called(1);
    });

    testWidgets('cancelling does not log out nor run what goes before', (tester) async {
      when(() => memory.biometricEmail()).thenAnswer((_) async => 'ana@ottos.test');
      var before = 0;
      await pump(tester, beforeLogout: () async => before++);
      await tester.tap(find.text(CoreTexts.cancel));
      await tester.pumpAndSettle();

      expect(before, 0);
      verifyNever(() => auth.logout());
    });

    testWidgets('SEC-12: logout completes when clearing fails', (tester) async {
      when(() => memory.biometricEmail()).thenAnswer((_) async => null);
      final authBloc = await pump(tester, beforeLogout: () async => throw StateError('database is locked'));
      await tester.pumpAndSettle();

      verify(() => auth.logout()).called(1);
      expect(authBloc.state.isAuthenticated, isFalse);
    });

    testWidgets('without a saved fingerprint nor a warning it logs out at once', (tester) async {
      when(() => memory.biometricEmail()).thenAnswer((_) async => null);
      var before = 0;
      await pump(tester, beforeLogout: () async => before++);

      expect(find.byType(AlertDialog), findsNothing);
      expect(before, 1);
      verify(() => auth.logout()).called(1);
    });
  });

  group('start', () {
    const user = CurrentUser(id: 'u1', email: 'ana@ottos.test', name: 'Ana', type: 'STAFF', roles: [], permissions: {});

    test('SEC-1: legacy password removed at start', () async {
      when(() => memory.removeLegacyCredentials()).thenAnswer((_) async {});
      when(() => auth.restoreSession()).thenAnswer((_) async => user);
      final authBloc = bloc()..add(const AuthStarted());
      await authBloc.stream.firstWhere((state) => state.isAuthenticated);
      verify(() => memory.removeLegacyCredentials()).called(1);
      await authBloc.close();
    });

    test('SEC-1: a failure removing it does not stop the app from starting', () async {
      when(() => memory.removeLegacyCredentials()).thenThrow(PlatformException(code: 'STORAGE'));
      when(() => auth.restoreSession()).thenAnswer((_) async => user);
      final authBloc = bloc()..add(const AuthStarted());
      await authBloc.stream.firstWhere((state) => state.isAuthenticated);
      await authBloc.close();
    });
  });

  group('SecureLoginMemory', () {
    late _MockStorage plain;
    late _MockStorage bound;

    setUp(() {
      plain = _MockStorage();
      bound = _MockStorage();
      when(() => plain.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      when(
        () => plain.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => plain.delete(key: any(named: 'key'))).thenAnswer((_) async {});
      when(
        () => bound.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => bound.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    });

    SecureLoginMemory secure() =>
        SecureLoginMemory(storage: plain, biometricStorage: bound, platform: TargetPlatform.android);

    test('SEC-1: the password goes only to the storage bound to the biometric', () async {
      expect(await secure().saveBiometricCredentials('ana@ottos.test', 'secret'), isTrue);
      verify(
        () => bound.write(
          key: any(named: 'key'),
          value: 'secret',
        ),
      ).called(1);
      verifyNever(
        () => plain.write(
          key: any(named: 'key'),
          value: 'secret',
        ),
      );
      verify(
        () => plain.write(
          key: any(named: 'key'),
          value: 'ana@ottos.test',
        ),
      ).called(1);
    });

    test('SEC-1: a password saved before the binding is deleted', () async {
      await secure().removeLegacyCredentials();
      verify(() => plain.delete(key: 'ottos.login.biometric.password')).called(1);
      verify(() => plain.delete(key: 'ottos.login.biometric.email')).called(1);
    });

    test('SEC-1: the bound storage is tied to the biometric on Android and iOS', () {
      final android = SecureLoginMemory.boundStorage.aOptions.toMap();
      expect(android['enforceBiometrics'], 'true');
      expect(android['requireBiometricsPerOperation'], 'true');
      expect(android['biometricType'], AndroidBiometricType.strongBiometricOnly.name);
      final ios = SecureLoginMemory.boundStorage.iOptions.toMap();
      expect(ios['accessibility'], KeychainAccessibility.passcode.name);
      expect(ios['accessControlFlags'], contains(AccessControlFlag.biometryCurrentSet.name));
      expect(secure().promptsOnRead, isTrue);
    });

    test('SEC-1: a refused fingerprint keeps the saved login', () async {
      when(() => plain.read(key: 'ottos.login.biometric.account')).thenAnswer((_) async => 'ana@ottos.test');
      when(() => bound.read(key: any(named: 'key'))).thenThrow(PlatformException(code: 'AUTH_FAILED'));
      expect(await secure().biometricCredentials(), isNull);
      verifyNever(() => plain.delete(key: 'ottos.login.biometric.account'));
    });

    test('SEC-1: a key gone with a change of fingerprints forgets the saved login', () async {
      when(() => plain.read(key: 'ottos.login.biometric.account')).thenAnswer((_) async => 'ana@ottos.test');
      when(() => bound.read(key: any(named: 'key'))).thenAnswer((_) async => null);
      expect(await secure().biometricCredentials(), isNull);
      verify(() => plain.delete(key: 'ottos.login.biometric.account')).called(1);
    });
  });
}
