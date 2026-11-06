import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

Remittance _due(DateTime? date) => Remittance(
  id: 'r',
  code: 'OT-1',
  type: RemittanceType.delivery,
  status: 'ASSIGNED',
  statusName: 'Asignada',
  expectedDate: date,
);

void main() {
  // 23:59 of 10 October at UTC−4, the business's; already the 11th in UTC.
  final now = DateTime.utc(2026, 10, 11, 3, 59);

  tearDown(BusinessTime.reset);

  test('counts whole calendar days past the expected date', () {
    expect(_due(DateTime(2026, 10, 9, 23, 59)).daysLate(now: now), 1);
    expect(_due(DateTime(2026, 10, 7)).daysLate(now: now), 3);
  });

  test('is 0 when due today, later or without a date', () {
    expect(_due(DateTime(2026, 10, 10)).daysLate(now: now), 0);
    expect(_due(DateTime(2026, 10, 12)).daysLate(now: now), 0);
    expect(_due(null).daysLate(now: now), 0);
  });

  test('AC-2.6: «today» is the business date, not the device\'s', () {
    // Business at UTC−4 it is still the 10th; at UTC+2 it is already the 11th.
    BusinessTime.setForTest(zone: BusinessTimeZone.ofMinutes(-240));
    expect(_due(DateTime(2026, 10, 9)).daysLate(now: now), 1);
    BusinessTime.setForTest(zone: BusinessTimeZone.ofMinutes(120));
    expect(_due(DateTime(2026, 10, 9)).daysLate(now: now), 2);
  });
}
