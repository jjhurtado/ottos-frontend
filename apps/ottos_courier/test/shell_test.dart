import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/shell/courier_shell.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _courier = CurrentUser(
  id: 'c1',
  email: 'c1@ottos.test',
  name: 'Courier 1',
  type: '',
  roles: [],
  permissions: {Permissions.remittancesReadAssigned},
);

void main() {
  late _MockAuthRepository authRepository;
  late AuthBloc authBloc;

  setUp(() {
    authRepository = _MockAuthRepository();
    when(() => authRepository.sessionExpired).thenAnswer((_) => const Stream.empty());
    when(() => authRepository.logout()).thenAnswer((_) async {});
    authBloc = AuthBloc(authRepository: authRepository, accessPolicy: (_) => true)..add(const AuthLoggedIn(_courier));
  });

  tearDown(() => authBloc.close());

  Future<void> openAccountMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: authRepository,
        child: BlocProvider.value(
          value: authBloc,
          child: const MaterialApp(
            home: CourierShell(location: '/', child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip(CourierTexts.account));
    await tester.pumpAndSettle();
  }

  testWidgets('shows who is logged in, in the bar and in the menu', (tester) async {
    await openAccountMenu(tester);

    // Once in the app bar, once at the top of the menu.
    expect(find.text('Courier 1'), findsNWidgets(2));
  });

  testWidgets('the account menu changes the password', (tester) async {
    await openAccountMenu(tester);

    await tester.tap(find.text(CoreTexts.changePassword));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(CoreTexts.changePasswordHelp), findsOneWidget);
  });

  testWidgets('the account menu logs out', (tester) async {
    await openAccountMenu(tester);

    await tester.tap(find.text(CoreTexts.logout));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

    expect(authBloc.state.isAuthenticated, isFalse);
    verify(() => authRepository.logout()).called(1);
  });
}
