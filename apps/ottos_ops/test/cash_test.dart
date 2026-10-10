import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/cash/cubit/cash_overview_cubit.dart';
import 'package:ottos_ops/features/cash/view/cash_page.dart';

class _MockCash extends Mock implements CashRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _balances = [Balance(currency: 'CUP', amount: 5000), Balance(currency: 'USD', amount: 1584)];
const _couriers = [
  CourierCash(
    courierId: 'k2',
    name: 'luis',
    balances: [Balance(currency: 'CUP', amount: 100)],
    negative: false,
  ),
  CourierCash(
    courierId: 'k1',
    name: 'Ana',
    balances: [Balance(currency: 'CUP', amount: -82000)],
    negative: true,
  ),
];
final _movements = [
  CashMovement.fromJson(const {
    'id': 'm1',
    'type': 'COURIER_FUNDING',
    'fromType': 'BUSINESS',
    'toType': 'COURIER',
    'toOwnerId': 'k1',
    'amount': 100,
    'signedAmount': -100,
    'currency': 'USD',
    'occurredAt': '2026-10-09T10:00:00Z',
  }),
];

void main() {
  late _MockCash cash;

  setUp(() {
    cash = _MockCash();
    when(() => cash.businessBalances()).thenAnswer((_) async => _balances);
    when(() => cash.couriers()).thenAnswer((_) async => _couriers);
    when(() => cash.businessMovements()).thenAnswer((_) async => _movements);
  });

  group('cubit', () {
    test('loads balances, couriers by name and movements', () async {
      final cubit = CashOverviewCubit(cash: cash);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, CashOverviewStatus.success);
      expect(cubit.state.couriers.map((c) => c.name), ['Ana', 'luis']);
      expect(cubit.state.movements.single.toOwnerId, 'k1');
      expect(cubit.state.currencies, ['USD', 'CUP']);
    });

    test('offers USD and CUP while the box is empty', () {
      expect(const CashOverviewState().currencies, ['USD', 'CUP']);
    });

    test('keeps showing the page while it refreshes', () async {
      final cubit = CashOverviewCubit(cash: cash);
      addTearDown(cubit.close);
      await cubit.load();
      when(() => cash.businessBalances()).thenAnswer((_) async => const [Balance(currency: 'USD', amount: 1684)]);
      final states = <CashOverviewState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(states.map((s) => s.status), [CashOverviewStatus.success]);
      expect(states.single.balances.single.amount, 1684);
    });

    test('reports a failed load', () async {
      when(() => cash.couriers()).thenThrow(const ApiException(CoreTexts.forbidden, statusCode: 403));
      final cubit = CashOverviewCubit(cash: cash);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, CashOverviewStatus.failure);
      expect(cubit.state.error, CoreTexts.forbidden);
    });
  });

  group('page', () {
    Future<void> pumpCash(WidgetTester tester, Set<String> permissions) async {
      final auth = _MockAuth();
      when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
      final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
        ..add(
          AuthLoggedIn(
            CurrentUser(
              id: 'u1',
              email: 'u@ottos.test',
              name: 'U',
              type: '',
              roles: const [],
              permissions: permissions,
            ),
          ),
        );
      addTearDown(authBloc.close);
      await OttosLocalization.initialize();
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepositoryProvider<CashRepository>.value(
          value: cash,
          child: BlocProvider.value(
            value: authBloc,
            child: MaterialApp(
              localizationsDelegates: OttosLocalization.delegates,
              supportedLocales: OttosLocalization.supportedLocales,
              home: const Scaffold(body: CashPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows balances, couriers and movements, with every action for an admin', (tester) async {
      await pumpCash(tester, {Permissions.cashRead, Permissions.cashWrite, Permissions.cashAdjust});

      expect(find.text('USD'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('${OpsTexts.movementTitle(CashMovementType.courierFunding)} · Ana'), findsOneWidget);
      expect(find.text(OpsTexts.deposit), findsOneWidget);
      expect(find.text(OpsTexts.withdraw), findsOneWidget);
      expect(find.text(OpsTexts.fund), findsNWidgets(2));
      expect(find.byTooltip(OpsTexts.courierOwes), findsOneWidget);
    });

    testWidgets('a read-only user sees no actions', (tester) async {
      await pumpCash(tester, {Permissions.cashRead});

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text(OpsTexts.deposit), findsNothing);
      expect(find.text(OpsTexts.fund), findsNothing);
    });
  });
}
