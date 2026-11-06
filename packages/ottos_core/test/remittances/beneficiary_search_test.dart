import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('a name is searchable from 2 letters, accents and ñ included', () {
    expect(isBeneficiarySearchable('jo'), isTrue);
    expect(isBeneficiarySearchable(' Ñu '), isTrue);
    expect(isBeneficiarySearchable('é'), isFalse);
  });

  test('a phone is searchable from 4 digits', () {
    expect(isBeneficiarySearchable('1234'), isTrue);
    expect(isBeneficiarySearchable('123'), isFalse);
  });

  test('empty or symbols only is not searchable', () {
    expect(isBeneficiarySearchable(''), isFalse);
    expect(isBeneficiarySearchable('  '), isFalse);
    expect(isBeneficiarySearchable('%_-'), isFalse);
  });
}
