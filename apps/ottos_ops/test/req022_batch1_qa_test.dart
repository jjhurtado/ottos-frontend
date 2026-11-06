import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/router.dart';
import 'package:ottos_ops/features/customers/cubit/customer_detail_cubit.dart';
import 'package:ottos_ops/features/home/cubit/home_cubit.dart';
import 'package:ottos_ops/features/home/view/home_page.dart';
import 'package:ottos_ops/features/remittances/view/new_remittance_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

class _MockAuth extends Mock implements AuthRepository {}

final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'initial': true, 'position': 10},
    {'code': 'ASSIGNED', 'name': 'Asignada', 'position': 20},
    {'code': 'DELIVERED', 'name': 'Entregada', 'isFinal': true, 'position': 30},
  ],
});

PageResult<T> _count<T>(int total) => PageResult<T>(items: const [], page: 0, size: 1, totalItems: total);

AuthBloc _loggedIn(Set<String> permissions) {
  final auth = _MockAuth();
  when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
  final bloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
    ..add(
      AuthLoggedIn(
        CurrentUser(id: 'u1', email: 'qa@ottos.test', name: 'QA', type: '', roles: const [], permissions: permissions),
      ),
    );
  addTearDown(bloc.close);
  return bloc;
}

/// REQ-022 batch 1, tester's checks of the panel (expected results from 03-implementation.md and rc.11 behaviour).
void main() {
  setUpAll(() async {
    registerFallbackValue(const RemittanceFilter());
    await OttosLocalization.initialize();
  });

  group('Home (OPT-F2 and voided tiles)', () {
    late _MockRemittances remittances;
    late _MockCash cash;

    setUp(() {
      remittances = _MockRemittances();
      cash = _MockCash();
      when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
      when(() => remittances.search(any(), size: 1)).thenAnswer((_) async => _count(4));
      when(() => remittances.pendingTotals()).thenAnswer((_) async => const PendingTotals());
      when(() => cash.exchanges(review: true, size: 1)).thenAnswer((_) async => _count(1));
    });

    test('OPT-F2 (slow money pending): the counters show without waiting for it', () async {
      final pending = Completer<PendingTotals>();
      when(() => remittances.pendingTotals()).thenAnswer((_) => pending.future);
      final cubit = HomeCubit(remittances: remittances, cash: cash);
      addTearDown(cubit.close);

      final load = cubit.load();
      await pumpEventQueue();

      expect(cubit.state.status, HomeStatus.success);
      expect(cubit.state.openByStatus.map((item) => item.count), [4, 4]);
      expect(cubit.state.pending, isNull);
      expect(cubit.state.pendingError, isNull);
      pending.complete(const PendingTotals());
      await load;
      expect(cubit.state.pending, const PendingTotals());
    });

    test('OPT-F2 (retry of the money pending alone): the counters are not asked again', () async {
      when(() => remittances.pendingTotals()).thenThrow(const ApiException('Sin totales'));
      final cubit = HomeCubit(remittances: remittances, cash: cash);
      addTearDown(cubit.close);
      await cubit.load();
      clearInteractions(remittances);
      when(() => remittances.pendingTotals()).thenAnswer((_) async => const PendingTotals());

      await cubit.loadPending();

      expect(cubit.state.status, HomeStatus.success);
      expect(cubit.state.pending, const PendingTotals());
      expect(cubit.state.pendingError, isNull);
      verifyNever(() => remittances.search(any(), size: 1));
    });

    testWidgets('voided tiles: a status tile opens the list without voided remittances', (tester) async {
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
            value: _loggedIn({Permissions.remittancesRead}),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: OttosLocalization.delegates,
              supportedLocales: OttosLocalization.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pagada'));
      await tester.pumpAndSettle();

      final shown = tester.widget<Text>(find.textContaining('list ')).data!;
      final uri = Uri.parse(shown.substring('list '.length));
      expect(uri.path, '/remittances');
      final filter = filterFromQuery(uri.queryParameters);
      expect(filter.status, 'PAID');
      expect(filter.voided, isFalse);
    });
  });

  group('customer detail (OPT-F2)', () {
    late _MockCustomers customers;

    setUp(() {
      customers = _MockCustomers();
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const []);
    });

    test('OPT-F2 (numbers fail): the customer still shows, without numbers', () async {
      when(() => customers.get('c1'))
          .thenAnswer((_) async => const Customer(id: 'c1', fullName: 'Cliente Prueba', phone: '+13055550101'));
      when(() => customers.stats('c1')).thenThrow(const ApiException('Error'));
      final cubit = CustomerDetailCubit(customers: customers, id: 'c1');
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, CustomerDetailStatus.success);
      expect(cubit.state.customer?.id, 'c1');
      expect(cubit.state.stats, isNull);
    });

    test('OPT-F2 (customer and numbers fail): the error shows, nothing escapes', () async {
      when(() => customers.get('c1')).thenThrow(const ApiException('No encontrado'));
      when(() => customers.stats('c1')).thenAnswer((_) async => throw const ApiException('Error'));
      final cubit = CustomerDetailCubit(customers: customers, id: 'c1');
      addTearDown(cubit.close);

      await cubit.load();
      await pumpEventQueue();

      expect(cubit.state.status, CustomerDetailStatus.failure);
      expect(cubit.state.error, 'No encontrado');
    });
  });

  group('new remittance from a customer (OPT-F2)', () {
    testWidgets('OPT-F2 (currencies fail before the customer arrives): the error and retry stay on screen', (
      tester,
    ) async {
      final customers = _MockCustomers();
      final rates = _MockRates();
      final customer = Completer<Customer>();
      when(() => customers.get('c1')).thenAnswer((_) => customer.future);
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const []);
      when(() => rates.corridors()).thenThrow(const ApiException('Sin conexión'));
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<RemittanceRepository>.value(value: _MockRemittances()),
            RepositoryProvider<CustomerRepository>.value(value: customers),
            RepositoryProvider<RateRepository>.value(value: rates),
          ],
          child: BlocProvider.value(
            value: _loggedIn({Permissions.remittancesCreate, Permissions.ratesRead, Permissions.customersRead}),
            child: MaterialApp(
              localizationsDelegates: OttosLocalization.delegates,
              supportedLocales: OttosLocalization.supportedLocales,
              home: const Scaffold(body: NewRemittancePage(initialCustomerId: 'c1')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);

      customer.complete(const Customer(id: 'c1', fullName: 'Cliente Prueba', phone: '+13055550101'));
      await tester.pumpAndSettle();
      // A window resize rebuilds the page with the cubit's current state.
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text(CoreTexts.retry), findsOneWidget);
    });
  });
}
