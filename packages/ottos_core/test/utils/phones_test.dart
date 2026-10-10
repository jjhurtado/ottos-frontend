import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('a local Cuban number gets the country code', () {
    expect(Phones.international('53445678'), '5353445678');
    expect(Phones.whatsApp('5344 5678').toString(), 'https://wa.me/5353445678');
  });

  test('a number with country code is kept as is', () {
    expect(Phones.international('5352345432'), '5352345432');
    expect(Phones.international('+1 305 555 1841'), '13055551841');
  });
}
