import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/cubit/assigned_cubit.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/features/cash/cubit/cash_cubit.dart';
import 'package:ottos_courier/features/cash/view/cash_page.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:ottos_courier/offline/remittance_source.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockSource extends Mock implements RemittanceSource {}

class _MockCash extends Mock implements CashRepository {}

class _MockSync extends Mock implements SyncRepository {}

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
  toDeliver: [PendingAmount(currency: 'USD', remittances: 7, amount: 1500)],
  toCollect: [PendingAmount(currency: 'USD', remittances: 2, amount: 300)],
);

const _sales = {Permissions.remittancesRead, Permissions.remittancesCreate};

const _courier = {Permissions.remittancesReadAssigned, Permissions.remittancesDeliver, Permissions.cashReadOwn};

const _statement = CourierStatement(
  cash: CourierCash(
    courierId: 'u1',
    name: 'Luis',
    balances: [Balance(currency: 'USD', amount: 500)],
    negative: false,
  ),
  movements: [],
);

/// REQ-021 US-2 and US-3: the money pending in the app.
void main() {
  late _MockRemittances repository;
  late _MockSource source;
  late _MockCash cash;

  setUpAll(() async {
    sqfliteFfiInit();
    registerFallbackValue(<SyncAction>[]);
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
  });

  Future<void> pump(WidgetTester tester, Set<String> permissions, Widget page) async {
    tester.view.physicalSize = const Size(400, 2000);
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
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: Scaffold(body: page),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('US-2 sales on SCR-19', () {
    test('AC-2.1 BR-5: the cubit keeps the business totals with the list', () async {
      final cubit = AssignedCubit(source: source, pendingTotals: repository.pendingTotals);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AssignedStatus.success);
      expect(cubit.state.totals, _business);
    });

    test('the totals fail on their own: the list still loads', () async {
      when(() => repository.pendingTotals()).thenThrow(const ApiException('Error'));
      final cubit = AssignedCubit(source: source, pendingTotals: repository.pendingTotals);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, AssignedStatus.success);
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.totals, isNull);
    });

    testWidgets('AC-2.1 AC-2.2: sales see both totals above the list, as the panel', (tester) async {
      await pump(tester, _sales, const AssignedPage());

      expect(find.text(CoreTexts.pendingToDeliver), findsOneWidget);
      expect(find.text(CoreTexts.pendingToCollect), findsOneWidget);
      expect(find.text(Formatters.money(1500, 'USD')), findsOneWidget);
      expect(find.text('7 remesas'), findsOneWidget);
      final tiles = tester.getRect(find.byType(PendingTotalsTiles));
      expect(tiles.bottom, lessThan(tester.getRect(find.text('OT-a')).top), reason: 'above the list');
    });

    testWidgets('AC-2.3: without connection the totals hide with the list', (tester) async {
      when(() => source.list()).thenThrow(_offline);

      await pump(tester, _sales, const AssignedPage());

      expect(find.byType(PendingTotalsTiles), findsNothing);
      expect(find.text(CoreTexts.networkError), findsOneWidget);
    });

    testWidgets('AC-3.1: a courier has no business totals on SCR-19 and the server is not asked', (tester) async {
      when(() => source.canSearch).thenReturn(false);

      await pump(tester, _courier, const AssignedPage());

      expect(find.byType(PendingTotalsTiles), findsNothing);
      verifyNever(() => repository.pendingTotals());
    });
  });

  group('US-3 the courier in «Mi caja»', () {
    testWidgets('AC-3.1 AC-3.2: their own totals by currency, summed from their remittances', (tester) async {
      when(() => cash.myStatement()).thenAnswer((_) async => _statement);
      when(() => source.list()).thenAnswer(
        (_) async => [
          Remittance.fromJson(_json('a', cash: 100)),
          Remittance.fromJson(_json('b', cash: 38000, currency: 'CUP')),
          Remittance.fromJson(_json('c', type: 'PICKUP', cash: 250)),
        ],
      );

      await pump(tester, _courier, const CashPage());

      expect(find.text(CourierTexts.ownToDeliver), findsOneWidget);
      expect(find.text(CourierTexts.ownToCollect), findsOneWidget);
      expect(find.text(Formatters.money(38000, 'CUP')), findsOneWidget);
      expect(find.text(Formatters.money(100, 'USD')), findsOneWidget);
      expect(find.text(Formatters.money(250, 'USD')), findsOneWidget);
      verifyNever(() => repository.pendingTotals());
    });

    testWidgets('sales have no own totals in «Caja»', (tester) async {
      when(() => cash.couriers()).thenAnswer((_) async => const []);

      await pump(tester, const {Permissions.remittancesRead, Permissions.cashRead}, const CashPage());

      expect(find.byType(PendingTotalsTiles), findsNothing);
      verifyNever(() => source.list());
    });

    group('offline (BR-7)', () {
      late OfflineStore store;
      late _MockSync server;
      late SyncCubit sync;

      setUp(() async {
        store = await OfflineStore.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
        server = _MockSync();
        when(() => server.state(since: any(named: 'since'))).thenAnswer(
          (_) async => SyncState(
            serverTime: 't1',
            full: true,
            remittances: [
              _json('a', cash: 100),
              _json('b', cash: 40),
              _json('c', type: 'PICKUP', cash: 250),
            ],
            cash: const {
              'cash': {'courierId': 'u1', 'name': 'Luis', 'balances': []},
              'movements': [],
            },
          ),
        );
        sync = SyncCubit(store: store, sync: server);
        await sync.start('u1');
      });

      tearDown(() async {
        await sync.close();
        await store.close();
      });

      test('AC-3.3 AC-3.4: one completed without connection stops counting, from the phone alone', () async {
        final offlineSource = OfflineSource(sync: sync);
        when(() => server.send(any())).thenThrow(_offline);
        when(() => server.state(since: any(named: 'since'))).thenThrow(_offline);

        await offlineSource.deliver(Remittance.fromJson(_json('a')));
        final cubit = CashCubit(
          cash: cash,
          ownCash: true,
          couriersCash: false,
          ownStatement: sync.cash,
          assigned: offlineSource.list,
        );
        addTearDown(cubit.close);
        await cubit.load();

        expect(cubit.state.status, CashStatus.success);
        expect(cubit.state.pending?.toDeliver, const [PendingAmount(currency: 'USD', remittances: 1, amount: 40)]);
        expect(cubit.state.pending?.toCollect, const [PendingAmount(currency: 'USD', remittances: 1, amount: 250)]);
        verifyNever(() => repository.pendingTotals());
      });
    });
  });
}
