import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockApi extends Mock implements ApiClient {}

Remittance _remittance(
  String id, {
  RemittanceType type = RemittanceType.delivery,
  double? cash = 100,
  String? currency = 'USD',
  DateTime? completedAt,
  Voided? voided,
}) => Remittance(
  id: id,
  code: id,
  type: type,
  status: 'ASSIGNED',
  statusName: '',
  cashAmount: cash,
  cashCurrency: currency,
  completedAt: completedAt,
  voided: voided,
);

PendingAmount _amount(String currency, int count, double value) =>
    PendingAmount(currency: currency, remittances: count, amount: value);

/// REQ-021: money pending to deliver and to collect.
void main() {
  group('PendingTotals', () {
    test('BR-5: reads the server totals; missing lists read as empty', () {
      final totals = PendingTotals.fromJson({
        'toDeliver': [
          {'currency': 'CUP', 'remittances': 2, 'amount': '76000.00'},
          {'currency': 'USD', 'remittances': 3, 'amount': 450.5},
        ],
        'toCollect': [],
      });

      expect(totals.toDeliver, [_amount('CUP', 2, 76000), _amount('USD', 3, 450.5)]);
      expect(totals.toCollect, isEmpty);
      expect(PendingTotals.fromJson(const {}), const PendingTotals());
    });

    test('BR-2 BR-7: the phone sums the cash per type and currency, never mixing currencies', () {
      final totals = PendingTotals.sum([
        _remittance('a', cash: 100),
        _remittance('b', cash: 50.25),
        _remittance('c', cash: 38000, currency: 'CUP'),
        _remittance('d', type: RemittanceType.pickup, cash: 200),
      ]);

      expect(totals.toDeliver, [_amount('CUP', 1, 38000), _amount('USD', 2, 150.25)]);
      expect(totals.toCollect, [_amount('USD', 1, 200)]);
    });

    test('CR-1 BR-2: the phone adds whole cents, so the sum is exact', () {
      final totals = PendingTotals.sum([
        _remittance('a', cash: 0.1),
        _remittance('b', cash: 0.2),
        _remittance('c', cash: 1234567.89),
      ]);

      expect(totals.toDeliver.single.amount, 1234568.19, reason: 'whole cents, never a binary remainder');
      final pickups = PendingTotals.sum([
        _remittance('d', type: RemittanceType.pickup, cash: 0.1),
        _remittance('e', type: RemittanceType.pickup, cash: 0.2),
      ]);
      expect(pickups.toCollect.single.amount, 0.3, reason: 'adding doubles gives 0.30000000000000004');
    });

    test('AC-1.3 AC-3.3: voided and completed ones are not counted', () {
      final totals = PendingTotals.sum([
        _remittance('done', completedAt: DateTime(2026, 11, 6)),
        _remittance('void', voided: const Voided(reason: 'x')),
        _remittance('no cash', cash: null, currency: null),
      ]);

      expect(totals, const PendingTotals());
    });
  });

  group('RemittanceRepository', () {
    late _MockApi api;

    setUp(() {
      api = _MockApi();
      when(() => api.get<Map<String, dynamic>>('/remittance-workflow')).thenAnswer(
        (_) async => {
          'statuses': [
            {'code': 'PAID', 'position': 10},
            {'code': 'ASSIGNED', 'position': 20},
            {'code': 'DELIVERED', 'position': 30, 'isFinal': true},
          ],
        },
      );
    });

    test('BR-1 BR-8 CR-2: the pending filter is every non-final status of the workflow, not voided', () async {
      final workflow = await RemittanceRepository(api: api).workflow();

      expect(
        RemittanceFilter.pending(workflow.statuses),
        const RemittanceFilter(status: 'PAID,ASSIGNED', voided: false),
      );
    });

    test('AC-1.1 BR-5: asks one row with the totals and reads them', () async {
      when(() => api.get<Map<String, dynamic>>('/remittances', query: any(named: 'query'))).thenAnswer(
        (_) async => {
          'items': [],
          'totalItems': 4,
          'totals': {
            'toDeliver': [
              {'currency': 'USD', 'remittances': 4, 'amount': 400},
            ],
            'toCollect': [],
          },
        },
      );

      final totals = await RemittanceRepository(api: api).pendingTotals();

      expect(totals.toDeliver.single, _amount('USD', 4, 400));
      final query =
          verify(() => api.get<Map<String, dynamic>>('/remittances', query: captureAny(named: 'query'))).captured.single
              as Map<String, dynamic>;
      expect(query, containsPair('status', 'PAID,ASSIGNED'));
      expect(query, containsPair('voided', false));
      expect(query, containsPair('size', 1));
      expect(query, containsPair('totals', true));
    });
  });

  test('CR-4: a page without totals (a backend before REQ-021) is an error, never «Nada pendiente»', () async {
    final api = _MockApi();
    when(() => api.get<Map<String, dynamic>>('/remittance-workflow')).thenAnswer((_) async => {'statuses': []});
    when(() => api.get<Map<String, dynamic>>('/remittances', query: any(named: 'query')))
        .thenAnswer((_) async => {'items': [], 'totalItems': 0, 'totals': null});

    await expectLater(
      RemittanceRepository(api: api).pendingTotals(),
      throwsA(isA<ApiException>().having((error) => error.message, 'message', CoreTexts.unexpectedError)),
    );
  });

  group('PendingTotalsTiles', () {
    Future<void> pump(WidgetTester tester, PendingTotals totals, {ValueChanged<RemittanceType>? onTap}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: PendingTotalsTiles(totals: totals, onTap: onTap),
              ),
            ),
          ),
        );

    testWidgets('AC-1.1 AC-1.2: one line per currency with its count, deliveries apart from pickups', (tester) async {
      await pump(
        tester,
        PendingTotals(
          toDeliver: [_amount('CUP', 2, 76000), _amount('USD', 1, 1234567.5)],
          toCollect: [_amount('USD', 3, 300)],
        ),
      );

      expect(find.text(CoreTexts.pendingToDeliver), findsOneWidget);
      expect(find.text(CoreTexts.pendingToCollect), findsOneWidget);
      expect(find.text(Formatters.money(76000, 'CUP')), findsOneWidget);
      expect(find.text('2 remesas'), findsOneWidget);
      expect(find.text('1 remesa'), findsOneWidget);
      expect(find.text('3 remesas'), findsOneWidget);
      expect(find.text(Formatters.money(300, 'USD')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'a large amount fits a narrow tile');
    });

    testWidgets('AC-1.5: nothing pending says so', (tester) async {
      await pump(tester, const PendingTotals());

      expect(find.text(CoreTexts.nothingPending), findsNWidgets(2));
    });

    testWidgets('AC-1.7: a tap says which type it adds up', (tester) async {
      final tapped = <RemittanceType>[];
      await pump(tester, const PendingTotals(), onTap: tapped.add);

      await tester.tap(find.text(CoreTexts.pendingToCollect));
      await tester.tap(find.text(CoreTexts.pendingToDeliver));

      expect(tapped, [RemittanceType.pickup, RemittanceType.delivery]);
    });
  });
}
