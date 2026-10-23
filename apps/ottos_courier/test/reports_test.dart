import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/reports/view/reports_page.dart';
import 'package:ottos_courier/features/reports/view/statistics_page.dart';
import 'package:ottos_courier/shell/courier_shell.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockReports extends Mock implements ReportRepository {}

/// Sales during the day, with the reports.
const _sales = {
  Permissions.remittancesRead,
  Permissions.remittancesCreate,
  Permissions.cashRead,
  Permissions.reportsRead,
};

const _courier = {Permissions.remittancesReadAssigned, Permissions.remittancesDeliver, Permissions.cashReadOwn};

CurrentUser _user(Set<String> permissions) =>
    CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: const [], permissions: permissions);

final _monthly = {
  'month': '2026-10',
  'businessCurrency': 'USD',
  'remittances': {'total': 1, 'delivery': 1, 'pickup': 0, 'completed': 1, 'open': 0, 'withIncident': 0},
  'collected': 110.0,
  'fees': 10.0,
};

final _detail = {
  'month': '2026-10',
  'businessCurrency': 'USD',
  'counts': {'lines': 1, 'voided': 0, 'total': 1, 'delivery': 1},
  'remittances': [
    {
      'id': 'r1',
      'code': 'OT-K7Q2MA',
      'type': 'DELIVERY',
      'status': 'DELIVERED',
      'createdAt': '2026-10-01T16:30:00Z',
      'municipalityName': 'Playa',
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
  ],
};

void main() {
  setUpAll(() async {
    registerFallbackValue(DateTime(2000));
    await OttosLocalization.initialize();
  });

  group('who sees Reportes and Estadísticas', () {
    test('sales with reports:read; never a courier, never without the permission', () {
      expect(CourierShell.canSeeReports(_user(_sales)), isTrue);
      expect(CourierShell.canSeeReports(_user(_sales.difference({Permissions.reportsRead}))), isFalse);
      expect(CourierShell.canSeeReports(_user({..._courier, Permissions.reportsRead})), isFalse);
    });

    Future<void> pumpShell(WidgetTester tester, Set<String> permissions) async {
      final auth = _MockAuth();
      when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
      final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)..add(AuthLoggedIn(_user(permissions)));
      addTearDown(authBloc.close);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AuthRepository>.value(value: auth),
            RepositoryProvider.value(value: const AppConfig(apiUrl: '')),
          ],
          child: BlocProvider.value(
            value: authBloc,
            child: const MaterialApp(
              home: CourierShell(location: '/reports', child: SizedBox()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('sales with the permission: four sections, Reportes selected', (tester) async {
      await pumpShell(tester, _sales);

      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.widgetWithText(NavigationDestination, ReportTexts.reports), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, ReportTexts.statistics), findsOneWidget);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    });

    testWidgets('sales without it: as before', (tester) async {
      await pumpShell(tester, _sales.difference({Permissions.reportsRead}));

      expect(find.byType(NavigationDestination), findsNWidgets(2));
      expect(find.text(ReportTexts.statistics), findsNothing);
    });

    testWidgets('a courier: as before', (tester) async {
      await pumpShell(tester, {..._courier, Permissions.reportsRead});

      expect(find.byType(NavigationDestination), findsNWidgets(2));
      expect(find.widgetWithText(NavigationDestination, CourierTexts.myRemittances), findsOneWidget);
      expect(find.text(ReportTexts.reports), findsNothing);
    });
  });

  group('pages', () {
    late _MockReports reports;

    setUp(() {
      reports = _MockReports();
      when(() => reports.monthly(any(), any())).thenAnswer((_) async => MonthlyReport.fromJson(_monthly));
      when(() => reports.monthlyRemittances(any(), any()))
          .thenAnswer((_) async => MonthlyReportDetail.fromJson(_detail));
    });

    Future<void> pump(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(390, 2400);
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

    testWidgets('Reportes: the month, its remittances as cards and «Exportar»', (tester) async {
      await pump(tester, const ReportsPage());

      expect(find.text(ReportTexts.monthRemittances), findsOneWidget);
      expect(find.text('OT-K7Q2MA'), findsOneWidget);
      expect(find.textContaining('Playa · Pedro Díaz'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, ReportTexts.export));
      await tester.pumpAndSettle();
      expect(find.text(ReportTexts.exportCsv), findsOneWidget);
    });

    testWidgets('an old backend (404): a friendly notice, nothing breaks', (tester) async {
      when(() => reports.monthlyRemittances(any(), any())).thenThrow(const ApiException('No', statusCode: 404));
      when(() => reports.statistics(any(), any())).thenThrow(const ApiException('No', statusCode: 404));

      await pump(tester, const ReportsPage());
      expect(find.text(ReportTexts.notAvailableYet), findsOneWidget);

      await pump(tester, const StatisticsPage());
      expect(find.text(ReportTexts.notAvailableYet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Estadísticas: the period chips and the charts, one under another', (tester) async {
      Map<String, dynamic> figures(int count) => {
        'remittances': count,
        'deliveries': count,
        'collected': count * 110.0,
        'fees': count * 10.0,
        'deliveryAmount': count * 100.0,
        'averageAmount': 100.0,
      };
      when(() => reports.statistics(any(), any())).thenAnswer(
        (_) async => Statistics.fromJson({
          'from': '2026-10-01',
          'to': '2026-10-23',
          'totals': figures(12),
          'byWeek': [
            {'week': '2026-W40', 'from': '2026-10-01', ...figures(12)},
          ],
          'byDayOfWeek': [
            {'dayOfWeek': 'MONDAY', ...figures(12)},
          ],
          'byMunicipality': [
            {'municipalityCode': '2302', 'municipalityName': 'Playa', ...figures(12)},
          ],
        }),
      );

      await pump(tester, const StatisticsPage());

      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.text(ReportTexts.remittancesByWeek), findsOneWidget);
      expect(find.text(ReportTexts.salesByDay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
