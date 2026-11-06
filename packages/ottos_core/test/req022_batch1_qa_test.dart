import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

const _es = Locale('es');

/// REQ-022 batch 1, tester's checks of the shared package (expected results from 03-implementation.md and the
/// behaviour of 1.0.0-rc.11, not from the new code).
void main() {
  setUpAll(OttosLocalization.initialize);

  group('OPT-F1: the Spanish-only delegates give what the Global ones gave', () {
    final dates = [DateTime(2026, 1, 1), DateTime(2026, 11, 6, 9, 5), DateTime(2027, 12, 31, 23, 59)];

    test('OPT-F1: Material dates, numbers, times and labels equal GlobalMaterialLocalizations in Spanish', () async {
      final mine = await OttosLocalization.delegates
          .whereType<LocalizationsDelegate<MaterialLocalizations>>()
          .single
          .load(_es);
      final global = await GlobalMaterialLocalizations.delegate.load(_es);

      for (final date in dates) {
        expect(mine.formatYear(date), global.formatYear(date));
        expect(mine.formatCompactDate(date), global.formatCompactDate(date));
        expect(mine.formatShortDate(date), global.formatShortDate(date));
        expect(mine.formatMediumDate(date), global.formatMediumDate(date));
        expect(mine.formatFullDate(date), global.formatFullDate(date));
        expect(mine.formatMonthYear(date), global.formatMonthYear(date));
        expect(mine.formatShortMonthDay(date), global.formatShortMonthDay(date));
        final time = TimeOfDay.fromDateTime(date);
        expect(mine.formatTimeOfDay(time), global.formatTimeOfDay(time));
        expect(
          mine.formatTimeOfDay(time, alwaysUse24HourFormat: true),
          global.formatTimeOfDay(time, alwaysUse24HourFormat: true),
        );
        expect(mine.formatHour(time), global.formatHour(time));
        expect(mine.formatMinute(time), global.formatMinute(time));
      }
      for (final number in [0, 7, 1234, 9876543]) {
        expect(mine.formatDecimal(number), global.formatDecimal(number));
      }
      expect(mine.firstDayOfWeekIndex, global.firstDayOfWeekIndex);
      expect(mine.narrowWeekdays, global.narrowWeekdays);
      expect(mine.dateHelpText, global.dateHelpText);
      expect(mine.okButtonLabel, global.okButtonLabel);
      expect(mine.pageRowsInfoTitle(1, 10, 25, false), global.pageRowsInfoTitle(1, 10, 25, false));
      expect(mine.parseCompactDate('6/11/2026'), global.parseCompactDate('6/11/2026'));
    });

    test('OPT-F1: Cupertino dates and numbers equal GlobalCupertinoLocalizations in Spanish', () async {
      final mine = await OttosLocalization.delegates
          .whereType<LocalizationsDelegate<CupertinoLocalizations>>()
          .single
          .load(_es);
      final global = await GlobalCupertinoLocalizations.delegate.load(_es);

      for (final date in dates) {
        expect(mine.datePickerYear(date.year), global.datePickerYear(date.year));
        expect(mine.datePickerMonth(date.month), global.datePickerMonth(date.month));
        expect(mine.datePickerStandaloneMonth(date.month), global.datePickerStandaloneMonth(date.month));
        expect(mine.datePickerDayOfMonth(date.day, date.weekday), global.datePickerDayOfMonth(date.day, date.weekday));
        expect(mine.datePickerMediumDate(date), global.datePickerMediumDate(date));
        expect(mine.datePickerHour(date.hour), global.datePickerHour(date.hour));
        expect(mine.datePickerMinute(date.minute), global.datePickerMinute(date.minute));
        expect(mine.timerPickerHour(date.hour), global.timerPickerHour(date.hour));
        expect(mine.timerPickerMinute(date.minute), global.timerPickerMinute(date.minute));
        expect(mine.timerPickerSecond(date.second), global.timerPickerSecond(date.second));
      }
      expect(mine.datePickerDateOrder, global.datePickerDateOrder);
      expect(mine.datePickerDateTimeOrder, global.datePickerDateTimeOrder);
      expect(mine.todayLabel, global.todayLabel);
    });

    test('OPT-F1: Widgets localizations are Spanish and left to right', () async {
      final mine = await OttosLocalization.delegates
          .whereType<LocalizationsDelegate<WidgetsLocalizations>>()
          .single
          .load(_es);
      final global = await GlobalWidgetsLocalizations.delegate.load(_es);

      expect(mine.textDirection, TextDirection.ltr);
      expect(mine.textDirection, global.textDirection);
      expect(mine.reorderItemUp, global.reorderItemUp);
    });

    test('OPT-F1: only Spanish is supported, as before', () {
      for (final delegate in OttosLocalization.delegates) {
        expect(delegate.isSupported(_es), isTrue);
        expect(delegate.isSupported(const Locale('es', 'CU')), isTrue);
        expect(delegate.isSupported(const Locale('en')), isFalse);
      }
    });

    test('OPT-F1: money and dates of the app keep the Spanish format', () {
      expect(Formatters.money(1234567.5, 'CUP'), contains('1.234.567,50'));
      expect(Formatters.date(DateTime(2026, 11, 6)), '6 nov 2026');
    });
  });

  group('OPT-F2: new remittance started from a customer', () {
    late _MockCustomers customers;
    late _MockRates rates;

    setUp(() {
      customers = _MockCustomers();
      rates = _MockRates();
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const []);
    });

    test('OPT-F2 (customer fails): the form still opens, without the customer', () async {
      when(() => customers.get('c1')).thenThrow(const ApiException('Sin conexión'));
      when(() => rates.corridors()).thenAnswer((_) async => const []);
      final cubit = NewRemittanceCubit(remittances: _MockRemittances(), customers: customers, rates: rates);
      addTearDown(cubit.close);

      await cubit.load(customerId: 'c1');

      expect(cubit.state.corridorsStatus, LoadStatus.success);
      expect(cubit.state.customer, isNull);
    });
  });
}
