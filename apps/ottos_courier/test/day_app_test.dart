import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/features/cash/view/cash_page.dart';
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

Remittance _remittance(String code, String status) => Remittance(
  id: code,
  code: code,
  type: RemittanceType.delivery,
  status: status,
  statusName: status,
  beneficiaryName: 'Rosa',
  cashAmount: 100,
  cashCurrency: 'USD',
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

    testWidgets('a courier cannot assign', (tester) async {
      when(() => remittances.get('r1')).thenAnswer((_) async => withCourier(null));
      await pump(tester, _courierPermissions, const RemittancePage(remittanceId: 'r1'));
      expect(find.text(CourierTexts.assignToCourier), findsNothing);
    });
  });
}
