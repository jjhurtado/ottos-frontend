import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/app/router.dart';
import 'package:ottos_courier/features/cash/view/cash_page.dart';
import 'package:ottos_courier/features/cash/view/courier_cash_page.dart';
import 'package:ottos_courier/features/new_remittance/view/new_remittance_page.dart';
import 'package:ottos_courier/features/remittance/view/remittance_page.dart';
import 'package:ottos_courier/offline/remittance_source.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockAuth extends Mock implements AuthRepository {}

/// Sales during the day: every remittance, registering and assigning, and the couriers' cash.
const _sales = {
  Permissions.remittancesRead,
  Permissions.remittancesCreate,
  Permissions.remittancesAssign,
  Permissions.remittancesReportIncident,
  Permissions.cashRead,
  Permissions.cashWrite,
  Permissions.configurationRead,
  Permissions.customersRead,
};

const _courierPermissions = {
  Permissions.remittancesReadAssigned,
  Permissions.remittancesDeliver,
  Permissions.cashReadOwn,
};

final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'position': 10, 'initial': true},
    {'code': 'DELIVERED', 'name': 'Entregada', 'position': 30, 'isFinal': true},
  ],
  'transitions': const [],
});

Remittance _remittance(String code, String status, {DateTime? completedAt}) => Remittance(
  id: code,
  code: code,
  type: RemittanceType.delivery,
  status: status,
  statusName: status,
  beneficiaryName: 'Rosa',
  cashAmount: 100,
  cashCurrency: 'USD',
  completedAt: completedAt ?? (status == 'DELIVERED' ? DateTime(2026, 10, 14) : null),
);

void main() {
  late _MockRemittances remittances;
  late _MockCustomers customers;
  late _MockRates rates;
  late _MockCash cash;

  setUpAll(() async {
    registerFallbackValue(const RemittanceFilter());
    registerFallbackValue(const CashInput(amount: 0, currency: 'USD'));
    await OttosLocalization.initialize();
  });

  setUp(() {
    remittances = _MockRemittances();
    customers = _MockCustomers();
    rates = _MockRates();
    cash = _MockCash();
  });

  late AuthBloc authBloc;

  Future<void> pump(WidgetTester tester, Set<String> permissions, Widget page) async {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    when(auth.logout).thenAnswer((_) async {});
    authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: const [], permissions: permissions),
        ),
      );
    addTearDown(authBloc.close);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceRepository>.value(value: remittances),
          RepositoryProvider<RemittanceSource>.value(
            value: OnlineSource(
              remittances: remittances,
              onlyMine: permissions.contains(Permissions.remittancesReadAssigned),
            ),
          ),
          RepositoryProvider<CustomerRepository>.value(value: customers),
          RepositoryProvider<RateRepository>.value(value: rates),
          RepositoryProvider<CashRepository>.value(value: cash),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp.router(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => Scaffold(body: page),
                ),
                GoRoute(
                  path: Routes.courierCash(':id'),
                  builder: (_, state) => CourierCashPage(courierId: state.pathParameters['id']!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('list', () {
    testWidgets('sales see the open remittances and can register one', (tester) async {
      when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
      when(() => remittances.search(any(), size: any(named: 'size'))).thenAnswer(
        (_) async => PageResult(
          items: [_remittance('OT-OPEN', 'PAID'), _remittance('OT-DONE', 'DELIVERED')],
          page: 0,
          size: 100,
          totalItems: 2,
        ),
      );

      await pump(tester, _sales, const AssignedPage());

      expect(find.text('OT-OPEN'), findsOneWidget);
      expect(find.text('OT-DONE'), findsNothing);
      expect(find.text(CourierTexts.newRemittance), findsOneWidget);
      verifyNever(() => remittances.assignedToMe());
      verify(() => remittances.search(const RemittanceFilter(voided: false), size: 100)).called(1);
    });

    testWidgets('logging out with the list open does not fail', (tester) async {
      when(() => remittances.assignedToMe()).thenAnswer((_) async => [_remittance('OT-MINE', 'PAID')]);
      await pump(tester, _courierPermissions, const AssignedPage());

      authBloc.add(const AuthLogoutRequested());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a courier sees theirs and cannot register', (tester) async {
      when(() => remittances.assignedToMe()).thenAnswer((_) async => [_remittance('OT-MINE', 'PAID')]);

      await pump(tester, _courierPermissions, const AssignedPage());

      expect(find.text('OT-MINE'), findsOneWidget);
      expect(find.text(CourierTexts.newRemittance), findsNothing);
    });

    void stubSales({required List<Remittance> recent, required List<List<Remittance>> completedPages}) {
      when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
      when(() => remittances.search(const RemittanceFilter(voided: false), size: 100)).thenAnswer(
        (_) async => PageResult(items: recent, page: 0, size: 100, totalItems: recent.length),
      );
      for (final (index, items) in completedPages.indexed) {
        when(
          () => remittances.search(const RemittanceFilter(voided: false, status: 'DELIVERED'), page: index, size: 50),
        ).thenAnswer(
          (_) async => PageResult(items: items, page: index, size: 50, totalItems: 50 * (completedPages.length - 1) + 1),
        );
      }
    }

    testWidgets('sales turn on «Completadas» to see the completed ones after the open ones', (tester) async {
      final done = _remittance('OT-DONE', 'DELIVERED');
      final old = _remittance('OT-OLD', 'DELIVERED', completedAt: DateTime(2026, 10, 1));
      stubSales(
        recent: [old, done, _remittance('OT-OPEN', 'PAID')],
        completedPages: [
          [old, done],
        ],
      );

      await pump(tester, _sales, const AssignedPage());
      expect(find.text('OT-DONE'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, CourierTexts.showCompleted));
      await tester.pumpAndSettle();

      final codes = tester.widgetList<Text>(find.textContaining('OT-')).map((text) => text.data).toList();
      expect(codes, ['OT-OPEN', 'OT-DONE', 'OT-OLD'], reason: 'open first, then the latest completed');
      expect(find.textContaining('Completada el'), findsNWidgets(2));
      final card = find.ancestor(of: find.text('OT-DONE'), matching: find.byType(Dismissible));
      expect(tester.widget<Dismissible>(card).direction, DismissDirection.none, reason: 'nothing to do on it');
      expect(find.text(CourierTexts.showMore), findsNothing, reason: 'a single page');

      await tester.tap(find.widgetWithText(FilterChip, CourierTexts.showCompleted));
      await tester.pumpAndSettle();
      expect(find.text('OT-DONE'), findsNothing);
    });

    testWidgets('«Ver más» brings the next page of completed ones', (tester) async {
      stubSales(
        recent: const [],
        completedPages: [
          [_remittance('OT-P1', 'DELIVERED', completedAt: DateTime(2026, 10, 10))],
          [_remittance('OT-P2', 'DELIVERED', completedAt: DateTime(2026, 9, 10))],
        ],
      );

      await pump(tester, _sales, const AssignedPage());
      await tester.tap(find.widgetWithText(FilterChip, CourierTexts.showCompleted));
      await tester.pumpAndSettle();
      expect(find.text('OT-P1'), findsOneWidget);
      expect(find.text('OT-P2'), findsNothing);

      await tester.tap(find.text(CourierTexts.showMore));
      await tester.pumpAndSettle();
      expect(find.text('OT-P1'), findsOneWidget);
      expect(find.text('OT-P2'), findsOneWidget);
      expect(find.text(CourierTexts.showMore), findsNothing, reason: 'that was the last page');
    });

    testWidgets('with everything completed, sales can still turn on «Completadas»', (tester) async {
      final done = _remittance('OT-DONE', 'DELIVERED');
      stubSales(
        recent: [done],
        completedPages: [
          [done],
        ],
      );

      await pump(tester, _sales, const AssignedPage());
      expect(find.text(CourierTexts.noAssigned), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, CourierTexts.showCompleted));
      await tester.pumpAndSettle();
      expect(find.text('OT-DONE'), findsOneWidget);
    });

    testWidgets('a courier has no «Completadas» option', (tester) async {
      when(() => remittances.assignedToMe()).thenAnswer((_) async => [_remittance('OT-MINE', 'PAID')]);
      await pump(tester, _courierPermissions, const AssignedPage());
      expect(find.text(CourierTexts.showCompleted), findsNothing);

      when(() => remittances.assignedToMe()).thenAnswer((_) async => []);
      await pump(tester, _courierPermissions, const AssignedPage());
      expect(find.text(CourierTexts.noAssigned), findsOneWidget);
      expect(find.text(CourierTexts.showCompleted), findsNothing);
    });
  });

  group('new remittance', () {
    setUp(() {
      when(() => rates.corridors()).thenAnswer(
        (_) async => const [
          Corridor(
            code: 'USD-CUP',
            sourceCurrency: 'USD',
            targetCurrency: 'CUP',
            rate: ExchangeRate(id: 'r', rate: 760),
          ),
        ],
      );
      when(() => remittances.couriers()).thenAnswer((_) async => const [Courier(id: 'k1', name: 'Luis')]);
    });

    testWidgets('who can assign picks the courier', (tester) async {
      await pump(tester, _sales, const NewRemittancePage());

      expect(find.text(CourierTexts.courier), findsOneWidget);
      expect(find.text(CourierTexts.noCourier), findsOneWidget);
    });

    testWidgets('who can register customers creates the sender from the form', (tester) async {
      await pump(tester, {..._sales, Permissions.customersWrite}, const NewRemittancePage());
      expect(find.text(CourierTexts.newCustomer), findsOneWidget);

      await pump(tester, _sales, const NewRemittancePage());
      expect(find.text(CourierTexts.newCustomer), findsNothing);
    });

    testWidgets('the new sender is titled as such and can come from the phone contacts', (tester) async {
      await pump(
        tester,
        {..._sales, Permissions.customersWrite},
        NewRemittancePage(
          pickContact: () async => const PickedContact(name: 'Rosa Pérez', phone: '53 51234567'),
        ),
      );
      await tester.tap(find.text(CourierTexts.newCustomer));
      await tester.pumpAndSettle();

      expect(find.text(CourierTexts.newCustomer), findsNWidgets(2));
      expect(find.text(CoreTexts.newCustomer), findsNothing);
      await tester.tap(find.text(CoreTexts.pickFromContacts));
      await tester.pumpAndSettle();
      expect(find.text('Rosa Pérez'), findsOneWidget);
      expect(find.text('5351234567'), findsOneWidget);
    });

    testWidgets('who cannot assign does not see the courier', (tester) async {
      await pump(tester, _sales.difference({Permissions.remittancesAssign}), const NewRemittancePage());

      expect(find.text(CourierTexts.courier), findsNothing);
      verifyNever(() => remittances.couriers());
    });
  });

  group('cash', () {
    const luis = CourierCash(
      courierId: 'k1',
      name: 'Luis',
      balances: [Balance(currency: 'USD', amount: 50)],
      negative: false,
    );

    testWidgets('sales fund a courier from the app', (tester) async {
      var usd = 50.0;
      when(() => cash.couriers()).thenAnswer(
        (_) async => [
          CourierCash(
            courierId: 'k1',
            name: 'Luis',
            balances: [Balance(currency: 'USD', amount: usd)],
            negative: false,
          ),
        ],
      );
      when(() => cash.fundCourier('k1', any())).thenAnswer((invocation) async {
        final input = invocation.positionalArguments[1] as CashInput;
        usd += input.amount;
        return CashMovement.fromJson({
          'id': 'm1',
          'type': 'COURIER_FUNDING',
          'amount': input.amount,
          'signedAmount': input.amount,
          'currency': input.currency,
        });
      });

      await pump(tester, _sales, const CashPage());
      expect(find.text(CourierTexts.couriersCash), findsOneWidget);
      expect(find.text(CourierTexts.balances), findsNothing, reason: 'sales carry no cash of their own');

      await tester.tap(find.text(CourierTexts.fund));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '20');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CourierTexts.fund)));
      await tester.pumpAndSettle();

      verify(() => cash.fundCourier('k1', any())).called(1);
      expect(find.text(Formatters.money(70, 'USD')), findsOneWidget);
    });

    testWidgets('sales open a courier and see their movements, as the courier does', (tester) async {
      when(() => cash.couriers()).thenAnswer((_) async => const [luis]);
      when(() => cash.courierStatement('k1')).thenAnswer(
        (_) async => CourierStatement(
          cash: const CourierCash(
            courierId: 'k1',
            name: 'Luis',
            balances: [Balance(currency: 'CUP', amount: -500)],
            negative: true,
          ),
          movements: [
            CashMovement.fromJson(const {
              'id': 'm1',
              'type': 'DELIVERY_PAYOUT',
              'amount': 500,
              'signedAmount': -500,
              'currency': 'CUP',
              'occurredAt': '2026-10-12T15:00:00Z',
            }),
          ],
        ),
      );

      await pump(tester, _sales.difference({Permissions.cashWrite}), const CashPage());
      await tester.tap(find.text('Luis'));
      await tester.pumpAndSettle();

      verify(() => cash.courierStatement('k1')).called(1);
      expect(find.widgetWithText(AppBar, 'Luis'), findsOneWidget);
      expect(find.text(CourierTexts.balances), findsOneWidget);
      expect(find.text(CourierTexts.courierOwesBusiness), findsOneWidget);
      expect(find.text(CourierTexts.movementTitle('DELIVERY_PAYOUT')), findsOneWidget);
      expect(find.text(CourierTexts.fund), findsNothing, reason: 'moving cash needs cash:write');
    });

    testWidgets('from a courier\'s cash, sales fund them and see the movement', (tester) async {
      var movements = <CashMovement>[];
      when(() => cash.couriers()).thenAnswer((_) async => const [luis]);
      when(() => cash.courierStatement('k1'))
          .thenAnswer((_) async => CourierStatement(cash: luis, movements: movements));
      when(() => cash.fundCourier('k1', any())).thenAnswer((invocation) async {
        final input = invocation.positionalArguments[1] as CashInput;
        final movement = CashMovement.fromJson({
          'id': 'm1',
          'type': 'COURIER_FUNDING',
          'amount': input.amount,
          'signedAmount': input.amount,
          'currency': input.currency,
          'occurredAt': '2026-10-13T10:00:00Z',
        });
        movements = [movement];
        return movement;
      });

      await pump(tester, {..._sales, Permissions.cashWrite}, const CashPage());
      await tester.tap(find.text('Luis'));
      await tester.pumpAndSettle();
      expect(find.text(CourierTexts.registerReturn), findsOneWidget);

      await tester.tap(find.text(CourierTexts.fund));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '20');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CourierTexts.fund)));
      await tester.pumpAndSettle();

      verify(() => cash.fundCourier('k1', any())).called(1);
      expect(find.text(CourierTexts.movementTitle('COURIER_FUNDING')), findsOneWidget);
    });

    testWidgets('a courier sees only their own cash', (tester) async {
      when(() => cash.myStatement()).thenAnswer((_) async => const CourierStatement(cash: luis, movements: []));

      await pump(tester, _courierPermissions, const CashPage());

      expect(find.text(CourierTexts.balances), findsOneWidget);
      expect(find.text(CourierTexts.couriersCash), findsNothing);
      verifyNever(() => cash.couriers());
    });
  });

  group('detail', () {
    Remittance withCourier(String? courierId) => Remittance(
      id: 'r1',
      code: 'OT-1',
      type: RemittanceType.delivery,
      status: courierId == null ? 'PAID' : 'ASSIGNED',
      statusName: '',
      courierId: courierId,
    );

    testWidgets('a paid remittance can be assigned to a courier from the app', (tester) async {
      when(() => remittances.get('r1')).thenAnswer((_) async => withCourier(null));
      when(() => remittances.couriers()).thenAnswer((_) async => const [Courier(id: 'k1', name: 'Luis')]);
      when(() => remittances.assign('r1', courierId: 'k1')).thenAnswer((_) async => withCourier('k1'));

      await pump(tester, _sales, const RemittancePage(remittanceId: 'r1'));
      expect(find.text('Pagada'), findsOneWidget);
      expect(find.text(CoreTexts.reportIncident), findsNothing, reason: 'no courier went yet');

      await tester.tap(find.text(CourierTexts.assignToCourier));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Luis').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, CoreTexts.assign));
      await tester.pumpAndSettle();

      verify(() => remittances.assign('r1', courierId: 'k1')).called(1);
      expect(find.text('Asignada'), findsOneWidget);
      expect(find.text(CourierTexts.assignToCourier), findsNothing);
    });

    testWidgets('no assigning once it has a courier, or without the permission', (tester) async {
      when(() => remittances.get('r1')).thenAnswer((_) async => withCourier('k1'));
      await pump(tester, _sales, const RemittancePage(remittanceId: 'r1'));
      expect(find.text(CourierTexts.assignToCourier), findsNothing);
    });

    testWidgets('a voided remittance shows why and offers no actions', (tester) async {
      when(() => remittances.get('r1')).thenAnswer(
        (_) async => Remittance(
          id: 'r1',
          code: 'OT-1',
          type: RemittanceType.delivery,
          status: 'PAID',
          statusName: '',
          voided: const Voided(reason: 'Duplicada', byName: 'Admin'),
        ),
      );
      await pump(tester, _sales, const RemittancePage(remittanceId: 'r1'));

      expect(find.byType(VoidedBanner), findsOneWidget);
      expect(find.text(CourierTexts.assignToCourier), findsNothing);
    });

    testWidgets('a courier cannot assign', (tester) async {
      when(() => remittances.get('r1')).thenAnswer((_) async => withCourier(null));
      await pump(tester, _courierPermissions, const RemittancePage(remittanceId: 'r1'));
      expect(find.text(CourierTexts.assignToCourier), findsNothing);
    });
  });
}
