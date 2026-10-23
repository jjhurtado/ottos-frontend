import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  group('remittance', () {
    test('reads on the house with its waived fee and reason', () {
      final remittance = Remittance.fromJson(const {
        'id': 'r1',
        'type': 'DELIVERY',
        'fee': 0,
        'total': 37,
        'onTheHouse': true,
        'waivedFee': 10.00,
        'onTheHouseReason': 'Su madre',
      });

      expect(remittance.onTheHouse, isTrue);
      expect(remittance.waivedFee, 10);
      expect(remittance.onTheHouseReason, 'Su madre');
    });

    test('a courier gets the mark but not the money', () {
      final remittance = Remittance.fromJson(const {
        'id': 'r1',
        'type': 'DELIVERY',
        'onTheHouse': true,
        'waivedFee': null,
        'onTheHouseReason': null,
      });

      expect(remittance.onTheHouse, isTrue);
      expect(remittance.waivedFee, isNull);
      expect(remittance.onTheHouseReason, isNull);
    });

    test('a backend without the field reads as a normal remittance', () {
      final remittance = Remittance.fromJson(const {'id': 'r1', 'type': 'DELIVERY'});

      expect(remittance.onTheHouse, isFalse);
      expect(remittance.waivedFee, isNull);
    });
  });

  test('a quote on the house says so and tells the fee left uncharged', () {
    final quote = Quote.fromJson(const {
      'sourceCurrency': 'USD',
      'targetCurrency': 'CUP',
      'amount': 37,
      'fee': 0,
      'total': 37,
      'rate': 410,
      'amountToDeliver': 15150,
      'onTheHouse': true,
      'waivedFee': 10,
    });
    expect(quote.onTheHouse, isTrue);
    expect(quote.waivedFee, 10);

    final normal = Quote.fromJson(const {'amount': 37, 'fee': 10, 'total': 47});
    expect(normal.onTheHouse, isFalse);
    expect(normal.waivedFee, isNull);
  });

  group('new remittance', () {
    const base = NewRemittance(
      type: RemittanceType.delivery,
      customerId: 'c1',
      beneficiaryId: 'b1',
      amount: 37,
      targetCurrency: 'CUP',
    );

    test('a normal one sends neither field, as before', () {
      final json = base.toJson();

      expect(json.containsKey('onTheHouse'), isFalse);
      expect(json.containsKey('onTheHouseReason'), isFalse);
    });

    test('on the house sends the mark and the trimmed reason', () {
      const remittance = NewRemittance(
        type: RemittanceType.delivery,
        customerId: 'c1',
        beneficiaryId: 'b1',
        amount: 37,
        targetCurrency: 'CUP',
        onTheHouse: true,
        onTheHouseReason: '  Su madre ',
      );

      expect(remittance.toJson(), containsPair('onTheHouse', true));
      expect(remittance.toJson(), containsPair('onTheHouseReason', 'Su madre'));
      expect(remittance.toJson().containsKey('fee'), isFalse);
    });
  });

  test('the list filters by on the house only when asked', () {
    expect(const RemittanceFilter().toQuery()['onTheHouse'], isNull);
    final filter = const RemittanceFilter().copyWith(onTheHouse: true);
    expect(filter.toQuery()['onTheHouse'], isTrue);
    expect(filter.isEmpty, isFalse);
    expect(filter.copyWith(onTheHouse: null).isEmpty, isTrue);
  });

  test('every error of on the house reads in Spanish', () {
    for (final code in ['ON_THE_HOUSE_NOT_ALLOWED', 'ON_THE_HOUSE_DELIVERY_ONLY', 'ON_THE_HOUSE_REASON_REQUIRED']) {
      expect(CoreTexts.errorCodes[code], isNotNull, reason: code);
    }
  });

  group('monthly report', () {
    test('reads the on the house block', () {
      final report = MonthlyReport.fromJson(const {
        'month': '2026-10',
        'onTheHouse': {'remittances': 2, 'amount': 237.00, 'waivedFees': 30.00},
      });

      expect(report.onTheHouse, const ReportOnTheHouse(remittances: 2, amount: 237, waivedFees: 30));
    });

    test('a backend without the block has none', () {
      expect(MonthlyReport.fromJson(const {'month': '2026-10'}).onTheHouse, isNull);
    });
  });
}
