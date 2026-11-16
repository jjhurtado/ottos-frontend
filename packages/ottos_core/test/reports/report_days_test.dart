import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockReports extends Mock implements ReportRepository {}

/// A row of the month's detail as the endpoint sends it.
Map<String, dynamic> _json(
  String code,
  String createdAt, {
  double amount = 100,
  double fee = 10,
  String type = 'DELIVERY',
  bool voided = false,
}) => {
  'id': 'id-$code',
  'code': code,
  'beneficiaryName': 'Rosa Pérez',
  'type': type,
  'status': 'PAID',
  'statusName': 'PAID',
  'createdAt': createdAt,
  'municipalityName': 'Centro Habana',
  'sourceCurrency': 'USD',
  'targetCurrency': 'CUP',
  'amount': amount,
  'fee': fee,
  'total': amount + fee,
  'rate': 410,
  'amountToDeliver': amount * 410,
  'collected': amount + fee,
  'deliveredCurrency': amount,
  'voided': voided ? {'at': createdAt, 'byName': 'Admin', 'reason': 'Repetida'} : null,
};

ReportRemittance _row(
  String code,
  String createdAt, {
  double amount = 100,
  double fee = 10,
  String type = 'DELIVERY',
  bool voided = false,
}) => ReportRemittance.fromJson(_json(code, createdAt, amount: amount, fee: fee, type: type, voided: voided));

Map<String, dynamic> _detail(List<Map<String, dynamic>> rows) => {
  'month': '2026-10',
  'from': '2026-10-01',
  'to': '2026-10-31',
  'generatedAt': '2026-11-01T13:05:00Z',
  'businessCurrency': 'USD',
  'remittances': rows,
};

void main() {
  setUpAll(() async {
    registerFallbackValue(DateTime(2000));
    await OttosLocalization.initialize();
  });

  tearDown(BusinessTime.reset);

  group('REQ-026 groupReportDays', () {
    // Business time UTC−4: 02:00Z on the 2nd is still the 1st (BR-1).
    final a1 = _row('OT-A1', '2026-10-01T13:00:00Z');
    final a2 = _row('OT-A2', '2026-10-02T02:00:00Z', amount: 50, fee: 5);
    final b1 = _row('OT-B1', '2026-10-02T15:00:00Z', amount: 200, fee: 20);
    final b2 = _row('OT-B2', '2026-10-02T16:00:00Z', amount: 80, fee: 8, voided: true);
    final b3 = _row('OT-B3', '2026-10-02T17:00:00Z', amount: 40, fee: 4, type: 'PICKUP');
    final c1 = _row('OT-C1', '2026-10-05T12:00:00Z');
    final oldestFirst = [a1, a2, b1, b2, b3, c1];
    final newestFirst = oldestFirst.reversed.toList();

    test('AC-1.1: several days, each with its rows in the list order and its business date', () {
      final days = groupReportDays(newestFirst);

      expect(days.map((day) => day.date), [DateTime(2026, 10, 5), DateTime(2026, 10, 2), DateTime(2026, 10, 1)]);
      expect(days[1].rows, [b3, b2, b1]);
      // The 02:00Z row belongs to the 1st in business time (BR-1).
      expect(days[2].rows, [a2, a1]);
      expect(days[2].totals.remittances, 2);
      expect(days[2].totals.sent, 150);
      expect(days[2].totals.fees, 15);
    });

    test('AC-1.2 BR-2: a voided row stays under its day, counted apart and not summed', () {
      final day = groupReportDays(newestFirst)[1];

      expect(day.rows, contains(b2));
      expect(day.totals.remittances, 2);
      expect(day.totals.voided, 1);
      // Sent: live deliveries only (the pickup is not sent); fees: every live row.
      expect(day.totals.sent, 200);
      expect(day.totals.fees, 24);
    });

    test('AC-1.4 BR-2: a day split across pages has the same summary on both pages', () {
      final firstPage = newestFirst.take(2).toList();
      final secondPage = newestFirst.skip(2).toList();

      final onFirst = groupReportDays(firstPage, all: newestFirst);
      final onSecond = groupReportDays(secondPage, all: newestFirst);

      expect(onFirst.last.date, DateTime(2026, 10, 2));
      expect(onFirst.last.rows, [b3]);
      expect(onSecond.first.date, DateTime(2026, 10, 2));
      expect(onSecond.first.rows, [b2, b1]);
      expect(onFirst.last.totals, onSecond.first.totals);
      expect(onSecond.first.totals.voided, 1);
      expect(onSecond.first.totals.remittances, 2);
    });

    test('AC-2.3 BR-3: oldest first, the days come oldest first', () {
      final days = groupReportDays(oldestFirst);

      expect(days.map((day) => day.date), [DateTime(2026, 10, 1), DateTime(2026, 10, 2), DateTime(2026, 10, 5)]);
      expect(days[1].rows, [b1, b2, b3]);
    });

    test('AC-2.4: an empty list has no days', () {
      expect(groupReportDays(const []), isEmpty);
    });

    test('CR-1: rows without a registration time make one group headed «Sin fecha»', () {
      const n1 = ReportRemittance(id: 'n1', code: 'OT-N1');
      const n2 = ReportRemittance(id: 'n2', code: 'OT-N2');

      final days = groupReportDays([n1, n2]);

      expect(days, hasLength(1));
      expect(days.single.date, isNull);
      expect(days.single.rows, [n1, n2]);
      expect(ReportTexts.dayHeading(days.single.date, DateTime(2026, 10, 29)), 'Sin fecha');
    });

    test('BR-1: the day follows the business time zone', () {
      BusinessTime.setForTest(zone: BusinessTimeZone.ofMinutes(0));

      expect(groupReportDays([a2]).single.date, DateTime(2026, 10, 2));
    });
  });

  group('REQ-026 day texts', () {
    final today = DateTime(2026, 10, 29);

    test('AC-1.1: weekday and date, with «Hoy ·» or «Ayer ·» when it applies', () {
      expect(ReportTexts.dayHeading(DateTime(2026, 10, 29), today), 'Hoy · Jueves 29 oct');
      expect(ReportTexts.dayHeading(DateTime(2026, 10, 28), today), 'Ayer · Miércoles 28 oct');
      expect(ReportTexts.dayHeading(DateTime(2026, 10, 27), today), 'Martes 27 oct');
      expect(ReportTexts.dayHeading(DateTime(2026, 10, 30), today), 'Viernes 30 oct');
    });

    test('AC-1.1 AC-1.2: the card summary, with the voided ones when there are any', () {
      const totals = ReportTotals(remittances: 3, sent: 475, deliveryFees: 30);
      expect(ReportTexts.daySummaryShort(totals, 'USD'), '3 remesas · 475,00 USD');
      expect(
        ReportTexts.daySummaryShort(const ReportTotals(remittances: 1, sent: 50, voided: 1), 'USD'),
        '1 remesa · 50,00 USD · 1 anulada',
      );
      expect(ReportTexts.voidedCount(2), '2 anuladas');
    });

    test('AC-2.1: the table summary with sent and fees', () {
      const totals = ReportTotals(remittances: 3, sent: 475, deliveryFees: 25, pickupFees: 5, voided: 2);
      expect(
        ReportTexts.daySummary(totals, 'USD'),
        '3 remesas · enviado 475,00 USD · comisiones 30,00 USD · 2 anuladas',
      );
    });
  });

  group('REQ-026 month remittances by day', () {
    late _MockReports reports;

    // Oct 1 (2 rows, 1 voided), Oct 2 (1 row), oldest first as the backend sends them.
    final rows = [
      _json('OT-A1', '2026-10-01T13:00:00Z'),
      _json('OT-A2', '2026-10-01T15:00:00Z', amount: 80, fee: 8, voided: true),
      _json('OT-B1', '2026-10-02T15:00:00Z', amount: 200, fee: 20),
    ];

    setUp(() {
      reports = _MockReports();
      BusinessTime.setForTest(deviceClock: () => DateTime.utc(2026, 10, 2, 18));
    });

    Future<ReportRemittancesCubit> pump(
      WidgetTester tester,
      List<Map<String, dynamic>> rows, {
      required bool compact,
    }) async {
      when(() => reports.monthlyRemittances(any(), any()))
          .thenAnswer((_) async => MonthlyReportDetail.fromJson(_detail(rows)));
      final cubit = ReportRemittancesCubit(reports: reports, month: DateTime(2026, 10))..load();
      addTearDown(cubit.close);
      await tester.binding.setSurfaceSize(compact ? const Size(390, 2400) : const Size(1400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: OttosLocalization.delegates,
          supportedLocales: OttosLocalization.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider.value(
                value: cubit,
                child: ReportRemittancesSection(compact: compact),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return cubit;
    }

    double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

    testWidgets('AC-1.1 AC-1.2 AC-1.3: cards under a heading per day, newest first, read as headings', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, rows, compact: true);

      const today = 'Hoy · Viernes 2 oct';
      const yesterday = 'Ayer · Jueves 1 oct';
      expect(find.text(today), findsOneWidget);
      expect(find.text(yesterday), findsOneWidget);
      expect(find.text('1 remesa · 200,00 USD'), findsOneWidget);
      expect(find.text('1 remesa · 100,00 USD · 1 anulada'), findsOneWidget);
      // Each day: heading, then its rows, then the next day (BR-3).
      expect(top(tester, today), lessThan(top(tester, 'OT-B1')));
      expect(top(tester, 'OT-B1'), lessThan(top(tester, yesterday)));
      expect(top(tester, yesterday), lessThan(top(tester, 'OT-A2')));
      // One card per day.
      expect(find.ancestor(of: find.text('OT-A1'), matching: find.byType(Card)), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
      expect(
        tester.getSemantics(find.text(today)),
        matchesSemantics(isHeader: true, label: '$today\n1 remesa · 200,00 USD'),
      );
      semantics.dispose();
    });

    testWidgets('AC-2.1 AC-2.3: a day row in the wide table; flipping the sort flips the days', (tester) async {
      final cubit = await pump(tester, rows, compact: false);

      const first = 'Ayer · Jueves 1 oct';
      expect(find.text('1 remesa · enviado 100,00 USD · comisiones 10,00 USD · 1 anulada'), findsOneWidget);
      expect(find.text('1 remesa · enviado 200,00 USD · comisiones 20,00 USD'), findsOneWidget);
      expect(top(tester, 'Hoy · Viernes 2 oct'), lessThan(top(tester, first)));
      // CR-2: the summary follows the date, 16 px after it, on screen at panel widths.
      final dateRight = tester.getTopRight(find.text(first)).dx;
      final summaryLeft = tester
          .getTopLeft(find.text('1 remesa · enviado 100,00 USD · comisiones 10,00 USD · 1 anulada'))
          .dx;
      expect(summaryLeft - dateRight, moreOrLessEquals(16, epsilon: 0.5));

      await tester.tap(find.text('${ReportTexts.registered} ↓'));
      await tester.pumpAndSettle();

      expect(cubit.state.filter.newestFirst, isFalse);
      expect(top(tester, first), lessThan(top(tester, 'OT-A1')));
      expect(top(tester, 'OT-A2'), lessThan(top(tester, 'Hoy · Viernes 2 oct')));
    });

    testWidgets('AC-2.4: a filter that leaves nothing shows no heading, only the empty state', (tester) async {
      await pump(tester, rows, compact: false);

      await tester.enterText(find.byType(TextField), 'nada');
      await tester.pumpAndSettle();

      expect(find.text(ReportTexts.noRemittancesFound), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d oct$')), findsNothing);
      expect(find.textContaining(RegExp('remesas? ·')), findsNothing);
    });

    testWidgets('AC-1.4 AC-2.2: a day that goes on to the next page starts it with the same heading and summary', (
      tester,
    ) async {
      // 45 rows on Oct 1 and 10 on Oct 2: newest first, page 1 ends inside Oct 1.
      final many = [
        for (var i = 0; i < 45; i++) _json('OT-A$i', '2026-10-01T13:${i.toString().padLeft(2, '0')}:00Z'),
        for (var i = 0; i < 10; i++) _json('OT-B$i', '2026-10-02T13:${i.toString().padLeft(2, '0')}:00Z'),
      ];
      final cubit = await pump(tester, many, compact: true);
      const heading = 'Ayer · Jueves 1 oct';
      const summary = '45 remesas · 4.500,00 USD';

      expect(find.text(heading), findsOneWidget);
      expect(find.text(summary), findsOneWidget);

      cubit.page(1);
      await tester.pumpAndSettle();

      expect(find.text(heading), findsOneWidget);
      expect(find.text(summary), findsOneWidget);
      expect(find.text('Hoy · Viernes 2 oct'), findsNothing);
    });
  });
}
