import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/remittances/view/historical_remittance_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

const _wildcard = Customer(id: 'c0', fullName: 'Cliente histórico sin identificar', phone: '0000000');
const _rosa = Beneficiary(id: 'b1', fullName: 'Rosa', phone: '5352220001', street: 'Calle 10');

void main() {
  late _MockRemittances remittances;
  late _MockCustomers customers;
  late String? opened;

  setUpAll(() {
    registerFallbackValue(
      HistoricalRemittance(
        type: RemittanceType.delivery,
        customerId: '',
        beneficiaryId: '',
        occurredAt: DateTime(2020),
        amount: 0,
        fee: 0,
      ),
    );
  });

  setUp(() {
    remittances = _MockRemittances();
    customers = _MockCustomers();
    opened = null;
    when(() => customers.search(any())).thenAnswer((_) async => const [_wildcard]);
    when(() => customers.beneficiaries('c0')).thenAnswer((_) async => const [_rosa]);
    when(() => remittances.registerHistorical(any())).thenAnswer(
      (_) async => const Remittance(
        id: 'r9',
        code: 'OT-OLD1',
        type: RemittanceType.delivery,
        status: 'DELIVERED',
        statusName: 'Entregada',
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/remittances/historical',
      routes: [
        GoRoute(
          path: '/remittances',
          builder: (_, _) => const Scaffold(body: Text('list')),
        ),
        GoRoute(
          path: '/remittances/historical',
          // A fixed evening, so 12:00 of "today" is in the past.
          builder: (_, _) => Scaffold(body: HistoricalRemittancePage(now: () => DateTime(2026, 10, 13, 18))),
        ),
        GoRoute(
          path: '/remittances/:id',
          builder: (_, state) {
            opened = state.pathParameters['id'];
            return const Scaffold(body: Text('detail'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceRepository>.value(value: remittances),
          RepositoryProvider<CustomerRepository>.value(value: customers),
        ],
        child: MaterialApp.router(
          localizationsDelegates: OttosLocalization.delegates,
          supportedLocales: OttosLocalization.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseWho(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextField, '${OpsTexts.customer} *'), 'Cliente');
    await tester.pumpAndSettle();
    await tester.tap(find.text(_wildcard.fullName));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<Beneficiary>, '${OpsTexts.beneficiary} *'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Rosa').last);
    await tester.pumpAndSettle();
  }

  Future<void> pickToday(WidgetTester tester) async {
    await tester.tap(find.text(OpsTexts.historicalPickDate));
    await tester.pumpAndSettle();
    final ok = MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog))).okButtonLabel;
    await tester.tap(find.text(ok).last);
    await tester.pumpAndSettle();
  }

  testWidgets('a delivery in CUP keeps the ticket figures and opens the new remittance', (tester) async {
    await pump(tester);
    await chooseWho(tester);
    await pickToday(tester);
    await tester.tap(find.text(OpsTexts.historicalDeliveredInCup));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.historicalSent} *'), '100');
    await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.historicalFee} *'), '10');
    await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.historicalRate} *'), '300');
    await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.historicalToDeliver} *'), '30000');
    await tester.tap(find.text(OpsTexts.register));
    await tester.pumpAndSettle();

    final sent = verify(() => remittances.registerHistorical(captureAny())).captured.single as HistoricalRemittance;
    expect(sent.toJson(), {
      'type': 'DELIVERY',
      'customerId': 'c0',
      'beneficiaryId': 'b1',
      'occurredAt': '2026-10-13T12:00:00',
      'targetCurrency': 'CUP',
      'amount': 100.0,
      'fee': 10.0,
      'rate': 300.0,
      'amountToDeliver': 30000.0,
      'notes': null,
    });
    expect(opened, 'r9');
  });

  testWidgets('a pickup is in USD and sends no rate', (tester) async {
    await pump(tester);
    await tester.tap(find.text(CoreTexts.pickup));
    await tester.pumpAndSettle();
    expect(find.text(OpsTexts.historicalDeliveredInCup), findsNothing);
    expect(find.text(OpsTexts.historicalPickupUsd), findsOneWidget);

    await chooseWho(tester);
    await pickToday(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.historicalCollected} *'), '2500');
    await tester.tap(find.text(OpsTexts.register));
    await tester.pumpAndSettle();

    final sent = verify(() => remittances.registerHistorical(captureAny())).captured.single as HistoricalRemittance;
    expect(sent.toJson()['type'], 'PICKUP');
    expect(sent.toJson()['targetCurrency'], 'USD');
    expect(sent.toJson().containsKey('rate'), isFalse);
    expect(sent.fee, 0);
  });

  testWidgets('nothing is sent without sender, beneficiary, date and amount', (tester) async {
    await pump(tester);
    await tester.tap(find.text(OpsTexts.register));
    await tester.pumpAndSettle();

    verifyNever(() => remittances.registerHistorical(any()));
    expect(find.text(CoreTexts.requiredField), findsAtLeastNWidgets(3));
  });
}
