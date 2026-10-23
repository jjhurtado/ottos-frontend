import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/destinations.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/reports/view/statistics_page.dart';
import 'package:ottos_ops/shell/ops_shell.dart';

class _MockReports extends Mock implements ReportRepository {}

class _MockAuth extends Mock implements AuthRepository {}

CurrentUser _user(Set<String> permissions) =>
    CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: const [], permissions: permissions);

Map<String, dynamic> _figures(int remittances) => {
  'remittances': remittances,
  'deliveries': remittances,
  'pickups': 0,
  'deliveryAmount': remittances * 100.0,
  'averageAmount': remittances == 0 ? 0 : 100.0,
  'collected': remittances * 110.0,
  'fees': remittances * 10.0,
  'deliveredCurrency': remittances * 100.0,
  'pickupCollected': 0,
  'onTheHouse': {'remittances': 0, 'amount': 0, 'waivedFees': 0},
};

final _statistics = {
  'from': '2026-10-01',
  'to': '2026-10-23',
  'businessCurrency': 'USD',
  'totals': _figures(12),
  'byWeek': [
    {'week': '2026-W40', 'from': '2026-10-01', 'to': '2026-10-04', 'partial': true, ..._figures(5)},
    {'week': '2026-W41', 'from': '2026-10-05', 'to': '2026-10-11', 'partial': false, ..._figures(7)},
  ],
  'byMonth': [
    {'month': '2026-10', 'from': '2026-10-01', 'to': '2026-10-23', 'partial': true, ..._figures(12)},
  ],
  'byDayOfWeek': [
    for (final day in ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'])
      {'dayOfWeek': day, ..._figures(day == 'FRIDAY' ? 12 : 0)},
  ],
  'byMunicipality': [
    {'municipalityCode': '2302', 'municipalityName': 'Plaza de la Revolución', ..._figures(12)},
  ],
};

void main() {
  late _MockReports reports;

  setUpAll(() async {
    registerFallbackValue(DateTime(2000));
    await OttosLocalization.initialize();
  });

  setUp(() {
    reports = _MockReports();
    when(() => reports.statistics(any(), any())).thenAnswer((_) async => Statistics.fromJson(_statistics));
  });

  Future<void> pump(WidgetTester tester, Widget page, {Size size = const Size(1400, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepositoryProvider<ReportRepository>.value(
        value: reports,
        child: MaterialApp(
          localizationsDelegates: OttosLocalization.delegates,
          supportedLocales: OttosLocalization.supportedLocales,
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the page shows the period, its picker and the charts', (tester) async {
    await pump(tester, const StatisticsPage());

    expect(find.text(OpsTexts.statistics), findsOneWidget);
    expect(find.text(ReportTexts.periodCurrentMonth), findsOneWidget);
    expect(find.text(ReportTexts.periodCustom), findsOneWidget);
    expect(find.textContaining('por fecha de registro'), findsOneWidget);
    expect(find.text(ReportTexts.salesByWeek), findsOneWidget);
    expect(find.text(ReportTexts.byMunicipality), findsOneWidget);
    expect(find.text('Vie'), findsOneWidget);
  });

  testWidgets('choosing «Últimos 3 meses» asks for them', (tester) async {
    await pump(tester, const StatisticsPage());

    await tester.tap(find.text(ReportTexts.periodLastThreeMonths));
    await tester.pumpAndSettle();

    final today = CubaTime.today();
    verify(() => reports.statistics(DateTime(today.year, today.month - 2), today)).called(1);
  });

  testWidgets('works on a phone', (tester) async {
    await pump(tester, const StatisticsPage(), size: const Size(390, 4000));

    expect(find.text(ReportTexts.salesByWeek), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a backend without statistics shows a notice', (tester) async {
    when(() => reports.statistics(any(), any())).thenThrow(const ApiException('No', statusCode: 404));
    await pump(tester, const StatisticsPage());

    expect(find.text(ReportTexts.notAvailableYet), findsOneWidget);
  });

  group('who sees it', () {
    test('only with reports:read, next to Reportes', () {
      expect(Destinations.statistics.isVisibleTo(_user({Permissions.reportsRead})), isTrue);
      expect(Destinations.statistics.isVisibleTo(_user({Permissions.remittancesRead})), isFalse);
      expect(Destinations.all.indexOf(Destinations.statistics), Destinations.all.indexOf(Destinations.reports) + 1);
      expect(Destinations.forLocation('/statistics'), Destinations.statistics);
    });

    Future<void> pumpShell(WidgetTester tester, Set<String> permissions) async {
      final auth = _MockAuth();
      when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
      final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)..add(AuthLoggedIn(_user(permissions)));
      addTearDown(authBloc.close);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepositoryProvider.value(
          value: const AppConfig(apiUrl: ''),
          child: BlocProvider.value(
            value: authBloc,
            child: const MaterialApp(
              home: OpsShell(location: '/', child: SizedBox()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('sales with reports:read see the entry in the menu', (tester) async {
      await pumpShell(tester, {Permissions.remittancesRead, Permissions.reportsRead});
      expect(find.text(OpsTexts.statistics), findsOneWidget);
    });

    testWidgets('sales without reports:read do not', (tester) async {
      await pumpShell(tester, {Permissions.remittancesRead});
      expect(find.text(OpsTexts.statistics), findsNothing);
      expect(find.text(OpsTexts.reports), findsNothing);
    });
  });
}
