import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/cubit/assigned_cubit.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/features/cash/view/cash_page.dart';
import 'package:ottos_courier/offline/remittance_source.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockSource extends Mock implements RemittanceSource {}

class _MockCash extends Mock implements CashRepository {}

const _offline = ApiException(CoreTexts.networkError);

Map<String, dynamic> _json(String id, {String type = 'DELIVERY', num cash = 100, String currency = 'USD'}) => {
  'id': id,
  'code': 'OT-$id',
  'type': type,
  'status': 'ASSIGNED',
  'statusName': 'Asignada',
  'cashAmount': cash,
  'cashCurrency': currency,
};

const _business = PendingTotals(
  toDeliver: [PendingAmount(currency: 'CUP', remittances: 1234, amount: 987654321.99)],
  toCollect: [PendingAmount(currency: 'USD', remittances: 2, amount: 300)],
);

const _sales = {Permissions.remittancesRead, Permissions.remittancesCreate};

const _courier = {Permissions.remittancesReadAssigned, Permissions.remittancesDeliver, Permissions.cashReadOwn};

const _statement = CourierStatement(
  cash: CourierCash(
    courierId: 'u1',
    name: 'Repartidor',
    balances: [Balance(currency: 'USD', amount: 500)],
    negative: false,
  ),
  movements: [],
);

/// REQ-021, tester: edge cases of the money pending in the app (US-2, US-3).
void main() {
  late _MockRemittances repository;
  late _MockSource source;
  late _MockCash cash;

  setUpAll(() async {
    await OttosLocalization.initialize();
  });

  setUp(() {
    repository = _MockRemittances();
    cash = _MockCash();
    source = _MockSource();
    when(() => source.canSearch).thenReturn(true);
    when(() => source.canShowCompleted).thenReturn(true);
    when(() => source.completedAreLatest).thenReturn(false);
    when(() => source.list()).thenAnswer((_) async => [Remittance.fromJson(_json('a'))]);
    when(() => source.pendingIds()).thenAnswer((_) async => {});
    when(() => source.changes).thenAnswer((_) => const Stream.empty());
    when(() => repository.pendingTotals()).thenAnswer((_) async => _business);
    when(() => cash.myStatement()).thenAnswer((_) async => _statement);
  });

  Future<void> pump(WidgetTester tester, Set<String> permissions, Widget page, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: const [], permissions: permissions),
        ),
      );
    addTearDown(authBloc.close);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceSource>.value(value: source),
          RepositoryProvider<RemittanceRepository>.value(value: repository),
          RepositoryProvider<CashRepository>.value(value: cash),
          RepositoryProvider<SyncCubit?>.value(value: null),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            theme: OttosTheme.light(),
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(body: page),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('US-2 sales', () {
    testWidgets('AC-2.3 (connection lost after loading): a reload without connection hides the totals', (tester) async {
      await pump(tester, _sales, const AssignedPage());
      expect(find.byType(PendingTotalsTiles), findsOneWidget);

      when(() => source.list()).thenThrow(_offline);
      when(() => repository.pendingTotals()).thenThrow(_offline);
      await BlocProvider.of<AssignedCubit>(tester.element(find.text('OT-a'))).load();
      await tester.pumpAndSettle();

      expect(
        find.byType(PendingTotalsTiles),
        findsNothing,
        reason: 'Sales does not work offline: no figures from before (AC-2.3)',
      );
    });

    test('AC-2.2 (only the totals fail on a reload): no figure older than the panel is kept', () async {
      final cubit = AssignedCubit(source: source, pendingTotals: repository.pendingTotals);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.totals, _business);

      when(() => repository.pendingTotals()).thenThrow(const ApiException('Error'));
      await cubit.load();

      expect(cubit.state.status, AssignedStatus.success);
      expect(cubit.state.totals, isNull, reason: 'a failed reload must not show the figures of before (AC-2.2)');
    });

    testWidgets('AC-2.1 (390 wide, large amounts, text at 200%): the tiles render without overflow', (tester) async {
      await pump(tester, _sales, const AssignedPage(), textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text(Formatters.money(987654321.99, 'CUP')), findsOneWidget);
      expect(find.text('1234 remesas'), findsOneWidget);
    });

    testWidgets('AC-2.1 (contrast): the tiles above the list meet WCAG AA', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, _sales, const AssignedPage());

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });

  group('US-3 the courier in «Mi caja»', () {
    testWidgets('AC-3.1 (nothing assigned): both figures say nothing is pending', (tester) async {
      when(() => source.list()).thenAnswer((_) async => []);

      await pump(tester, _courier, const CashPage());

      expect(find.text(CourierTexts.ownToDeliver), findsOneWidget);
      expect(find.text(CourierTexts.ownToCollect), findsOneWidget);
      expect(find.text(CoreTexts.nothingPending), findsNWidgets(2));
    });

    testWidgets('AC-3.1 BR-2 (cents): the phone sum keeps the cents without float noise', (tester) async {
      when(() => source.list()).thenAnswer(
        (_) async => [
          Remittance.fromJson(_json('a', cash: 0.1)),
          Remittance.fromJson(_json('b', cash: 0.2)),
          Remittance.fromJson(_json('c', cash: 1000.05, currency: 'CUP')),
        ],
      );

      await pump(tester, _courier, const CashPage());

      expect(find.text(Formatters.money(0.3, 'USD')), findsOneWidget);
      expect(find.text('2 remesas'), findsOneWidget);
      expect(find.text(Formatters.money(1000.05, 'CUP')), findsOneWidget);
    });

    testWidgets('AC-3.1 (390 wide, text at 200%): «Mi caja» renders the figures without overflow', (tester) async {
      when(() => source.list()).thenAnswer(
        (_) async => [
          Remittance.fromJson(_json('a', cash: 987654321.99, currency: 'CUP')),
          Remittance.fromJson(_json('b', type: 'PICKUP', cash: 250)),
        ],
      );

      await pump(tester, _courier, const CashPage(), textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text(Formatters.money(987654321.99, 'CUP')), findsOneWidget);
    });
  });
}
