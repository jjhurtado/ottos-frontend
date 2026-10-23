import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

import 'fixtures.dart';

class _MockReports extends Mock implements ReportRepository {}

void main() {
  late _MockReports reports;

  setUpAll(() async {
    registerFallbackValue(DateTime(2000));
    await OttosLocalization.initialize();
  });

  setUp(() => reports = _MockReports());

  Future<void> pump(WidgetTester tester, Widget child, {Size size = const Size(1400, 2400)}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: OttosLocalization.delegates,
        supportedLocales: OttosLocalization.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('month remittances', () {
    Widget section({required bool compact, ValueChanged<ReportRemittance>? onOpen}) => BlocProvider(
      create: (_) => ReportRemittancesCubit(reports: reports, month: DateTime(2026, 10))..load(),
      child: ReportRemittancesSection(compact: compact, onOpen: onOpen),
    );

    setUp(() {
      when(() => reports.monthlyRemittances(any(), any()))
          .thenAnswer((_) async => MonthlyReportDetail.fromJson(detailJson));
    });

    testWidgets('a table with every remittance, the voided one with its reason', (tester) async {
      ReportRemittance? opened;
      await pump(tester, section(compact: false, onOpen: (row) => opened = row));

      expect(find.text(ReportTexts.monthRemittances), findsOneWidget);
      for (final code in ['OT-K7Q2MA', 'OT-P3X8RA', 'OT-R9T4BW', 'OT-F9V3GA', 'OT-H2N6LC']) {
        expect(find.text(code), findsOneWidget);
      }
      expect(find.text(ReportTexts.voidedOn('12 oct', reasonWithSeparator)), findsOneWidget);
      expect(find.textContaining('Pedro Díaz'), findsWidgets);
      expect(find.text('Entrega · casa'), findsOneWidget);
      // The filtered totals leave the voided one out.
      expect(find.textContaining(Formatters.money(402, 'USD'), findRichText: true), findsOneWidget);
      expect(find.text(ReportTexts.filteredTotalsNote(1)), findsOneWidget);
      expect(find.text(ReportTexts.pageOf(1, 5, 5)), findsOneWidget);

      await tester.tap(find.text('OT-K7Q2MA'));
      expect(opened?.id, 'id-OT-K7Q2MA');
    });

    testWidgets('searching by code narrows the list and its totals', (tester) async {
      await pump(tester, section(compact: false));

      await tester.enterText(find.byType(TextField), 'h2n');
      await tester.pumpAndSettle();

      expect(find.text('OT-H2N6LC'), findsOneWidget);
      expect(find.text('OT-K7Q2MA'), findsNothing);
      expect(find.textContaining('Cobrado ${Formatters.money(55, 'USD')}', findRichText: true), findsOneWidget);
    });

    testWidgets('cards on a phone, without links if the user may not open them', (tester) async {
      await pump(tester, section(compact: true), size: const Size(390, 2400));

      expect(find.text('OT-K7Q2MA'), findsOneWidget);
      expect(find.text(ReportTexts.filters), findsOneWidget);
      expect(find.textContaining('Entrega · 1 oct · Plaza de la Revolución · Pedro Díaz'), findsOneWidget);
      expect(find.text(ReportTexts.voidedOn('12 oct', reasonWithSeparator)), findsOneWidget);
    });

    testWidgets('a backend without the detail shows a notice, nothing else', (tester) async {
      when(() => reports.monthlyRemittances(any(), any())).thenThrow(const ApiException('No', statusCode: 404));
      await pump(tester, section(compact: true), size: const Size(390, 900));

      expect(find.text(ReportTexts.notAvailableYet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('statistics', () {
    Widget view({required bool compact}) => BlocProvider(
      create: (_) => StatisticsCubit(reports: reports, today: DateTime(2026, 10, 23))..load(),
      child: StatisticsView(compact: compact),
    );

    testWidgets('the five charts with their figures', (tester) async {
      when(() => reports.statistics(any(), any())).thenAnswer((_) async => Statistics.fromJson(statisticsJson()));
      await pump(tester, view(compact: false));

      expect(find.text(ReportTexts.salesByWeek), findsOneWidget);
      expect(find.text(ReportTexts.salesByDay), findsOneWidget);
      expect(find.text(ReportTexts.averageTitle), findsOneWidget);
      expect(find.text(ReportTexts.byMunicipality), findsOneWidget);
      expect(find.text(ReportTexts.onTheHouseTitle), findsOneWidget);
      expect(find.text('23'), findsWidgets);
      expect(find.text('Lun'), findsOneWidget);
      expect(find.text('Plaza de la Revolución'), findsOneWidget);
      expect(find.text(ReportTexts.sameAsBefore), findsOneWidget, reason: 'the same figures before');
      expect(find.text(ReportTexts.fewDataChip), findsNothing);
    });

    testWidgets('more than ten municipalities group the rest in «Otros»', (tester) async {
      when(() => reports.statistics(any(), any())).thenAnswer(
        (_) async => Statistics.fromJson(
          statisticsJson(
            weekly: [13],
            municipalities: [for (var i = 0; i < 12; i++) ('${2300 + i}', 'Municipio $i', i < 11 ? 1 : 2)],
          ),
        ),
      );
      await pump(tester, view(compact: false));

      expect(find.text('Municipio 9'), findsOneWidget);
      expect(find.text('Municipio 10'), findsNothing);
      expect(find.text(ReportTexts.others(2)), findsOneWidget);
    });

    testWidgets('few data: the banner and no comparison', (tester) async {
      when(() => reports.statistics(any(), any()))
          .thenAnswer((_) async => Statistics.fromJson(statisticsJson(weekly: [2], onTheHouse: 0)));
      await pump(tester, view(compact: true), size: const Size(390, 3000));

      expect(find.text(ReportTexts.fewData(2)), findsOneWidget);
      expect(find.text(ReportTexts.seePreviousMonth), findsOneWidget);
      expect(find.text(ReportTexts.fewDataChip), findsWidgets);
      expect(find.textContaining('frente al periodo anterior'), findsNothing);
      expect(find.text(ReportTexts.onTheHouseNone), findsOneWidget);
    });

    testWidgets('a period without remittances: notices in place of the charts', (tester) async {
      when(() => reports.statistics(any(), any()))
          .thenAnswer((_) async => Statistics.fromJson(statisticsJson(weekly: [0], onTheHouse: 0, municipalities: [])));
      await pump(tester, view(compact: false));

      expect(find.text(ReportTexts.noDataFor(ReportTexts.salesByWeek)), findsOneWidget);
      expect(find.text(ReportTexts.noDataFor(ReportTexts.salesByDay)), findsOneWidget);
      expect(find.text(ReportTexts.noDataFor(ReportTexts.byMunicipality)), findsOneWidget);
      expect(find.text(ReportTexts.fewData(0)), findsNothing);
    });

    testWidgets('a backend without statistics shows a notice, nothing else', (tester) async {
      when(() => reports.statistics(any(), any())).thenThrow(const ApiException('No', statusCode: 404));
      await pump(tester, view(compact: true), size: const Size(390, 900));

      expect(find.text(ReportTexts.notAvailableYet), findsOneWidget);
    });
  });
}
