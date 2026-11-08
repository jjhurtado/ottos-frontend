import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _quote = Quote(
  sourceCurrency: 'USD',
  targetCurrency: 'CUP',
  amount: 100,
  fee: 5,
  total: 105,
  rate: 410,
  amountToDeliver: 41000,
);

/// REQ-022 batch 3 (OPT-F6, OPT-F7): the new-remittance fields and the cash
/// operations shared by the panel and the app.
void main() {
  setUpAll(OttosLocalization.initialize);

  Future<void> pump(WidgetTester tester, Widget child) async {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        const AuthLoggedIn(
          CurrentUser(
            id: 'u1',
            email: 'u@ottos.test',
            name: 'U',
            type: '',
            roles: [],
            permissions: {Permissions.customersWrite},
          ),
        ),
      );
    addTearDown(authBloc.close);
    final cubit = NewRemittanceCubit(remittances: _MockRemittances(), customers: _MockCustomers(), rates: _MockRates());
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc),
          BlocProvider.value(value: cubit),
        ],
        child: MaterialApp(
          localizationsDelegates: OttosLocalization.delegates,
          supportedLocales: OttosLocalization.supportedLocales,
          home: Scaffold(body: ListView(children: [child])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// [text] inside a Row that also holds the search field.
  Finder besideSearch(String text) => find.descendant(
    of: find.ancestor(of: find.byType(TextField), matching: find.byType(Row)),
    matching: find.text(text),
  );

  group('OPT-F6: new-remittance fields', () {
    testWidgets('the panel keeps its wording and puts «Nuevo cliente» beside the search', (tester) async {
      await pump(tester, const NewRemittanceCustomerField(customer: null, enabled: true));

      expect(find.text(CoreTexts.searchCustomer), findsOneWidget);
      expect(besideSearch(CoreTexts.newCustomer), findsWidgets);
      expect(find.text(CoreTexts.newSender), findsNothing);
    });

    testWidgets('the app keeps its wording and puts «Nuevo remitente» under the search', (tester) async {
      await pump(tester, const NewRemittanceCustomerField(customer: null, enabled: true, compact: true));

      expect(find.text(CoreTexts.searchCustomerApp), findsOneWidget);
      expect(find.text(CoreTexts.newSender), findsOneWidget);
      expect(besideSearch(CoreTexts.newSender), findsNothing);
      expect(find.text(CoreTexts.newCustomer), findsNothing);
    });

    testWidgets('without a customer the beneficiary asks for one first', (tester) async {
      await pump(tester, const NewRemittanceBeneficiaryField(state: NewRemittanceState()));

      expect(find.text(CoreTexts.chooseCustomerFirst), findsOneWidget);
    });

    testWidgets('the quote shows the panel or the app labels', (tester) async {
      const state = NewRemittanceState(quote: _quote);
      await pump(tester, const NewRemittanceQuoteSummary(state: state));
      expect(find.text(CoreTexts.quoteTotal), findsOneWidget);
      expect(find.text(CoreTexts.quoteToDeliver), findsOneWidget);

      await pump(tester, const NewRemittanceQuoteSummary(state: state, compact: true));
      expect(find.text(CoreTexts.quoteTotalApp), findsOneWidget);
      expect(find.text(CoreTexts.quoteToDeliverApp), findsOneWidget);
    });
  });

  group('OPT-F7: courier cash operations', () {
    test('USD and CUP first, then any other currency the courier holds, once each', () {
      expect(courierCashCurrencies(const []), ['USD', 'CUP']);
      expect(courierCashCurrencies(const [Balance(currency: 'CUP', amount: 10), Balance(currency: 'EUR', amount: 5)]), [
        'USD',
        'CUP',
        'EUR',
      ]);
    });

    Future<void> openOperation(WidgetTester tester, void Function() onDone) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => runCashOperation(
                  context,
                  title: 'Fondos',
                  confirmLabel: 'Entregar',
                  currencies: const ['USD', 'CUP'],
                  submit: (input) async => CashMovement(
                    id: 'm1',
                    type: CashMovementType.courierFunding,
                    amount: input.amount,
                    signedAmount: input.amount,
                    currency: input.currency,
                  ),
                  onDone: onDone,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('a registered movement is announced and the caller reloads', (tester) async {
      var reloads = 0;
      await openOperation(tester, () => reloads++);
      await tester.enterText(find.byType(TextFormField).first, '20');
      await tester.tap(find.text('Entregar'));
      await tester.pumpAndSettle();

      expect(find.text(CoreTexts.movementRegistered(Formatters.money(20, 'USD'))), findsOneWidget);
      expect(reloads, 1);
    });

    testWidgets('a cancelled operation says nothing and does not reload', (tester) async {
      var reloads = 0;
      await openOperation(tester, () => reloads++);
      await tester.tap(find.text(CoreTexts.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(reloads, 0);
    });
  });
}
