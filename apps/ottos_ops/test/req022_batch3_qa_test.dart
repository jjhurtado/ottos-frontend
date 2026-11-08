// REQ-022 batch 3 (tester): the panel's new remittance, cash operations and
// customer list behave as before the refactor (OPT-F6, OPT-F7, OPT-F8).
// Expected texts are the literal wording users saw before; the file only uses
// APIs that also exist on develop, and it passed there before it passed on
// the branch.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/cash/view/cash_page.dart';
import 'package:ottos_ops/features/cash/view/courier_cash_page.dart';
import 'package:ottos_ops/features/customers/view/customer_list_page.dart';
import 'package:ottos_ops/features/remittances/view/new_remittance_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _ana = Customer(id: 'c1', fullName: 'Ana Prueba', phone: '+13055550001');
const _rosa = Beneficiary(
  id: 'b1',
  fullName: 'Rosa Prueba',
  phone: '5352220001',
  street: 'Calle 10',
  houseNumber: '512',
  municipalityName: 'Plaza',
);
const _juana = Beneficiary(id: 'b2', fullName: 'Juana Prueba', phone: '5352220002', street: 'Calle 3');

CashMovement _movement(String type, double amount, String currency) => CashMovement.fromJson({
  'id': 'm-$type',
  'type': type,
  'amount': amount,
  'signedAmount': amount,
  'currency': currency,
  'occurredAt': '2026-11-07T10:00:00Z',
});

void main() {
  late _MockRemittances remittances;
  late _MockCustomers customers;
  late _MockRates rates;
  late _MockCash cash;

  setUpAll(() async {
    registerFallbackValue(const CashInput(amount: 0, currency: 'USD'));
    registerFallbackValue(
      const NewRemittance(
        type: RemittanceType.delivery,
        customerId: '',
        beneficiaryId: '',
        amount: 0,
        targetCurrency: '',
      ),
    );
    registerFallbackValue(RemittanceType.delivery);
    await OttosLocalization.initialize();
  });

  setUp(() {
    remittances = _MockRemittances();
    customers = _MockCustomers();
    rates = _MockRates();
    cash = _MockCash();
  });

  Future<void> pump(
    WidgetTester tester,
    Set<String> permissions,
    Widget page, {
    Size size = const Size(1400, 1400),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
          RepositoryProvider<RemittanceRepository>.value(value: remittances),
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
                  path: '/remittances/:id',
                  builder: (_, state) => Scaffold(body: Text('Detalle ${state.pathParameters['id']}')),
                ),
                GoRoute(
                  path: '/remittances',
                  builder: (_, _) => const Scaffold(body: Text('Lista de remesas')),
                ),
                GoRoute(
                  path: '/customers/:id',
                  builder: (_, state) => Scaffold(body: Text('Cliente ${state.pathParameters['id']}')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('OPT-F6: panel new remittance', () {
    const sales = {
      Permissions.remittancesCreate,
      Permissions.ratesRead,
      Permissions.customersRead,
      Permissions.customersWrite,
    };

    setUp(() {
      when(() => rates.corridors()).thenAnswer(
        (_) async => const [
          Corridor(
            code: 'USD-CUP',
            sourceCurrency: 'USD',
            targetCurrency: 'CUP',
            rate: ExchangeRate(id: 'r', rate: 410),
            pickupRate: ExchangeRate(id: 'p', rate: 400, remittanceType: RemittanceType.pickup),
          ),
        ],
      );
      when(() => customers.search(any())).thenAnswer((_) async => const [_ana]);
    });

    testWidgets('main path: find the sender, pick a beneficiary, see the quote and register', (tester) async {
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const [_rosa, _juana]);
      when(
        () => rates.quote(
          sourceCurrency: 'USD',
          targetCurrency: 'CUP',
          amount: 100,
          type: RemittanceType.delivery,
          rate: any(named: 'rate'),
          fee: any(named: 'fee'),
          onTheHouse: false,
        ),
      ).thenAnswer(
        (_) async => const Quote(
          sourceCurrency: 'USD',
          targetCurrency: 'CUP',
          amount: 100,
          fee: 5,
          total: 105,
          rate: 410,
          amountToDeliver: 41000,
        ),
      );
      when(() => remittances.register(any(), idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer(
        (_) async => const Remittance(
          id: 'r9',
          code: 'OT-0009',
          type: RemittanceType.delivery,
          status: 'PAID',
          statusName: 'Pagada',
          beneficiaryName: 'Rosa Prueba',
          cashAmount: 41000,
          cashCurrency: 'CUP',
        ),
      );

      await pump(tester, sales, const NewRemittancePage());

      expect(find.text('Nombre o teléfono'), findsOneWidget);
      expect(find.text('Nuevo cliente'), findsOneWidget);
      expect(find.text('Elige primero el remitente'), findsOneWidget);
      expect(find.text('Escribe el monto para ver la comisión y lo que se entrega.'), findsOneWidget);

      await tester.enterText(find.widgetWithIcon(TextField, Icons.search), 'a');
      await tester.pumpAndSettle();
      verifyNever(() => customers.search(any()));
      await tester.enterText(find.widgetWithIcon(TextField, Icons.search), 'An');
      await tester.pumpAndSettle();
      verify(() => customers.search('An')).called(1);
      expect(find.text('+13055550001'), findsOneWidget, reason: 'the option shows the phone');
      await tester.tap(find.text('Ana Prueba'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Prueba · +13055550001'), findsOneWidget);
      expect(find.byTooltip('Cambiar remitente'), findsOneWidget);
      expect(find.text('Buscar otro beneficiario'), findsOneWidget);
      expect(find.text('Nuevo beneficiario'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<Beneficiary>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rosa Prueba · ${_rosa.address}').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Monto a enviar'), '100');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      for (final label in ['Comisión', 'Total cobrado', 'Tasa', 'A entregar']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Total a cobrar'), findsNothing);
      expect(find.text(Formatters.money(105, 'USD')), findsOneWidget);
      expect(find.text(Formatters.money(41000, 'CUP')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar remesa'));
      await tester.pumpAndSettle();

      final sent =
          verify(() => remittances.register(captureAny(), idempotencyKey: any(named: 'idempotencyKey'))).captured.single
              as NewRemittance;
      expect(sent.customerId, 'c1');
      expect(sent.beneficiaryId, 'b1');
      expect(sent.amount, 100);
      expect(sent.targetCurrency, 'CUP');
      expect(sent.type, RemittanceType.delivery);
      expect(find.text('Detalle r9'), findsOneWidget);
    });

    testWidgets('a sender with no beneficiaries says so; changing the sender asks for one again', (tester) async {
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const []);
      await pump(tester, sales, const NewRemittancePage());

      await tester.enterText(find.widgetWithIcon(TextField, Icons.search), 'Ana');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Prueba'));
      await tester.pumpAndSettle();

      expect(
        find.text('Este remitente no tiene beneficiarios todavía. Búscalo entre todos o crea uno.'),
        findsOneWidget,
      );
      expect(find.text('Buscar otro beneficiario'), findsOneWidget);

      await tester.tap(find.byTooltip('Cambiar remitente'));
      await tester.pumpAndSettle();
      expect(find.text('Elige primero el remitente'), findsOneWidget);
      expect(find.text('Nombre o teléfono'), findsOneWidget);
    });

    testWidgets('a pickup quote shows what is collected, without total or amount to deliver', (tester) async {
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const [_rosa]);
      when(
        () => rates.quote(
          sourceCurrency: any(named: 'sourceCurrency'),
          targetCurrency: any(named: 'targetCurrency'),
          amount: any(named: 'amount'),
          type: RemittanceType.pickup,
          rate: any(named: 'rate'),
          fee: any(named: 'fee'),
          onTheHouse: any(named: 'onTheHouse'),
        ),
      ).thenAnswer(
        (_) async => const Quote(
          sourceCurrency: 'USD',
          targetCurrency: 'CUP',
          amount: 50,
          fee: 2,
          total: 52,
          rate: 400,
          amountToDeliver: 20000,
        ),
      );
      await pump(tester, sales, const NewRemittancePage());

      await tester.tap(find.text(CoreTexts.pickup));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el monto para ver la comisión.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Monto a recoger'), '50');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Se recoge'), findsOneWidget);
      expect(find.text('Comisión'), findsOneWidget);
      expect(find.text('Tasa'), findsOneWidget);
      expect(find.text('Total cobrado'), findsNothing);
      expect(find.text('A entregar'), findsNothing);
    });

    testWidgets('without customers:write there is no «Nuevo cliente» nor «Nuevo beneficiario»', (tester) async {
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const [_rosa]);
      await pump(tester, sales.difference({Permissions.customersWrite}), const NewRemittancePage());

      expect(find.text('Nuevo cliente'), findsNothing);
      await tester.enterText(find.widgetWithIcon(TextField, Icons.search), 'Ana');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Prueba'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo beneficiario'), findsNothing);
      expect(find.text('Buscar otro beneficiario'), findsOneWidget);
    });
  });

  group('OPT-F7: panel cash operations', () {
    const luis = CourierCash(
      courierId: 'k1',
      name: 'Luis',
      balances: [Balance(currency: 'EUR', amount: 10)],
      negative: false,
    );

    setUp(() {
      when(() => cash.businessBalances()).thenAnswer((_) async => const [Balance(currency: 'USD', amount: 100)]);
      when(() => cash.couriers()).thenAnswer((_) async => const [luis]);
      when(() => cash.businessMovements()).thenAnswer((_) async => const []);
      when(
        () => cash.exchanges(
          courierId: any(named: 'courierId'),
          review: any(named: 'review'),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => const PageResult(items: [], page: 0, size: 50, totalItems: 0));
    });

    testWidgets('a deposit needs a reason, is announced and reloads the cash', (tester) async {
      when(() => cash.deposit(any())).thenAnswer((_) async => _movement('BUSINESS_DEPOSIT', 30, 'USD'));
      await pump(tester, {Permissions.cashRead, Permissions.cashWrite, Permissions.cashAdjust}, const CashPage());
      clearInteractions(cash);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Depositar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '30');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(find.text(CoreTexts.requiredField), findsOneWidget, reason: 'a deposit needs a reason');
      verifyNever(() => cash.deposit(any()));

      await tester.enterText(find.byType(TextFormField).last, 'Aporte del dueño');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();

      final input = verify(() => cash.deposit(captureAny())).captured.single as CashInput;
      expect(input.amount, 30);
      expect(input.currency, 'USD');
      expect(input.note, 'Aporte del dueño');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Movimiento de ${Formatters.money(30, 'USD')} registrado'), findsOneWidget);
      // Once on closing the dialog (RefreshOnReturn) and once after the movement
      verify(() => cash.businessBalances()).called(2);
    });

    testWidgets('from the cash page a courier return offers the business\'s currencies; cancel does nothing', (
      tester,
    ) async {
      when(() => cash.courierReturn('k1', any())).thenAnswer((_) async => _movement('COURIER_RETURN', 10, 'EUR'));
      await pump(tester, {Permissions.cashRead, Permissions.cashWrite}, const CashPage());
      clearInteractions(cash);

      await tester.tap(find.widgetWithText(TextButton, 'Registrar devolución'));
      await tester.pumpAndSettle();
      expect(find.text('Devolución de Luis'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      // As before: the cash page offers the currencies in the business's box (here only USD)
      expect(find.text('USD'), findsWidgets);
      expect(find.text('CUP'), findsNothing);
      expect(find.text('EUR'), findsNothing);
      await tester.tap(find.text('USD').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(CoreTexts.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      verifyNever(() => cash.courierReturn(any(), any()));
      // Only the reload on closing the dialog (RefreshOnReturn), none for a movement
      verify(() => cash.businessBalances()).called(1);
    });

    testWidgets('an error stays in the dialog, with nothing announced', (tester) async {
      when(() => cash.fundCourier('k1', any()))
          .thenThrow(const ApiException('Saldo insuficiente en la caja', statusCode: 409));
      when(() => cash.courierStatement('k1'))
          .thenAnswer((_) async => const CourierStatement(cash: luis, movements: []));
      await pump(tester, {Permissions.cashRead, Permissions.cashWrite}, const CourierCashPage(courierId: 'k1'));

      await tester.tap(find.text('Entregar fondos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '20');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Saldo insuficiente en la caja'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      verify(() => cash.courierStatement('k1')).called(1); // the first load only
    });

    testWidgets('a courier return from the courier page is announced and reloads the statement', (tester) async {
      when(() => cash.courierReturn('k1', any())).thenAnswer((_) async => _movement('COURIER_RETURN', 10, 'EUR'));
      when(() => cash.courierStatement('k1'))
          .thenAnswer((_) async => const CourierStatement(cash: luis, movements: []));
      await pump(tester, {Permissions.cashRead, Permissions.cashWrite}, const CourierCashPage(courierId: 'k1'));
      clearInteractions(cash);

      await tester.tap(find.text('Registrar devolución'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EUR').last);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();

      final input = verify(() => cash.courierReturn('k1', captureAny())).captured.single as CashInput;
      expect(input.currency, 'EUR');
      expect(find.text('Movimiento de ${Formatters.money(10, 'EUR')} registrado'), findsOneWidget);
      verify(() => cash.courierStatement('k1')).called(1);
    });
  });

  group('OPT-F8: customer list page', () {
    PageResult<Customer> page(List<Customer> items, {int page = 0, int total = 2}) =>
        PageResult(items: items, page: page, size: 50, totalItems: total);
    const luis = Customer(id: 'c2', fullName: 'Luis Prueba', phone: '+13055550002');

    testWidgets('lists, searches after typing, pages and shows the empty search', (tester) async {
      when(() => customers.customerPage('', page: 0, size: 50))
          .thenAnswer((_) async => page(const [_ana, luis], total: 120));
      when(() => customers.customerPage('', page: 1, size: 50))
          .thenAnswer((_) async => page(const [luis], page: 1, total: 120));
      when(() => customers.customerPage('lu', page: 0, size: 50)).thenAnswer((_) async => page(const [luis], total: 1));
      when(() => customers.customerPage('zz', page: 0, size: 50)).thenAnswer((_) async => page(const [], total: 0));
      await pump(tester, {Permissions.customersRead}, const CustomerListPage());

      expect(find.text('Ana Prueba'), findsOneWidget);
      expect(find.text('Luis Prueba'), findsOneWidget);
      expect(find.text('1–2 de 120'), findsOneWidget);

      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Prueba'), findsNothing);
      expect(find.text('51–51 de 120'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'l');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'lu');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      verifyNever(
        () => customers.customerPage(
          'l',
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      );
      expect(find.text('Luis Prueba'), findsOneWidget);
      expect(find.text('1–1 de 1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Ningún cliente coincide con la búsqueda.'), findsOneWidget);
    });

    testWidgets('no customers yet, and a failed load with «Reintentar» that loads again', (tester) async {
      var fail = true;
      when(() => customers.customerPage('', page: 0, size: 50)).thenAnswer((_) async {
        if (fail) throw const ApiException('Sin conexión con el servidor');
        return page(const [], total: 0);
      });
      await pump(tester, {Permissions.customersRead}, const CustomerListPage());

      expect(find.text('Sin conexión con el servidor'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no hay clientes.'), findsOneWidget);
    });
  });
}
