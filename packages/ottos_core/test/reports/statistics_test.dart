import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

import 'fixtures.dart';

class _MockReports extends Mock implements ReportRepository {}

void main() {
  setUpAll(OttosLocalization.initialize);

  group('model', () {
    test('reads the contract: totals, weeks, months, days and municipalities', () {
      final statistics = Statistics.fromJson(statisticsJson());

      expect(statistics.from, DateTime(2026, 9, 28));
      expect(statistics.totals.remittances, 23);
      expect(statistics.totals.onTheHouse.remittances, 1);
      expect(statistics.byWeek, hasLength(4));
      expect(statistics.byWeek.first.key, '2026-W40');
      expect(statistics.byWeek.first.from, DateTime(2026, 9, 28));
      expect(statistics.byMonth.first.partial, isTrue);
      expect(statistics.byDayOfWeek, hasLength(7));
      expect(DayOfWeek.fromCode(statistics.byDayOfWeek.last.key), DayOfWeek.sunday);
      expect(statistics.byMunicipality.single.name, 'Plaza de la Revolución');
      expect(statistics.hasFewData, isFalse);
    });

    test('each grouping adds up to the totals', () {
      final statistics = Statistics.fromJson(statisticsJson());
      int sum(List<StatisticsGroup> groups) => groups.fold(0, (total, group) => total + group.figures.remittances);

      expect(sum(statistics.byWeek), statistics.totals.remittances);
      expect(sum(statistics.byDayOfWeek), statistics.totals.remittances);
      expect(sum(statistics.byMunicipality), statistics.totals.remittances);
    });

    test('below 10 remittances it has few data', () {
      expect(Statistics.fromJson(statisticsJson(weekly: [2, 1])).hasFewData, isTrue);
    });

    test('the day names are translated', () {
      expect(ReportTexts.dayName(DayOfWeek.wednesday), 'Miércoles');
      expect(ReportTexts.dayShort(DayOfWeek.saturday), 'Sáb');
    });
  });

  group('periods', () {
    final today = DateTime(2026, 10, 23);

    test('current month, previous month and the last three', () {
      expect(StatisticsCubit.rangeFor(StatisticsPeriod.currentMonth, today), (from: DateTime(2026, 10), to: today));
      expect(StatisticsCubit.rangeFor(StatisticsPeriod.previousMonth, today), (
        from: DateTime(2026, 9),
        to: DateTime(2026, 9, 30),
      ));
      expect(StatisticsCubit.rangeFor(StatisticsPeriod.lastThreeMonths, today), (from: DateTime(2026, 8), to: today));
      expect(StatisticsCubit.rangeFor(StatisticsPeriod.previousMonth, DateTime(2026, 1, 5)), (
        from: DateTime(2025, 12),
        to: DateTime(2025, 12, 31),
      ));
    });

    test('the period before is as long', () {
      // The month so far, against the same days of the month before.
      expect(StatisticsCubit.previousRange(DateTime(2026, 10), today), (
        from: DateTime(2026, 9),
        to: DateTime(2026, 9, 23),
      ));
      // A whole month, against the whole month before.
      expect(StatisticsCubit.previousRange(DateTime(2026, 3), DateTime(2026, 3, 31)), (
        from: DateTime(2026, 2),
        to: DateTime(2026, 2, 28),
      ));
      expect(StatisticsCubit.previousRange(DateTime(2026, 8), today), (
        from: DateTime(2026, 5),
        to: DateTime(2026, 7, 23),
      ));
      // Any other range: as many days before.
      expect(StatisticsCubit.previousRange(DateTime(2026, 10, 10), DateTime(2026, 10, 16)), (
        from: DateTime(2026, 10, 3),
        to: DateTime(2026, 10, 9),
      ));
    });
  });

  group('cubit', () {
    late _MockReports reports;
    final today = DateTime(2026, 10, 23);

    setUp(() {
      reports = _MockReports();
      registerFallbackValue(DateTime(2000));
    });

    test('loads the period and the one before it', () async {
      when(() => reports.statistics(any(), any())).thenAnswer((_) async => Statistics.fromJson(statisticsJson()));
      final cubit = StatisticsCubit(reports: reports, today: today);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, StatisticsStatus.success);
      expect(cubit.state.previous, isNotNull);
      verify(() => reports.statistics(DateTime(2026, 10), today)).called(1);
      verify(() => reports.statistics(DateTime(2026, 9), DateTime(2026, 9, 23))).called(1);
    });

    test('a backend without statistics (404) leaves a friendly notice', () async {
      when(() => reports.statistics(any(), any())).thenThrow(const ApiException('No', statusCode: 404));
      final cubit = StatisticsCubit(reports: reports, today: today);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, StatisticsStatus.unavailable);
    });

    test('the comparison failing does not stop the statistics', () async {
      when(() => reports.statistics(DateTime(2026, 10), today))
          .thenAnswer((_) async => Statistics.fromJson(statisticsJson()));
      when(() => reports.statistics(DateTime(2026, 9), DateTime(2026, 9, 23)))
          .thenThrow(const ApiException('Error', statusCode: 500));
      final cubit = StatisticsCubit(reports: reports, today: today);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, StatisticsStatus.success);
      expect(cubit.state.previous, isNull);
    });

    test('choosing a period loads it', () async {
      when(() => reports.statistics(any(), any())).thenAnswer((_) async => Statistics.fromJson(statisticsJson()));
      final cubit = StatisticsCubit(reports: reports, today: today);
      addTearDown(cubit.close);

      await cubit.select(StatisticsPeriod.lastThreeMonths);
      expect(cubit.state.from, DateTime(2026, 8));

      await cubit.custom(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      expect(cubit.state.period, StatisticsPeriod.custom);
      verify(() => reports.statistics(DateTime(2026, 1, 1), DateTime(2026, 1, 31))).called(1);
    });
  });

  group('remittances cubit', () {
    late _MockReports reports;

    setUp(() => reports = _MockReports());

    test('loads the month, filters and pages', () async {
      when(() => reports.monthlyRemittances(2026, 10))
          .thenAnswer((_) async => MonthlyReportDetail.fromJson(detailJson));
      final cubit = ReportRemittancesCubit(reports: reports, month: DateTime(2026, 10, 23));
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, ReportDetailStatus.success);
      expect(cubit.state.filtered, hasLength(5));
      expect(cubit.state.totals.collected, 402);
      expect(cubit.state.couriers, [ReportFilter.withoutCourier, 'Ana Pérez', 'Pedro Díaz']);

      cubit.filter(cubit.state.filter.copyWith(type: () => 'PICKUP'));
      expect(cubit.state.filtered.single.code, 'OT-P3X8RA');
      expect(cubit.state.totals.collected, 0);
      expect(cubit.state.totals.pickupCollected, 200);
    });

    test('a backend without the detail (404) leaves a friendly notice', () async {
      when(() => reports.monthlyRemittances(any(), any())).thenThrow(const ApiException('No', statusCode: 404));
      final cubit = ReportRemittancesCubit(reports: reports, month: DateTime(2026, 10));
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, ReportDetailStatus.unavailable);
    });

    test('other errors can be retried', () async {
      when(() => reports.monthlyRemittances(any(), any())).thenThrow(const ApiException('Sin red'));
      final cubit = ReportRemittancesCubit(reports: reports, month: DateTime(2026, 10));
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, ReportDetailStatus.failure);
      expect(cubit.state.error, 'Sin red');
    });
  });

  group('Cuba time', () {
    test('UTC−4 in summer, UTC−5 in winter, whatever the device zone', () {
      expect(CubaTime.of(DateTime.utc(2026, 10, 1, 16, 30)), DateTime.utc(2026, 10, 1, 12, 30));
      expect(CubaTime.of(DateTime.utc(2026, 12, 1, 16, 30)), DateTime.utc(2026, 12, 1, 11, 30));
      // 2026: from Sunday 8 March to Sunday 1 November, both at 05:00 UTC.
      expect(CubaTime.isDaylightSaving(DateTime.utc(2026, 3, 8, 4, 59)), isFalse);
      expect(CubaTime.isDaylightSaving(DateTime.utc(2026, 3, 8, 5)), isTrue);
      expect(CubaTime.isDaylightSaving(DateTime.utc(2026, 11, 1, 4, 59)), isTrue);
      expect(CubaTime.isDaylightSaving(DateTime.utc(2026, 11, 1, 5)), isFalse);
    });

    test('today is Cuba\'s date', () {
      // 02:00 UTC on the 1st is still the 31st in Havana.
      expect(CubaTime.today(DateTime.utc(2026, 11, 1, 2)), DateTime(2026, 10, 31));
    });
  });
}
