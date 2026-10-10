import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockAuth extends Mock implements AuthRepository {}

const _user = CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: [], permissions: {});

void main() {
  late _MockAuth auth;
  late AuthBloc authBloc;

  setUp(() {
    auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    when(() => auth.logout()).thenAnswer((_) async {});
    authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)..add(const AuthLoggedIn(_user));
  });

  tearDown(() => authBloc.close());

  test('passwords need 8 to 72 characters', () {
    expect(passwordError(''), CoreTexts.requiredField);
    expect(passwordError('1234567'), CoreTexts.passwordTooShort);
    expect(passwordError('12345678'), isNull);
    expect(passwordError('x' * 73), CoreTexts.passwordTooLong);
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: auth,
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    TextButton(onPressed: () => showChangePasswordDialog(context), child: const Text('open')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    required String current,
    required String next,
    required String repeat,
  }) async {
    await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.currentPassword), current);
    await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.newPassword), next);
    await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.repeatPassword), repeat);
    await tester.tap(find.widgetWithText(FilledButton, CoreTexts.changePassword));
    await tester.pumpAndSettle();
  }

  testWidgets('checks the new password before sending it', (tester) async {
    await openDialog(tester);

    await fill(tester, current: 'old-pass-1', next: 'old-pass-1', repeat: 'other');

    expect(find.text(CoreTexts.samePassword), findsOneWidget);
    expect(find.text(CoreTexts.passwordsDiffer), findsOneWidget);
    verifyNever(
      () => auth.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });

  testWidgets('shows a wrong current password inside the dialog', (tester) async {
    when(
      () => auth.changePassword(currentPassword: 'wrong-pass', newPassword: 'new-pass-2'),
    ).thenThrow(ApiException(CoreTexts.errorCodes['INCORRECT_CURRENT_PASSWORD']!, code: 'INCORRECT_CURRENT_PASSWORD'));
    await openDialog(tester);

    await fill(tester, current: 'wrong-pass', next: 'new-pass-2', repeat: 'new-pass-2');

    expect(find.text(CoreTexts.errorCodes['INCORRECT_CURRENT_PASSWORD']!), findsOneWidget);
    expect(authBloc.state.isAuthenticated, isTrue);
  });

  testWidgets('logs out after a change, telling the login page why', (tester) async {
    when(() => auth.changePassword(currentPassword: 'old-pass-1', newPassword: 'new-pass-2')).thenAnswer((_) async {});
    await openDialog(tester);

    await fill(tester, current: 'old-pass-1', next: 'new-pass-2', repeat: 'new-pass-2');
    // The bloc was created outside the test's fake clock: let its logout run on the real one.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

    expect(find.byType(AlertDialog), findsNothing);
    expect(authBloc.state.isAuthenticated, isFalse);
    expect(authBloc.state.passwordChanged, isTrue);
    verify(() => auth.logout()).called(1);
  });
}
