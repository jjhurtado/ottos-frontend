import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('a voided remittance says who, when and why', () {
    final remittance = Remittance.fromJson(const {
      'id': 'r1',
      'code': 'OT-1',
      'type': 'DELIVERY',
      'status': 'DELIVERED',
      'voided': {'at': '2026-10-13T15:00:00Z', 'by': 'u1', 'byName': 'Administrator', 'reason': 'Duplicada'},
    });

    expect(remittance.isVoided, isTrue);
    expect(remittance.voided!.byName, 'Administrator');
    expect(remittance.voided!.reason, 'Duplicada');
    expect(remittance.voided!.at, DateTime.utc(2026, 10, 13, 15));
  });

  test('a standing remittance is not voided', () {
    final remittance = Remittance.fromJson(const {'id': 'r1', 'type': 'DELIVERY', 'status': 'PAID', 'voided': null});
    expect(remittance.isVoided, isFalse);
  });

  test('the filter asks for voided ones only when set', () {
    expect(const RemittanceFilter().toQuery()['voided'], isNull);
    expect(const RemittanceFilter(voided: false).toQuery()['voided'], false);
    expect(const RemittanceFilter().copyWith(voided: true).voided, isTrue);
    expect(CoreTexts.voidedBy(null), 'Remesa anulada');
  });
}
