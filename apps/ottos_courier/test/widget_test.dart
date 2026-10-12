import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/app.dart';
import 'package:ottos_courier/app/courier_texts.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

CurrentUser _user(Set<String> permissions) => CurrentUser(
  id: 'u1',
  email: 'c1@ottos.test',
  name: 'Courier 1',
  type: 'STAFF',
  roles: const [],
  permissions: permissions,
);

void main() {
  group('access policy', () {
    test('lets in couriers and sales', () {
      expect(CourierApp.canUseApp(_user({Permissions.remittancesReadAssigned})), isTrue);
      // Sales use the app during the day too.
      expect(CourierApp.canUseApp(_user({Permissions.remittancesRead})), isTrue);
      expect(CourierApp.canUseApp(_user({Permissions.usersRead, Permissions.rolesRead})), isFalse);
    });
  });

  group('login', () {
    late _MockAuthRepository authRepository;
    late AuthBloc authBloc;

    setUp(() {
      authRepository = _MockAuthRepository();
      when(() => authRepository.sessionExpired).thenAnswer((_) => const Stream.empty());
      when(() => authRepository.logout()).thenAnswer((_) async {});
      authBloc = AuthBloc(authRepository: authRepository, accessPolicy: CourierApp.canUseApp);
    });

    tearDown(() => authBloc.close());

    Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: authRepository),
          RepositoryProvider<AccessPolicy>.value(value: CourierApp.canUseApp),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: const MaterialApp(home: LoginPage(appName: CourierTexts.appName)),
        ),
      ),
    );

    Future<void> submit(WidgetTester tester, {required String email, required String password}) async {
      await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.email), email);
      await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.password), password);
      await tester.tap(find.text(CoreTexts.enter));
      await tester.pumpAndSettle();
    }

    testWidgets('validates the form before calling the API', (tester) async {
      await pumpLogin(tester);

      await submit(tester, email: 'not-an-email', password: '');

      expect(find.text(CoreTexts.emailInvalid), findsOneWidget);
      expect(find.text(CoreTexts.passwordRequired), findsOneWidget);
      verifyNever(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('shows the API error for wrong credentials', (tester) async {
      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const ApiException(CoreTexts.invalidCredentials, statusCode: 401));
      await pumpLogin(tester);

      await submit(tester, email: 'c1@ottos.test', password: 'wrong');

      expect(find.text(CoreTexts.invalidCredentials), findsOneWidget);
    });

    testWidgets('logs in a courier', (tester) async {
      final courier = _user({Permissions.remittancesReadAssigned});
      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => courier);
      await pumpLogin(tester);

      await submit(tester, email: 'c1@ottos.test', password: 'secret');

      expect(authBloc.state.user, courier);
      verifyNever(() => authRepository.logout());
    });

    testWidgets('rejects and logs out a user without access to the app', (tester) async {
      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _user({Permissions.usersRead}));
      await pumpLogin(tester);

      await submit(tester, email: 'sales@ottos.test', password: 'secret');

      expect(find.text(CoreTexts.noAccessToApp), findsOneWidget);
      expect(authBloc.state.isAuthenticated, isFalse);
      verify(() => authRepository.logout()).called(1);
    });
  });
}
