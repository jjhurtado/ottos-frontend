import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/app/router.dart';
import 'package:ottos_ops/features/cash/cubit/movement_ledger_cubit.dart';
import 'package:ottos_ops/features/cash/view/courier_cash_page.dart';
import 'package:ottos_ops/features/cash/view/movement_ledger.dart';
import 'package:ottos_ops/features/cash/view/movement_tile.dart';
import 'package:ottos_ops/features/remittances/view/remittance_detail_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockAuth extends Mock implements AuthRepository {}

final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'position': 10, 'initial': true},
    {'code': 'DELIVERED', 'name': 'Entregada', 'position': 30, 'isFinal': true},
  ],
  'transitions': const [],
});

final _delivered = Remittance(
  id: 'r1',
  code: 'OT-VKK5RX',
  type: RemittanceType.delivery,
  status: 'DELIVERED',
  statusName: 'Entregada',
  beneficiaryName: 'Rosa',
  completedAt: DateTime.utc(2026, 11, 12, 15),
  completedByName: 'Luis',
);

CashMovement _movement(String id, {String? actorName, String? remittanceCode}) => CashMovement.fromJson({
  'id': id,
  'type': 'DELIVERY_PAYOUT',
  'amount': 10,
  'signedAmount': -10,
  'currency': 'USD',
  'occurredAt': '2026-11-12T15:00:00Z',
  'actorName': actorName,
  'remittanceId': remittanceCode == null ? null : 'r1',
  'remittanceCode': remittanceCode,
});

PageResult<CashMovement> _page(List<CashMovement> items, {int page = 0, int total = 0}) =>
    PageResult(items: items, page: page, size: 50, totalItems: total == 0 ? items.length : total);

Future<void> _pump(
  WidgetTester tester,
  Set<String> permissions,
  Widget child, {
  List<RepositoryProvider> repos = const [],
}) async {
  final auth = _MockAuth();
  when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
  final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
    ..add(
      AuthLoggedIn(
        CurrentUser(
          id: 'u1',
          email: 'u@ottos.test',
          name: 'U',
          type: 'STAFF',
          roles: const [],
          permissions: permissions,
        ),
      ),
    );
  addTearDown(authBloc.close);
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final app = BlocProvider.value(
    value: authBloc,
    child: MaterialApp(
      localizationsDelegates: OttosLocalization.delegates,
      supportedLocales: OttosLocalization.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpWidget(repos.isEmpty ? app : MultiRepositoryProvider(providers: repos, child: app));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await OttosLocalization.initialize();
    registerFallbackValue(const MovementFilter());
  });

  group('SCR-5 remittance detail', () {
    late _MockRemittances remittances;
    late _MockCash cash;

    setUp(() {
      remittances = _MockRemittances();
      cash = _MockCash();
      when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
      when(() => remittances.get('r1')).thenAnswer((_) async => _delivered);
      when(() => remittances.events('r1')).thenAnswer(
        (_) async => [
          RemittanceEvent(
            id: 'e1',
            type: 'CREATED',
            actorId: 'u2',
            actorName: 'Marta',
            occurredAt: DateTime.utc(2026, 11, 12),
          ),
          RemittanceEvent(id: 'e2', type: 'REVIEW_FLAGGED', occurredAt: DateTime.utc(2026, 11, 12, 1)),
        ],
      );
    });

    Future<void> pumpDetail(WidgetTester tester, Set<String> permissions) => _pump(
      tester,
      permissions,
      const RemittanceDetailPage(remittanceId: 'r1'),
      repos: [
        RepositoryProvider<RemittanceRepository>.value(value: remittances),
        RepositoryProvider<CashRepository>.value(value: cash),
      ],
    );

    testWidgets('REQ-024 AC-1.1: each history entry says who made it, or the system', (tester) async {
      await pumpDetail(tester, {Permissions.remittancesRead});

      expect(find.textContaining(CoreTexts.by('Marta')), findsOneWidget);
      expect(find.textContaining(CoreTexts.bySystem), findsOneWidget);
    });

    testWidgets('REQ-024 AC-1.2: the summary says who delivered it and when', (tester) async {
      await pumpDetail(tester, {Permissions.remittancesRead});

      expect(find.text(OpsTexts.completedBy(isPickup: false)), findsOneWidget);
      expect(find.text('Luis · ${Formatters.dateTime(_delivered.completedAt)}'), findsOneWidget);
    });

    testWidgets('REQ-025 AC-1.1: «Copiar» puts the text on the clipboard and says so', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpDetail(tester, {Permissions.remittancesRead, Permissions.remittancesShare});

      await tester.tap(find.text(CoreTexts.copy));
      await tester.pumpAndSettle();

      expect(copied, remittanceShareText(_delivered));
      expect(find.text(CoreTexts.remittanceCopied), findsOneWidget);
    });

    testWidgets('REQ-025 AC-1.3: without the permission there is no «Copiar»', (tester) async {
      await pumpDetail(tester, {Permissions.remittancesRead});

      expect(find.text(CoreTexts.copy), findsNothing);
    });

    testWidgets('REQ-024 AC-1.2: a pickup says who collected it', (tester) async {
      when(() => remittances.get('r1')).thenAnswer(
        (_) async => Remittance(
          id: 'r1',
          code: 'OT-2',
          type: RemittanceType.pickup,
          status: 'DELIVERED',
          statusName: 'Entregada',
          completedAt: DateTime.utc(2026, 11, 12, 15),
          completedByName: 'Pedro',
        ),
      );
      await pumpDetail(tester, {Permissions.remittancesRead});

      expect(find.text(OpsTexts.completedBy(isPickup: true)), findsOneWidget);
      expect(find.text('Pedro · ${Formatters.dateTime(DateTime.utc(2026, 11, 12, 15))}'), findsOneWidget);
    });

    testWidgets('REQ-025 AC-1.4: a voided remittance can still be copied, starting with ANULADA', (tester) async {
      const voided = Remittance(
        id: 'r1',
        code: 'OT-3',
        type: RemittanceType.delivery,
        status: 'PAID',
        statusName: 'Pagada',
        voided: Voided(reason: 'Duplicada'),
      );
      when(() => remittances.get('r1')).thenAnswer((_) async => voided);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpDetail(tester, {Permissions.remittancesRead, Permissions.remittancesShare});

      await tester.tap(find.text(CoreTexts.copy));
      await tester.pumpAndSettle();

      expect(copied!.split('\n').first, CoreTexts.shareVoided);
    });
  });

  group('SCR-11/SCR-12 movement ledger', () {
    late _MockCash cash;

    setUp(() => cash = _MockCash());

    test('REQ-024 AC-2.1: loads the next page and keeps the filter', () async {
      when(
        () => cash.businessMovements(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer(
        (invocation) async => _page([_movement('m1')], page: invocation.namedArguments[#page] as int, total: 120),
      );
      final cubit = MovementLedgerCubit(cash.businessMovements);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.load(page: 1);

      expect(cubit.state.result!.page, 1);
      verify(() => cash.businessMovements(const MovementFilter(), page: 1, size: 50)).called(1);
    });

    test('REQ-024 AC-2.2: a new filter restarts at the first page', () async {
      when(
        () => cash.businessMovements(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer(
        (invocation) async => _page([_movement('m1')], page: invocation.namedArguments[#page] as int, total: 120),
      );
      final cubit = MovementLedgerCubit(cash.businessMovements);
      addTearDown(cubit.close);
      await cubit.load(page: 2);

      const filter = MovementFilter(type: CashMovementType.deliveryPayout);
      await cubit.filter(filter);

      verify(() => cash.businessMovements(filter, page: 0, size: 50)).called(1);
      expect(cubit.state.filter, filter);
    });

    Future<void> pumpLedger(WidgetTester tester, {MovementFilter filter = const MovementFilter()}) async {
      final cubit = MovementLedgerCubit(cash.businessMovements);
      addTearDown(cubit.close);
      await cubit.filter(filter);
      await _pump(
        tester,
        {Permissions.cashRead},
        BlocProvider.value(
          value: cubit,
          child: const SingleChildScrollView(child: MovementLedger()),
        ),
      );
    }

    testWidgets('REQ-024 AC-2.3: a movement shows its author and remittance code, with the paging bar', (tester) async {
      when(
        () => cash.businessMovements(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => _page([_movement('m1', actorName: 'Ana', remittanceCode: 'OT-1')], total: 120));
      await pumpLedger(tester);

      expect(find.textContaining('Ana · OT-1'), findsOneWidget);
      expect(find.text(OpsTexts.pageOf(1, 1, 120)), findsOneWidget);
    });

    testWidgets('REQ-024 AC-2.4: nothing matches: says so and offers to clear the filters', (tester) async {
      when(
        () => cash.businessMovements(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => _page(const []));
      await pumpLedger(tester, filter: const MovementFilter(type: CashMovementType.businessDeposit));

      expect(find.text(OpsTexts.noMovementsFiltered), findsOneWidget);
      // One in the filter row, one under the message.
      expect(find.text(OpsTexts.clearFilters), findsNWidgets(2));
    });

    testWidgets('REQ-024 SCR-11: a failed load offers «Reintentar»', (tester) async {
      when(
        () => cash.businessMovements(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenThrow(const ApiException(CoreTexts.networkError));
      await pumpLedger(tester);

      expect(find.text(CoreTexts.networkError), findsOneWidget);
      expect(find.text(CoreTexts.retry), findsOneWidget);
    });

    test('CR-2: a late answer for an older filter is dropped', () async {
      final older = Completer<PageResult<CashMovement>>();
      final newer = Completer<PageResult<CashMovement>>();
      const deposits = MovementFilter(type: CashMovementType.businessDeposit);
      when(() => cash.businessMovements(const MovementFilter(), page: 0, size: 50)).thenAnswer((_) => older.future);
      when(() => cash.businessMovements(deposits, page: 0, size: 50)).thenAnswer((_) => newer.future);
      final cubit = MovementLedgerCubit(cash.businessMovements);
      addTearDown(cubit.close);

      final first = cubit.load();
      final second = cubit.filter(deposits);
      newer.complete(_page([_movement('deposit')]));
      await second;
      older.complete(_page([_movement('old')]));
      await first;

      expect(cubit.state.filter, deposits);
      expect(cubit.state.result!.items.single.id, 'deposit');
    });

    testWidgets('REQ-024 AC-2.2: choosing «Desde» in the filter row asks for that day from the first page', (
      tester,
    ) async {
      when(
        () => cash.businessMovements(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => _page([_movement('m1')]));
      await pumpLedger(tester);

      await tester.tap(find.text(OpsTexts.fromDate));
      await tester.pumpAndSettle();
      final ok = MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog))).okButtonLabel;
      await tester.tap(find.text(ok));
      await tester.pumpAndSettle();

      final filter =
          verify(() => cash.businessMovements(captureAny(), page: 0, size: 50)).captured.last as MovementFilter;
      final today = BusinessTime.today();
      expect([filter.from?.year, filter.from?.month, filter.from?.day], [today.year, today.month, today.day]);
      expect(filter.to, isNull);
      expect(find.text(OpsTexts.clearFilters), findsOneWidget);
    });

    testWidgets('REQ-024 AC-2.3: a tile shows courier, author, code, rate and note; tapping it opens SCR-5', (
      tester,
    ) async {
      final movement = CashMovement.fromJson(const {
        'id': 'm1',
        'type': 'COURIER_FUNDING',
        'amount': 100,
        'signedAmount': -100,
        'currency': 'CUP',
        'toType': 'COURIER',
        'toOwnerId': 'k1',
        'occurredAt': '2026-11-12T15:00:00Z',
        'actorName': 'Ana',
        'remittanceId': 'r1',
        'remittanceCode': 'OT-1',
        'rate': 410,
        'note': 'Para el lunes',
      });
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: OttosLocalization.delegates,
          supportedLocales: OttosLocalization.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: MovementTile(movement: movement, courierNames: const {'k1': 'Luis'}),
                ),
              ),
              GoRoute(path: Routes.remittance('r1'), builder: (_, _) => const Text('Detalle r1')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('${OpsTexts.movementTitle(CashMovementType.courierFunding)} · Luis'), findsOneWidget);
      final subtitle = [
        Formatters.dateTime(movement.occurredAt),
        'Ana',
        'OT-1',
        CoreTexts.exchangeRateValue(Formatters.money(410, null)),
        'Para el lunes',
      ].join(' · ');
      expect(find.text(subtitle), findsOneWidget);

      await tester.tap(find.byType(MovementTile));
      await tester.pumpAndSettle();
      expect(find.text('Detalle r1'), findsOneWidget);
    });

    testWidgets('REQ-024 AC-3.1: SCR-12 pages the courier\'s own ledger under unchanged balances', (tester) async {
      when(() => cash.courierStatement('k1')).thenAnswer(
        (_) async => const CourierStatement(
          cash: CourierCash(
            courierId: 'k1',
            name: 'Luis',
            balances: [Balance(currency: 'USD', amount: 300)],
            negative: false,
          ),
          movements: [],
        ),
      );
      when(
        () => cash.courierMovements(
          'k1',
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => _page([_movement('m1', actorName: 'Ana')], total: 75));
      await _pump(
        tester,
        {Permissions.cashRead},
        const CourierCashPage(courierId: 'k1'),
        repos: [RepositoryProvider<CashRepository>.value(value: cash)],
      );

      expect(find.text(Formatters.money(300, null)), findsOneWidget);
      expect(find.textContaining('Ana'), findsOneWidget);
      expect(find.text(OpsTexts.pageOf(1, 1, 75)), findsOneWidget);
      verify(() => cash.courierMovements('k1', const MovementFilter(), page: 0, size: 50)).called(1);
      verifyNever(
        () => cash.businessMovements(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      );
    });
  });
}
