import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('an edited beneficiary differs even when only the house number changed', () {
    const before = Beneficiary(id: 'b1', fullName: 'Rosa', phone: '5352220001', street: 'Calle 3');
    const after = Beneficiary(id: 'b1', fullName: 'Rosa', phone: '5352220001', street: 'Calle 3', houseNumber: '7');
    expect(after, isNot(before));
  });

  test('an edited customer differs even when only the address changed', () {
    const before = Customer(id: 'c1', fullName: 'Ana', phone: '5551234');
    const after = Customer(id: 'c1', fullName: 'Ana', phone: '5551234', address: 'Miami');
    expect(after, isNot(before));
  });
}
