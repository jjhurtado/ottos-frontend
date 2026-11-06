import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('REQ-018: the beneficiary text goes in the query as `beneficiary`', () {
    const filter = RemittanceFilter(beneficiaryQuery: 'jose');

    expect(filter.toQuery()['beneficiary'], 'jose');
    expect(filter.isEmpty, isFalse);
    expect(const RemittanceFilter().toQuery()['beneficiary'], isNull);
  });

  test('REQ-018: copyWith keeps the text, changes it and clears it', () {
    const filter = RemittanceFilter(beneficiaryQuery: 'jose', status: 'CREATED');

    expect(filter.copyWith(status: null).beneficiaryQuery, 'jose');
    expect(filter.copyWith(beneficiaryQuery: 'ana').beneficiaryQuery, 'ana');
    expect(filter.copyWith(beneficiaryQuery: null).beneficiaryQuery, isNull);
    expect(filter, isNot(const RemittanceFilter(status: 'CREATED')));
  });
}
