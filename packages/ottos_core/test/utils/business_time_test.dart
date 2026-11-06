import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_core/src/utils/boot_clock.dart';

/// A monotonic clock the test moves by hand.
class _Monotonic {
  Duration value = Duration.zero;

  Duration call() => value;
}

void main() {
  setUpAll(OttosLocalization.initialize);
  tearDown(BusinessTime.reset);

  group('zone', () {
    test('labels: «UTC−5», «UTC+5:30» and «UTC»', () {
      expect(BusinessTimeZone.parse('UTC-05:00')!.label, 'UTC−5');
      expect(BusinessTimeZone.parse('UTC+05:30')!.label, 'UTC+5:30');
      expect(BusinessTimeZone.parse('UTC+00:00')!.label, 'UTC');
      expect(BusinessTimeZone.ofMinutes(-570).label, 'UTC−9:30');
    });

    test('written as the API writes it', () {
      expect(BusinessTimeZone.ofMinutes(-240).timeZone, 'UTC-04:00');
      expect(BusinessTimeZone.ofMinutes(345).timeZone, 'UTC+05:45');
      expect(BusinessTimeZone.ofMinutes(0).timeZone, 'UTC+00:00');
    });

    test('reads businessTime; the label comes from offsetMinutes', () {
      expect(
        BusinessTimeZone.fromJson({'timeZone': 'UTC-05:00', 'offsetMinutes': -300}),
        BusinessTimeZone.ofMinutes(-300),
      );
      expect(BusinessTimeZone.fromJson(null), isNull);
      expect(BusinessTimeZone.parse('-04:00'), isNull);
    });

    test('the whole hours offered: UTC−12 … UTC+14', () {
      final labels = BusinessTimeZone.wholeHours.map((zone) => zone.label).toList();
      expect(labels.length, 27);
      expect(labels.first, 'UTC−12');
      expect(labels.last, 'UTC+14');
      expect(labels, contains('UTC'));
    });

    test('AC-2.5: without a zone from the server it is UTC−4', () {
      expect(BusinessTime.zone, BusinessTimeZone.fallback);
      expect(BusinessTime.label, 'UTC−4');
      BusinessTime.setZone(null);
      expect(BusinessTime.zone.offsetMinutes, -240);
    });

    test('notifies only when the zone really changes', () {
      var changes = 0;
      void count() => changes++;
      BusinessTime.changes.addListener(count);
      addTearDown(() => BusinessTime.changes.removeListener(count));

      BusinessTime.setZone(BusinessTimeZone.fallback);
      BusinessTime.setZone(BusinessTimeZone.ofMinutes(-300));
      BusinessTime.setZone(BusinessTimeZone.ofMinutes(-300));

      expect(changes, 1);
    });
  });

  group('formatting', () {
    // 18:32 UTC: 14:32 at UTC−4, whatever zone the device running the test has.
    final instant = DateTime.utc(2026, 11, 5, 18, 32);

    test('AC-2.1: instants in the business zone, not the device\'s', () {
      expect(Formatters.time(instant), '14:32');
      expect(Formatters.dateTime(instant), Formatters.dateTime(DateTime(2026, 11, 5, 14, 32)));
      BusinessTime.setForTest(zone: BusinessTimeZone.ofMinutes(-300));
      expect(Formatters.time(instant), '13:32');
      BusinessTime.setForTest(zone: BusinessTimeZone.ofMinutes(330));
      expect(Formatters.time(instant), '0:02');
      expect(Formatters.date(instant), Formatters.date(DateTime(2026, 11, 6)));
    });

    test('AC-2.2: 23:30 business time keeps its date on a device already in the next day', () {
      final lateEvening = DateTime.utc(2026, 11, 6, 3, 30);
      expect(Formatters.date(lateEvening), Formatters.date(DateTime(2026, 11, 5)));
      expect(BusinessTime.today(lateEvening), DateTime(2026, 11, 5));
      expect(BusinessTime.shortDate(lateEvening), BusinessTime.shortDate(DateTime.utc(2026, 11, 5, 12)));
    });

    test('a plain date (a due date, a picked day) is never shifted', () {
      BusinessTime.setForTest(zone: BusinessTimeZone.ofMinutes(-720));
      expect(Formatters.date(DateTime(2026, 11, 5)), Formatters.date(DateTime(2026, 11, 5, 23)));
      expect(Formatters.date(DateTime.parse('2026-11-05')), Formatters.date(DateTime(2026, 11, 5)));
    });

    test('AC-1.1: «14:32 del 5 nov 2026», also with another zone for the preview', () {
      expect(BusinessTime.clockText(instant), '14:32 del 5 nov 2026');
      expect(BusinessTime.clockText(instant, BusinessTimeZone.ofMinutes(-300)), '13:32 del 5 nov 2026');
    });
  });

  group('server clock', () {
    late _Monotonic monotonic;
    late DateTime device;

    setUp(() {
      monotonic = _Monotonic();
      device = DateTime.utc(2026, 11, 5, 10);
      BusinessTime.setForTest(deviceClock: () => device, elapsed: monotonic.call);
    });

    test('AC-3.2: with no server time ever, it is the device clock', () {
      expect(BusinessTime.now(), device);
      expect(BusinessTime.clockOffset, isNull);
    });

    test('AC-3.1: after an answer, the server time plus the time passed since', () {
      // The phone is 3 minutes behind.
      BusinessTime.serverTimeReceived(DateTime.utc(2026, 11, 5, 10, 3));
      monotonic.value = const Duration(seconds: 40);
      device = device.add(const Duration(seconds: 40));

      expect(BusinessTime.now(), DateTime.utc(2026, 11, 5, 10, 3, 40));
      expect(BusinessTime.clockOffset, const Duration(minutes: 3));
    });

    test('AC-3.5: a clock change after a sync does not move it', () {
      BusinessTime.serverTimeReceived(DateTime.utc(2026, 11, 5, 10));
      monotonic.value = const Duration(minutes: 5);
      // The courier sets the phone a day and two hours ahead.
      device = DateTime.utc(2026, 11, 6, 12, 5);

      expect(BusinessTime.now(), DateTime.utc(2026, 11, 5, 10, 5));
    });

    test('AC-3.2: after a restart without network, the device clock plus the saved difference', () {
      BusinessTime.restore(
        clockOffset: const Duration(minutes: -7),
        sampledAt: device.subtract(const Duration(hours: 2)),
        zone: BusinessTimeZone.ofMinutes(-300),
      );

      expect(BusinessTime.now(), DateTime.utc(2026, 11, 5, 9, 53));
      expect(BusinessTime.zone, BusinessTimeZone.ofMinutes(-300));
    });

    test('AC-3.2: a saved difference is dropped if the clock went back or it is over a day old', () {
      BusinessTime.restore(clockOffset: const Duration(minutes: -7), sampledAt: device.add(const Duration(hours: 1)));
      expect(BusinessTime.now(), device, reason: 'the device clock went back since it was measured');

      BusinessTime.restore(
        clockOffset: const Duration(minutes: -7),
        sampledAt: device.subtract(const Duration(days: 2)),
      );
      expect(BusinessTime.now(), device, reason: 'too old to trust');
    });

    test('an answer of this run wins over the saved difference', () {
      BusinessTime.serverTimeReceived(DateTime.utc(2026, 11, 5, 10, 1));
      BusinessTime.restore(clockOffset: const Duration(minutes: -7), sampledAt: device);

      expect(BusinessTime.now(), DateTime.utc(2026, 11, 5, 10, 1));
    });

    test('wallClock and today follow the corrected clock', () {
      BusinessTime.serverTimeReceived(DateTime.utc(2026, 11, 6, 3, 30));

      expect(BusinessTime.wallClock(), DateTime(2026, 11, 5, 23, 30));
      expect(BusinessTime.today(), DateTime(2026, 11, 5));
      expect(DateUtils.isSameDay(BusinessTime.today(), DateTime(2026, 11, 5)), isTrue);
    });
  });

  test('CR-1: the clock that counts sleep is available on this platform and moves forward', () async {
    final clock = bootClock();
    expect(clock, isNotNull);
    final first = clock!();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(clock() - first, greaterThanOrEqualTo(const Duration(milliseconds: 15)));
  });
}
