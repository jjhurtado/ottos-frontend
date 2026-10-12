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
  final now = DateTime(2026, 10, 10, 23, 59);

  test('counts whole calendar days past the expected date', () {
    expect(_due(DateTime(2026, 10, 9, 23, 59)).daysLate(now: now), 1);
    expect(_due(DateTime(2026, 10, 7)).daysLate(now: now), 3);
  });

  test('is 0 when due today, later or without a date', () {
    expect(_due(DateTime(2026, 10, 10)).daysLate(now: now), 0);
    expect(_due(DateTime(2026, 10, 12)).daysLate(now: now), 0);
    expect(_due(null).daysLate(now: now), 0);
  });
}
