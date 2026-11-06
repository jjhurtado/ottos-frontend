import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

/// REQ-004 · client against docs/api/openapi.yaml (ottos repo).
void main() {
  // MovementView.type in openapi.yaml, copied by hand from the contract.
  const contractMovementTypes = [
    'REMITTANCE_PAYMENT',
    'REMITTANCE_VOID_REVERSAL',
    'COURIER_FUNDING',
    'DELIVERY_PAYOUT',
    'PICKUP_COLLECTION',
    'COURIER_RETURN',
    'BUSINESS_DEPOSIT',
    'BUSINESS_WITHDRAWAL',
    'COURIER_EXCHANGE_OUT',
    'COURIER_EXCHANGE_IN',
  ];

  test('DFT-10: CashMovementType has exactly the movement types of the contract', () {
    final codes = CashMovementType.values.where((t) => t != CashMovementType.unknown).map((t) => t.code).toList();
    expect(codes, unorderedEquals(contractMovementTypes));
  });

  test('DFT-10: every contract movement type reads to its own value, never to unknown', () {
    for (final code in contractMovementTypes) {
      expect(CashMovementType.fromCode(code).code, code);
    }
  });

  test('DFT-10: the removed types read as unknown, nothing breaks', () {
    expect(CashMovementType.fromCode('COURIER_SURPLUS'), CashMovementType.unknown);
    expect(CashMovementType.fromCode('REMITTANCE_REFUND'), CashMovementType.unknown);
  });

  test('DFT-8: a 426 body with all its contract members reads, notes stay null', () {
    final body = AppVersion.fromJson(const {
      'status': 426,
      'code': 'APP_UPDATE_REQUIRED',
      'minimumBuild': 7,
      'latestBuild': 9,
      'latestVersion': '1.0.2',
      'downloadUrl': 'https://example.test/app.apk',
    });
    expect(body.minimumBuild, 7);
    expect(body.latestBuild, 9);
    expect(body.latestVersion, '1.0.2');
    expect(body.downloadUrl, 'https://example.test/app.apk');
    expect(body.notes, isNull);
  });
}
