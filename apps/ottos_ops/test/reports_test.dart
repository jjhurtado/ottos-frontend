import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/reports/view/reports_page.dart';

class _MockReports extends Mock implements ReportRepository {}

class _MockAuth extends Mock implements AuthRepository {}

/// The contract's example month: pickups apart, nothing delivered on them.
final sampleJson = {
  'month': '2026-10',
  'from': '2026-10-01',
  'to': '2026-10-31',
  'generatedAt': '2026-11-01T12:00:00Z',
  'remittances': {'total': 24, 'delivery': 18, 'pickup': 6, 'completed': 21, 'open': 3, 'withIncident': 1},
  'collected': 1980.00,
  'fees': 220.00,
  'businessCurrency': 'USD',
  'deliveredCurrency': 1799.00,
  'difference': 181.00,
  'roundingMargin': 1.00,
  'pickups': {'remittances': 6, 'collected': 30000.00, 'fees': 40.00},
  'delivered': [
    {'currency': 'CUP', 'amount': 737950.00},
  ],
  'byCurrency': [
    {
      'currency': 'CUP',
      'remittances': 18,
      'sent': 1800.00,
      'fees': 180.00,
      'collected': 1980.00,
      'delivered': 737950.00,
      'deliveredCurrency': 1799.00,
    },
  ],
  'byType': [
    {'type': 'DELIVERY', 'remittances': 18, 'collected': 1980.00, 'fees': 180.00},
    {'type': 'PICKUP', 'remittances': 6, 'collected': 30000.00, 'fees': 40.00},
  ],
};

void main() {
  late _MockReports reports;

  setUpAll(OttosLocalization.initialize);

  setUp(() {
    reports = _MockReports();
    when(() => reports.monthly(any(), any())).thenAnswer((_) async => MonthlyReport.fromJson(sampleJson));
    when(() => reports.monthlyRemittances(any(), any()))
        .thenAnswer((_) async => MonthlyReportDetail.fromJson(const {'month': '2026-10'}));
  });

  test('reads the month and its totals', () {
    final report = MonthlyReport.fromJson(sampleJson);

    expect(report.remittances, 24);
    expect(report.pickups, 6);
    expect(report.difference, 181);
    expect(report.roundingMargin, 1);
    expect(report.pickupsCollected, 30000);
    expect(report.deliveryFees, 180, reason: 'the earnings include the pickups, the difference does not');
    expect(report.byCurrency.first.delivered, 737950);
    expect(report.byType.last.type, RemittanceType.pickup);
    expect(report.deliveredCurrency, 1799);
    expect(report.byCurrency.first.deliveredCurrency, 1799);
    expect(report.businessCurrency, 'USD');
  });

  test('a backend before 1.0.0-rc.4 still reads, with its old name', () {
    final old =
        {
            ...sampleJson,
            'deliveredUsd': 1799.00,
            'byCurrency': [
              {'currency': 'CUP', 'remittances': 18, 'delivered': 737950.00, 'deliveredUsd': 1799.00},
            ],
          }
          ..remove('businessCurrency')
          ..remove('deliveredCurrency');
    final report = MonthlyReport.fromJson(old);

    expect(report.deliveredCurrency, 1799);
    expect(report.byCurrency.first.deliveredCurrency, 1799);
    expect(report.businessCurrency, 'USD');
  });

  test('the PDF is one A4 page', () async {
    final bytes = await buildMonthlyReportPdf(MonthlyReport.fromJson(sampleJson), month: DateTime(2026, 10));

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes).contains('/Count 1'), isTrue, reason: 'one page');
  });

  test('the month title reads in Spanish', () {
    expect(ReportTexts.monthTitle(DateTime(2026, 10)), 'Octubre de 2026');
  });

  group('cubit', () {
    test('starts at the current month and never goes past it', () async {
      final cubit = ReportsCubit(reports: reports);
      addTearDown(cubit.close);
      final now = DateTime.now();
      await cubit.load();
      verify(() => reports.monthly(now.year, now.month)).called(1);

      await cubit.moveMonth(1);
      expect(cubit.state.month, DateTime(now.year, now.month));

      await cubit.moveMonth(-1);
      final previous = DateTime(now.year, now.month - 1);
      verify(() => reports.monthly(previous.year, previous.month)).called(1);
    });
  });

  group('page', () {
    Future<void> pump(WidgetTester tester, {Size size = const Size(1400, 1300)}) async {
      final auth = _MockAuth();
      when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
      final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
        ..add(
          const AuthLoggedIn(
            CurrentUser(
              id: 'u1',
              email: 'sales@ottos.test',
              name: 'Ventas',
              type: '',
              roles: [],
              permissions: {Permissions.reportsRead, Permissions.remittancesRead},
            ),
          ),
        );
      addTearDown(authBloc.close);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepositoryProvider<ReportRepository>.value(
          value: reports,
          child: BlocProvider.value(
            value: authBloc,
            child: MaterialApp(
              localizationsDelegates: OttosLocalization.delegates,
              supportedLocales: OttosLocalization.supportedLocales,
              home: const Scaffold(body: ReportsPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the totals of the month', (tester) async {
      await pump(tester);

      expect(find.text(OpsTexts.totalCollected), findsOneWidget);
      expect(find.text(Formatters.money(1980, 'USD')), findsWidgets);
      expect(find.text(Formatters.money(220, 'USD')), findsWidgets);
      expect(
        find.text(
          OpsTexts.earningsHelp(Formatters.money(180, 'USD'), Formatters.money(40, 'USD'), Formatters.money(1, 'USD')),
        ),
        findsOneWidget,
      );
      expect(find.text(OpsTexts.pickupsCollected), findsOneWidget);
      // The deliveries' total row: 18 of them and their 180 of fees, not the month's 24 and 220.
      expect(find.text('18'), findsWidgets);
      expect(find.text(Formatters.money(180, 'USD')), findsWidgets);
      expect(find.text(OpsTexts.pickupsHelp(6, Formatters.money(40, 'USD'))), findsOneWidget);
      expect(find.text(Formatters.money(737950, 'CUP')), findsWidgets);
      expect(find.widgetWithText(FilledButton, ReportTexts.export), findsOneWidget);
    });

    testWidgets('a month without sales says so and has nothing to export', (tester) async {
      when(() => reports.monthly(any(), any()))
          .thenAnswer((_) async => MonthlyReport.fromJson(const {'month': '2026-09'}));
      await pump(tester);

      expect(find.text(OpsTexts.noSales), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, ReportTexts.export));
      expect(button.onPressed, isNull);
    });

    testWidgets('shows the on the house block, also in the PDF', (tester) async {
      final json = {
        ...sampleJson,
        'onTheHouse': {'remittances': 2, 'amount': 237.00, 'waivedFees': 30.00},
      };
      when(() => reports.monthly(any(), any())).thenAnswer((_) async => MonthlyReport.fromJson(json));
      await pump(tester);

      expect(find.text(OpsTexts.onTheHouseReport), findsOneWidget);
      expect(find.text(Formatters.money(30, 'USD')), findsOneWidget);
      expect(find.text(OpsTexts.onTheHouseHelp(2, Formatters.money(237, 'USD'))), findsOneWidget);

      final bytes = await tester.runAsync(
        () => buildMonthlyReportPdf(MonthlyReport.fromJson(json), month: DateTime(2026, 10)),
      );
      expect(String.fromCharCodes(bytes!).contains('/Count 1'), isTrue, reason: 'still one page');
    });

    testWidgets('a backend without the block shows none', (tester) async {
      await pump(tester);
      expect(find.text(OpsTexts.onTheHouseReport), findsNothing);
    });

    testWidgets('the month remittances under the summary, and the three exports', (tester) async {
      when(() => reports.monthlyRemittances(any(), any()))
          .thenAnswer((_) async => MonthlyReportDetail.fromJson(detailJson));
      await pump(tester, size: const Size(1400, 2400));

      expect(find.text(ReportTexts.monthRemittances), findsOneWidget);
      expect(find.text('OT-K7Q2MA'), findsOneWidget);
      expect(find.text('OT-F9V3GA'), findsOneWidget);
      expect(find.text(ReportTexts.voidedOn('12 oct', 'Registrada dos veces')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, ReportTexts.export));
      await tester.pumpAndSettle();
      for (final item in [ReportTexts.exportSummaryPdf, ReportTexts.exportDetailPdf, ReportTexts.exportCsv]) {
        final button = tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, item));
        expect(button.onPressed, isNotNull, reason: item);
      }
    });

    testWidgets('a backend without the detail: the summary as always, a notice instead of the list', (tester) async {
      when(() => reports.monthlyRemittances(any(), any())).thenThrow(const ApiException('No', statusCode: 404));
      await pump(tester, size: const Size(1400, 2400));

      expect(find.text(OpsTexts.totalCollected), findsOneWidget);
      expect(find.text(ReportTexts.notAvailableYet), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, ReportTexts.export));
      await tester.pumpAndSettle();
      MenuItemButton item(String text) => tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, text));
      expect(item(ReportTexts.exportSummaryPdf).onPressed, isNotNull);
      expect(item(ReportTexts.exportDetailPdf).onPressed, isNull);
      expect(item(ReportTexts.exportCsv).onPressed, isNull);
    });

    testWidgets('on a phone the remittances are cards', (tester) async {
      when(() => reports.monthlyRemittances(any(), any()))
          .thenAnswer((_) async => MonthlyReportDetail.fromJson(detailJson));
      await pump(tester, size: const Size(390, 3600));

      expect(find.text('OT-K7Q2MA'), findsOneWidget);
      expect(find.text(ReportTexts.filters), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Two remittances: a delivery and a voided one, without personal data.
final detailJson = <String, dynamic>{
  'month': '2026-10',
  'businessCurrency': 'USD',
  'counts': {'lines': 2, 'voided': 1, 'total': 1, 'delivery': 1},
  'remittances': [
    {
      'id': 'r1',
      'code': 'OT-K7Q2MA',
      'type': 'DELIVERY',
      'status': 'DELIVERED',
      'createdAt': '2026-10-01T16:30:00Z',
      'municipalityName': 'Plaza de la Revolución',
      'courierName': 'Pedro Díaz',
      'targetCurrency': 'CUP',
      'amount': 100,
      'fee': 10,
      'total': 110,
      'rate': 410,
      'amountToDeliver': 41000,
      'collected': 110,
      'deliveredCurrency': 100,
    },
    {
      'id': 'r2',
      'code': 'OT-F9V3GA',
      'type': 'DELIVERY',
      'status': 'PAID',
      'createdAt': '2026-10-11T19:20:00Z',
      'municipalityName': 'Cerro',
      'targetCurrency': 'CUP',
      'amount': 80,
      'fee': 8,
      'total': 88,
      'rate': 410,
      'amountToDeliver': 32800,
      'collected': 88,
      'deliveredCurrency': 80,
      'voided': {'at': '2026-10-12T13:03:00Z', 'byName': 'Admin', 'reason': 'Registrada dos veces'},
    },
  ],
};
