import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('reads the delivery and the pickup rate and fee rule apart', () {
    final corridor = Corridor.fromJson({
      'code': 'USD-CUP',
      'sourceCurrency': 'USD',
      'targetCurrency': 'CUP',
      'active': true,
      'currentRate': {'id': 'r1', 'rate': 760, 'remittanceType': 'DELIVERY'},
      'currentFeeRule': {'id': 'f1', 'type': 'PERCENTAGE', 'value': 10, 'remittanceType': 'DELIVERY'},
      'currentPickupRate': {'id': 'r2', 'rate': 1, 'remittanceType': 'PICKUP'},
      'currentPickupFeeRule': {'id': 'f2', 'type': 'FIXED', 'value': 3, 'remittanceType': 'PICKUP'},
    });

    expect(corridor.rateFor(RemittanceType.delivery)?.rate, 760);
    expect(corridor.rateFor(RemittanceType.pickup)?.rate, 1);
    expect(corridor.feeRuleFor(RemittanceType.pickup)?.type, FeeType.fixed);
    expect(corridor.pickupRate?.remittanceType, RemittanceType.pickup);
  });

  test('a corridor without a pickup rate cannot quote pickups', () {
    const corridor = Corridor(
      code: 'USD-CUP',
      sourceCurrency: 'USD',
      targetCurrency: 'CUP',
      rate: ExchangeRate(id: 'r1', rate: 760),
    );

    expect(corridor.canQuoteFor(RemittanceType.delivery), isTrue);
    expect(corridor.canQuoteFor(RemittanceType.pickup), isFalse);
  });
}
