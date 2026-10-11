import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/reports/cubit/reports_cubit.dart';
import 'package:ottos_ops/features/reports/view/monthly_report_pdf.dart';
import 'package:ottos_ops/features/reports/view/reports_page.dart';

class _MockReports extends Mock implements ReportRepository {}

/// The contract's example month.
final sampleJson = {
  'month': '2026-10',
  'from': '2026-10-01',
  'to': '2026-10-31',
  'generatedAt': '2026-11-01T12:00:00Z',
  'remittances': {'total': 24, 'delivery': 18, 'pickup': 6, 'completed': 21, 'open': 3, 'withIncident': 1},
  'collected': 2640.00,
  'fees': 240.00,
  'deliveredUsd': 2399.00,
  'difference': 241.00,
  'delivered': [
    {'currency': 'CUP', 'amount': 1367240.00},
    {'currency': 'USD', 'amount': 600.00},
  ],
  'byCurrency': [
    {
      'currency': 'CUP',
      'remittances': 16,
      'sent': 1800.00,
      'fees': 180.00,
      'collected': 1980.00,
      'delivered': 1367240.00,
      'deliveredUsd': 1799.00,
    },
    {
      'currency': 'USD',
      'remittances': 8,
      'sent': 600.00,
      'fees': 60.00,
      'collected': 660.00,
      'delivered': 600.00,
      'deliveredUsd': 600.00,
    },
  ],
  'byType': [
    {'type': 'DELIVERY', 'remittances': 18, 'collected': 1980.00, 'fees': 180.00},
    {'type': 'PICKUP', 'remittances': 6, 'collected': 660.00, 'fees': 60.00},
  ],
};

void main() {
  late _MockReports reports;

  setUpAll(OttosLocalization.initialize);

  setUp(() {
    reports = _MockReports();
    when(() => reports.monthly(any(), any())).thenAnswer((_) async => MonthlyReport.fromJson(sampleJson));
  });

  test('reads the month and its totals', () {
    final report = MonthlyReport.fromJson(sampleJson);

    expect(report.remittances, 24);
    expect(report.pickups, 6);
    expect(report.difference, 241);
    expect(report.rounding, 1);
    expect(report.byCurrency.first.delivered, 1367240);
    expect(report.byType.last.type, RemittanceType.pickup);
  });

  test('the PDF is one A4 page', () async {
    final bytes = await buildMonthlyReportPdf(MonthlyReport.fromJson(sampleJson), month: DateTime(2026, 10));

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes).contains('/Count 1'), isTrue, reason: 'one page');
  });

  test('the month title reads in Spanish', () {
    expect(monthTitle(DateTime(2026, 10)), 'Octubre de 2026');
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
    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepositoryProvider<ReportRepository>.value(
          value: reports,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: const Scaffold(body: ReportsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the totals of the month', (tester) async {
      await pump(tester);

      expect(find.text(OpsTexts.totalCollected), findsOneWidget);
      expect(find.text(Formatters.money(2640, 'USD')), findsWidgets);
      expect(find.text(Formatters.money(240, 'USD')), findsWidgets);
      expect(find.text(OpsTexts.roundingNote(Formatters.money(1, 'USD'))), findsOneWidget);
      expect(find.text(Formatters.money(1367240, 'CUP')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, OpsTexts.exportPdf), findsOneWidget);
    });

    testWidgets('a month without sales says so and has nothing to export', (tester) async {
      when(() => reports.monthly(any(), any()))
          .thenAnswer((_) async => MonthlyReport.fromJson(const {'month': '2026-09'}));
      await pump(tester);

      expect(find.text(OpsTexts.noSales), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, OpsTexts.exportPdf));
      expect(button.onPressed, isNull);
    });
  });
}
