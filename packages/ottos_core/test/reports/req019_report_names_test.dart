import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

import 'fixtures.dart';

class _MockReports extends Mock implements ReportRepository {}

/// Tester round for REQ-019 (frontend): the report detail names each
/// remittance by its beneficiary, in the table, the cards, the search, the
/// CSV and the PDF. Expected results come from 01-user-stories.md.
void main() {
  late _MockReports reports;
  final report = MonthlyReport.fromJson(monthlyJson);

  setUpAll(() async {
    registerFallbackValue(DateTime(2000));
    await OttosLocalization.initialize();
  });

  setUp(() {
    reports = _MockReports();
    when(() => reports.monthlyRemittances(any(), any()))
        .thenAnswer((_) async => MonthlyReportDetail.fromJson(detailJson));
  });

  Future<void> pump(WidgetTester tester, {required bool compact, double textScale = 1}) async {
    await tester.binding.setSurfaceSize(compact ? const Size(390, 2400) : const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: OttosLocalization.delegates,
        supportedLocales: OttosLocalization.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider(
              create: (_) => ReportRemittancesCubit(reports: reports, month: DateTime(2026, 10))..load(),
              child: ReportRemittancesSection(compact: compact),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder titleOf(String code) => find.byWidgetPredicate((w) => w is RemittanceTitle && w.code == code);

  for (final compact in [false, true]) {
    final where = compact ? 'phone cards' : 'table';

    testWidgets('AC-3.1 ($where): each row shows the beneficiary name and its code', (tester) async {
      await pump(tester, compact: compact);

      final pickup = tester.widget<RemittanceTitle>(titleOf('OT-P3X8RA'));
      expect(pickup.name, 'Juan Gómez', reason: 'AC-1.3: for a pickup, the person the cash is collected from');
      final name = find.descendant(of: titleOf('OT-P3X8RA'), matching: find.text('Juan Gómez'));
      final code = find.descendant(of: titleOf('OT-P3X8RA'), matching: find.text('OT-P3X8RA'));
      expect(name, findsOneWidget);
      expect(code, findsOneWidget, reason: 'BR-2: the code stays visible');
      expect(tester.getTopLeft(code).dy, greaterThan(tester.getTopLeft(name).dy), reason: 'name first');
    });

    testWidgets('AC-3.1 ($where, no name): the code alone takes the title', (tester) async {
      await pump(tester, compact: compact);

      expect(tester.widget<RemittanceTitle>(titleOf('OT-H2N6LC')).name, isNull);
      expect(find.descendant(of: titleOf('OT-H2N6LC'), matching: find.byType(Text)), findsOneWidget);
    });

    testWidgets('AC-1.4 ($where): same beneficiary twice, told apart by code', (tester) async {
      await pump(tester, compact: compact);

      final rosa = find.byWidgetPredicate((w) => w is RemittanceTitle && w.name == 'Rosa Pérez');
      expect(rosa.evaluate().length, greaterThan(1));
      for (final code in ['OT-K7Q2MA', 'OT-R9T4BW', 'OT-F9V3GA']) {
        expect(find.descendant(of: titleOf(code), matching: find.text(code)), findsOneWidget);
      }
    });
  }

  testWidgets('REQ-019 CR-1: with large text, the table row grows instead of overflowing', (tester) async {
    await pump(tester, compact: false, textScale: 2.5);

    expect(tester.takeException(), isNull);
    final title = tester.getSize(titleOf('OT-P3X8RA'));
    expect(title.height, greaterThan(52), reason: 'two large lines do not fit in the old fixed 52 px');
  });

  testWidgets('AC-3.1 (search): the box finds a remittance by name, any case, and still by code', (tester) async {
    await pump(tester, compact: false);

    await tester.enterText(find.byType(TextField), 'JUAN');
    await tester.pumpAndSettle();
    expect(titleOf('OT-P3X8RA'), findsOneWidget);
    expect(titleOf('OT-K7Q2MA'), findsNothing);

    await tester.enterText(find.byType(TextField), 'h2n');
    await tester.pumpAndSettle();
    expect(titleOf('OT-H2N6LC'), findsOneWidget, reason: 'the code still works');

    await tester.enterText(find.byType(TextField), 'nadie');
    await tester.pumpAndSettle();
    expect(find.byType(RemittanceTitle), findsNothing);
  });

  testWidgets('AC-3.1 (search label): the search box says it matches names', (tester) async {
    await pump(tester, compact: false);
    expect(find.text(ReportTexts.searchCode), findsOneWidget);
    expect(ReportTexts.searchCode.toLowerCase(), contains('nombre'));
  });

  group('CSV', () {
    MonthlyReportDetail withName(String? name) => MonthlyReportDetail.fromJson({
      ...detailJson,
      'remittances': [
        {...(detailJson['remittances'] as List).first as Map<String, dynamic>, 'beneficiaryName': name},
      ],
    });

    test('AC-3.1: Beneficiario is the first column, Código the second, in every row', () {
      final rows = Csv.decode(ReportCsv.encode(MonthlyReportDetail.fromJson(detailJson)));
      expect(rows.first.take(2), ['Beneficiario', 'Código']);
      expect(rows.every((row) => row.length == ReportCsv.columns.length), isTrue);
      expect(rows.skip(1).map((row) => row[1]).every((code) => code.startsWith('OT-')), isTrue);
    });

    test('AC-3.1 (separator, quotes, accents): a tricky name stays one cell', () {
      const name = 'Pérez; "Rosa", Ñandú\nsegunda línea';
      final rows = Csv.decode(ReportCsv.encode(withName(name)));
      expect(rows, hasLength(2));
      expect(rows[1][0], name);
      expect(rows[1][1], 'OT-K7Q2MA');
      expect(rows[1], hasLength(ReportCsv.columns.length));
    });

    test('AC-3.1 (formula): a name that starts like a formula cannot run in a spreadsheet', () {
      for (final name in ['=HYPERLINK("https://example.test")', '@SUM(1)', '+cmd|calc', '-2+3x']) {
        final cell = Csv.decode(ReportCsv.encode(withName(name)))[1][0];
        expect(cell, startsWith("'"), reason: name);
      }
    });

    test('AC-3.1 (empty name): an empty cell, not the word null', () {
      expect(Csv.decode(ReportCsv.encode(withName(null)))[1][0], '');
    });
  });

  group('model', () {
    test('AC-3.1: the name is read from beneficiaryName and counts for equality', () {
      ReportRemittance row(String name) =>
          ReportRemittance.fromJson({'id': 'x', 'code': 'OT-1', 'beneficiaryName': name});
      expect(row('Ana').beneficiaryName, 'Ana');
      expect(row('Ana'), row('Ana'));
      expect(row('Ana'), isNot(row('Eva')));
    });

    test('AC-3.1 (old backend): a row without the field still reads, with no name', () {
      expect(ReportRemittance.fromJson({'id': 'x', 'code': 'OT-1'}).beneficiaryName, isNull);
    });

    test('AC-3.1 (filter): a blank search matches everything, a name part only its row', () {
      final rows = MonthlyReportDetail.fromJson(detailJson).remittances;
      expect(rows.where(const ReportFilter(code: '  ').matches), hasLength(rows.length));
      expect(rows.where(const ReportFilter(code: 'gómez').matches).map((r) => r.code), ['OT-P3X8RA']);
    });
  });

  group('PDF', () {
    test('AC-3.1: the detailed PDF builds with names, a missing name and an unusual name', () async {
      final names = ['Rosa Pérez', null, '', 'Ñandú 🙂 ${'Larguísimo ' * 12}', 'Ana — María'];
      final detail = MonthlyReportDetail.fromJson({
        ...detailJson,
        'remittances': [
          for (var i = 0; i < names.length; i++)
            {
              ...(detailJson['remittances'] as List)[i % 3] as Map<String, dynamic>,
              'beneficiaryName': names[i],
              'code': 'OT-N$i',
            },
        ],
      });
      final bytes = await buildMonthlyDetailPdf(report, detail, month: DateTime(2026, 10));
      expect(String.fromCharCodes(bytes).startsWith('%PDF-'), isTrue);
    });

    test('AC-3.1: the PDF no longer says it has no personal data', () async {
      final detail = MonthlyReportDetail.fromJson(detailJson);
      final bytes = await buildMonthlyDetailPdf(report, detail, month: DateTime(2026, 10));
      expect(latin1.decode(bytes), isNot(contains('sin datos personales')));
    });
  });

  testWidgets('AC-1.2 (complete from business dialog): the title names the beneficiary and the code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: OttosLocalization.delegates,
        supportedLocales: OttosLocalization.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => askCompleteFromBusiness(
              context,
              const Remittance(
                id: 'r1',
                code: 'OT-ABC123',
                type: RemittanceType.delivery,
                status: 'ASSIGNED',
                statusName: 'Asignada',
                beneficiaryName: 'Rosa Pérez',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(CoreTexts.byBusinessTitle('Rosa Pérez · OT-ABC123', isPickup: false)), findsOneWidget);
  });
}
