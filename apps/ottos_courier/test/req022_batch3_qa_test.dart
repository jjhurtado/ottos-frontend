// REQ-022 batch 3 (tester): the app's new remittance and courier cash keep
// their wording, layout and behaviour after moving to the shared core widgets
// (OPT-F6, OPT-F7). Expected texts are the literal wording users saw before;
// the file only uses APIs that also exist on develop, and it passed there
// before it passed on the branch.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/features/cash/view/cash_page.dart';
import 'package:ottos_courier/features/cash/view/courier_cash_page.dart';
import 'package:ottos_courier/features/new_remittance/view/new_remittance_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _ana = Customer(id: 'c1', fullName: 'Ana Prueba', phone: '+13055550001');
const _rosa = Beneficiary(id: 'b1', fullName: 'Rosa Prueba', phone: '5352220001', street: 'Calle 10');
const _luis = CourierCash(
  courierId: 'k1',
  name: 'Luis',
  balances: [Balance(currency: 'EUR', amount: 10)],
  negative: false,
);

/// Sales on the phone, without assigning (no courier picker to load).
const _sales = {
  Permissions.remittancesRead,
  Permissions.remittancesCreate,
  Permissions.cashRead,
  Permissions.cashWrite,
  Permissions.customersRead,
  Permissions.customersWrite,
};

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
    await OttosLocalization.initialize();
  });

  setUp(() {
    remittances = _MockRemittances();
    customers = _MockCustomers();
    rates = _MockRates();
    cash = _MockCash();
  });

  /// A phone-sized screen with a button that opens [page], as the app's routes do.
  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: const [], permissions: _sales),
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
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  group('OPT-F6: app new remittance', () {
    setUp(() {
      when(() => rates.corridors()).thenAnswer(
        (_) async => const [
          Corridor(
            code: 'USD-CUP',
            sourceCurrency: 'USD',
            targetCurrency: 'CUP',
            rate: ExchangeRate(id: 'r', rate: 410),
          ),
        ],
      );
      when(() => customers.search(any())).thenAnswer((_) async => const [_ana]);
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const [_rosa]);
    });

    testWidgets('main path with the app wording: sender, single beneficiary chosen, quote, register', (tester) async {
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

      await pump(tester, NewRemittancePage(pickContact: () async => null));

      expect(find.text('Busca por nombre o teléfono'), findsOneWidget);
      expect(find.text('Nombre o teléfono'), findsNothing);
      expect(find.text('Nuevo remitente'), findsOneWidget);
      expect(find.text('Nuevo cliente'), findsNothing);
      // The button goes under the search field, not beside it
      final search = tester.getRect(find.widgetWithIcon(TextField, Icons.search));
      final create = tester.getRect(find.widgetWithText(TextButton, 'Nuevo remitente'));
      expect(create.top, greaterThanOrEqualTo(search.bottom));

      await tester.enterText(find.widgetWithIcon(TextField, Icons.search), 'An');
      await tester.pumpAndSettle();
      // Options as wide as the screen less the margins
      final options = find.ancestor(of: find.text('Ana Prueba'), matching: find.byType(ListView)).first;
      expect(tester.getSize(options).width, 368);
      await tester.tap(find.text('Ana Prueba'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Prueba · +13055550001'), findsOneWidget);
      expect(find.text('Rosa Prueba · ${_rosa.address}'), findsOneWidget, reason: 'the only one is chosen');

      await tester.enterText(find.widgetWithText(TextField, 'Monto a enviar'), '100');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      for (final label in ['Comisión', 'Total a cobrar', 'Tasa', 'Se entrega']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Total cobrado'), findsNothing);
      expect(find.text('A entregar'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();

      final sent =
          verify(() => remittances.register(captureAny(), idempotencyKey: any(named: 'idempotencyKey'))).captured.single
              as NewRemittance;
      expect([sent.customerId, sent.beneficiaryId, sent.amount, sent.targetCurrency], ['c1', 'b1', 100, 'CUP']);
      expect(find.text('Remesa registrada: ${remittanceLabel('Rosa Prueba', 'OT-0009')}'), findsOneWidget);
      expect(find.text('Abrir'), findsOneWidget, reason: 'the page closes');
    });

    testWidgets('the new sender comes titled «Nuevo remitente» and can take a phone contact', (tester) async {
      await pump(
        tester,
        NewRemittancePage(
          pickContact: () async => const PickedContact(name: 'Pedro Prueba', phone: '53 51234567'),
        ),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Nuevo remitente'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Nuevo remitente')), findsOneWidget);
      await tester.tap(find.text(CoreTexts.pickFromContacts));
      await tester.pumpAndSettle();
      expect(find.text('Pedro Prueba'), findsOneWidget);
    });
  });

  group('OPT-F7: app courier cash', () {
    setUp(() => when(() => cash.couriers()).thenAnswer((_) async => const [_luis]));

    testWidgets('a return from the courier page offers USD, CUP and their EUR, is announced and reloads', (
      tester,
    ) async {
      when(() => cash.courierStatement('k1'))
          .thenAnswer((_) async => const CourierStatement(cash: _luis, movements: []));
      when(() => cash.courierReturn('k1', any())).thenAnswer(
        (_) async => CashMovement.fromJson(const {
          'id': 'm1',
          'type': 'COURIER_RETURN',
          'amount': 10,
          'signedAmount': 10,
          'currency': 'EUR',
          'occurredAt': '2026-11-07T10:00:00Z',
        }),
      );
      await pump(tester, const CourierCashPage(courierId: 'k1'));
      clearInteractions(cash);

      await tester.tap(find.text('Registrar devolución'));
      await tester.pumpAndSettle();
      expect(find.text('Devolución de Luis'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('USD'), findsWidgets);
      expect(find.text('CUP'), findsWidgets);
      await tester.tap(find.text('EUR').last);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();

      final input = verify(() => cash.courierReturn('k1', captureAny())).captured.single as CashInput;
      expect([input.amount, input.currency], [10, 'EUR']);
      expect(find.text('Movimiento de ${Formatters.money(10, 'EUR')} registrado'), findsOneWidget);
      verify(() => cash.courierStatement('k1')).called(1);
    });

    testWidgets('cancelling a funding from «Caja» says nothing and does not reload', (tester) async {
      await pump(tester, const CashPage());
      clearInteractions(cash);

      await tester.tap(find.text('Entregar fondos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CoreTexts.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      verifyZeroInteractions(cash);
    });
  });
}
