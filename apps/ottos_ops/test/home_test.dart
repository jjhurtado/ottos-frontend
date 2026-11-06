import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/app/router.dart';
import 'package:ottos_ops/features/home/view/home_page.dart';
import 'package:ottos_ops/features/remittances/view/remittance_list_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockAuth extends Mock implements AuthRepository {}

final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'initial': true, 'position': 10},
    {'code': 'ASSIGNED', 'name': 'Asignada', 'position': 20},
    {'code': 'DELIVERED', 'name': 'Entregada', 'isFinal': true, 'position': 30},
  ],
});

const _summary = RemittanceSummary(
  openByStatus: [
    StatusCount(code: 'PAID', name: 'Pagada', count: 2),
    StatusCount(code: 'ASSIGNED', name: 'Asignada', count: 2),
  ],
  late: 2,
  incident: 2,
  review: 2,
);

const _totals = PendingTotals(
  toDeliver: [
    PendingAmount(currency: 'CUP', remittances: 2, amount: 76000),
    PendingAmount(currency: 'USD', remittances: 3, amount: 450),
  ],
  toCollect: [PendingAmount(currency: 'USD', remittances: 1, amount: 200)],
);

void main() {
  late _MockRemittances remittances;
  late _MockCash cash;

  setUpAll(() async {
    registerFallbackValue(const RemittanceFilter());
    await OttosLocalization.initialize();
  });

  setUp(() {
    remittances = _MockRemittances();
    cash = _MockCash();
    when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
    when(() => remittances.summary()).thenAnswer((_) async => _summary);
    when(() => remittances.pendingTotals()).thenAnswer((_) async => _totals);
    when(() => cash.exchanges(review: true, size: 1))
        .thenAnswer((_) async => const PageResult<CurrencyExchange>(items: [], page: 0, size: 1, totalItems: 1));
  });

  AuthBloc loggedIn(Set<String> permissions) {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(
            id: 'u1',
            email: 'ventas@ottos.test',
            name: 'Ventas',
            type: '',
            roles: const [],
            permissions: permissions,
          ),
        ),
      );
    addTearDown(authBloc.close);
    return authBloc;
  }

  /// The Home at `/`, and the list it links to showing the address it was opened with.
  Future<void> pump(WidgetTester tester, Set<String> permissions) async {
    final authBloc = loggedIn(permissions);
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: HomePage()),
        ),
        GoRoute(
          path: '/remittances',
          builder: (_, state) => Scaffold(body: Text('list ${state.uri}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceRepository>.value(value: remittances),
          RepositoryProvider<CashRepository>.value(value: cash),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const sales = {Permissions.remittancesRead, Permissions.cashRead};

  testWidgets('home shows the counters to a user who also sees the cash', (tester) async {
    await pump(tester, sales);

    expect(tester.takeException(), isNull);
    expect(find.text('Pagada'), findsOneWidget);
    verify(() => cash.exchanges(review: true, size: 1)).called(1);
  });

  group('REQ-021 money pending', () {
    testWidgets('AC-1.1 AC-1.2: to deliver and to collect, by currency with their counts', (tester) async {
      await pump(tester, sales);

      expect(find.text(CoreTexts.pendingToDeliver), findsOneWidget);
      expect(find.text(CoreTexts.pendingToCollect), findsOneWidget);
      expect(find.text(Formatters.money(76000, 'CUP')), findsOneWidget);
      expect(find.text(Formatters.money(450, 'USD')), findsOneWidget);
      expect(find.text(Formatters.money(200, 'USD')), findsOneWidget);
      expect(find.text('3 remesas'), findsOneWidget);
      expect(find.text('1 remesa'), findsOneWidget);
    });

    testWidgets('AC-1.5: nothing open says nothing is pending', (tester) async {
      when(() => remittances.pendingTotals()).thenAnswer((_) async => const PendingTotals());

      await pump(tester, sales);

      expect(find.text(CoreTexts.nothingPending), findsNWidgets(2));
    });

    testWidgets('AC-1.6: without remittances:read there is no block and nothing is asked', (tester) async {
      await pump(tester, const {Permissions.cashRead});

      expect(find.text(CoreTexts.pendingToDeliver), findsNothing);
      verifyNever(() => remittances.pendingTotals());
    });

    testWidgets('AC-1.7 BR-8: a tile opens the list with the same filter and its type', (tester) async {
      await pump(tester, sales);

      await tester.tap(find.text(CoreTexts.pendingToCollect));
      await tester.pumpAndSettle();

      expect(find.text('list /remittances?status=PAID%2CASSIGNED&voided=false&type=PICKUP'), findsOneWidget);
    });

    testWidgets('AC-1.8: a failure shows an error with retry and the counters still work', (tester) async {
      when(() => remittances.pendingTotals()).thenThrow(const ApiException('Sin conexión'));

      await pump(tester, sales);

      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Pagada'), findsOneWidget, reason: 'the counters do not depend on the totals');

      when(() => remittances.pendingTotals()).thenAnswer((_) async => _totals);
      await tester.tap(find.text(CoreTexts.retry));
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión'), findsNothing);
      expect(find.text(Formatters.money(76000, 'CUP')), findsOneWidget);
    });
  });

  group('REQ-021 the list opened from a tile', () {
    test('AC-1.7 BR-8: the address gives back the filter of the tile', () {
      expect(
        filterFromQuery({'status': 'PAID,ASSIGNED', 'voided': 'false', 'type': 'DELIVERY'}),
        const RemittanceFilter(status: 'PAID,ASSIGNED', voided: false, type: RemittanceType.delivery),
      );
      expect(filterFromQuery(const {}), const RemittanceFilter());
    });

    testWidgets('AC-1.7: several statuses show as «Pendientes» in the status filter', (tester) async {
      when(
        () => remittances.search(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => const PageResult<Remittance>(items: [], page: 0, size: 20, totalItems: 0));
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const filter = RemittanceFilter(status: 'PAID,ASSIGNED', voided: false, type: RemittanceType.pickup);

      await tester.pumpWidget(
        RepositoryProvider<RemittanceRepository>.value(
          value: remittances,
          child: BlocProvider.value(
            value: loggedIn(const {Permissions.remittancesRead}),
            child: const MaterialApp(
              home: Scaffold(body: RemittanceListPage(initialFilter: filter)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(OpsTexts.pendingStatuses), findsOneWidget);
      verify(() => remittances.search(filter, page: 0, size: any(named: 'size'))).called(1);
    });
  });
}
