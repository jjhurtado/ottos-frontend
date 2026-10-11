import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

Remittance _remittance(RemittanceType type, String status) =>
    Remittance(id: 'r', code: 'OT-1', type: type, status: status, statusName: 'Delivered');

void main() {
  test('the final status says what was done, by type', () {
    expect(_remittance(RemittanceType.delivery, 'DELIVERED').displayStatus, 'Entregada');
    expect(_remittance(RemittanceType.pickup, 'DELIVERED').displayStatus, 'Recogida');
    expect(CoreTexts.statusName('DELIVERED'), 'Entregada o recogida');
  });

  test('the other statuses are the same for both types', () {
    for (final type in RemittanceType.values) {
      expect(_remittance(type, 'PAID').displayStatus, 'Pagada');
      expect(_remittance(type, 'ASSIGNED').displayStatus, 'Asignada');
    }
  });

  test('an unknown status shows the backend name, or its code', () {
    expect(CoreTexts.statusName('ON_HOLD', fallback: 'En espera'), 'En espera');
    expect(CoreTexts.statusName('ON_HOLD'), 'ON_HOLD');
  });
}
