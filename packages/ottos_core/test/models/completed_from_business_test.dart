import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('reads whether the business completed it, false when the backend does not say', () {
    final byBusiness = Remittance.fromJson(const {'id': 'r1', 'status': 'DELIVERED', 'completedFromBusiness': true});
    final older = Remittance.fromJson(const {'id': 'r2', 'status': 'DELIVERED'});

    expect(byBusiness.completedFromBusiness, isTrue);
    expect(older.completedFromBusiness, isFalse);
    expect(byBusiness == Remittance.fromJson(const {'id': 'r1', 'status': 'DELIVERED'}), isFalse);
  });
}
