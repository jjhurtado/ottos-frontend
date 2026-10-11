import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/home/view/home_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockAuth extends Mock implements AuthRepository {}

void main() {
  setUpAll(() async {
    registerFallbackValue(const RemittanceFilter());
    await OttosLocalization.initialize();
  });

  testWidgets('home shows the counters to a user who also sees the cash', (tester) async {
    final remittances = _MockRemittances();
    final cash = _MockCash();
    when(() => remittances.workflow()).thenAnswer(
      (_) async => Workflow.fromJson({
        'statuses': [
          {'code': 'PAID', 'name': 'Pagada', 'initial': true},
          {'code': 'DELIVERED', 'name': 'Entregada', 'isFinal': true},
        ],
      }),
    );
    when(() => remittances.search(any(), size: 1))
        .thenAnswer((_) async => const PageResult<Remittance>(items: [], page: 0, size: 1, totalItems: 2));
    when(() => cash.exchanges(review: true, size: 1))
        .thenAnswer((_) async => const PageResult<CurrencyExchange>(items: [], page: 0, size: 1, totalItems: 1));
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        const AuthLoggedIn(
          CurrentUser(
            id: 'u1',
            email: 'ventas@ottos.test',
            name: 'Ventas',
            type: '',
            roles: [],
            permissions: {Permissions.remittancesRead, Permissions.cashRead},
          ),
        ),
      );
    addTearDown(authBloc.close);
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceRepository>.value(value: remittances),
          RepositoryProvider<CashRepository>.value(value: cash),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: const Scaffold(body: HomePage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pagada'), findsOneWidget);
    verify(() => cash.exchanges(review: true, size: 1)).called(1);
  });
}
