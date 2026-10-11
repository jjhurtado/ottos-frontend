import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/customers/customer_csv.dart';

final _export = [
  {
    'fullName': 'Ana Pérez',
    'phone': '+13055550101',
    'address': 'Miami; FL',
    'active': true,
    'beneficiaries': [
      {
        'fullName': 'Rosa Martínez',
        'phone': '5352223344',
        'street': 'Calle 10',
        'houseNumber': '1',
        'municipalityCode': '2302',
        'municipalityName': 'Plaza de la Revolución',
        'notes': 'Llamar "antes"',
        'active': true,
      },
      {
        'fullName': 'Luis Pérez',
        'phone': '5351112233',
        'street': 'Calle 5',
        'municipalityCode': '2310',
        'municipalityName': 'Boyeros',
        'active': false,
      },
    ],
  },
  {'fullName': 'Sin Beneficiarios', 'phone': '+13055550102', 'active': true, 'beneficiaries': []},
];

void main() {
  test('exporting and importing gives back the same customers and beneficiaries', () {
    final text = CustomerCsv.export(_export);

    final customers = CustomerCsv.parse(text);

    expect(customers, hasLength(2));
    final ana = customers.first;
    expect(ana.ref, 'fila 2');
    expect(ana.address, 'Miami; FL');
    expect(ana.beneficiaries.map((b) => b.fullName), ['Rosa Martínez', 'Luis Pérez']);
    expect(ana.beneficiaries.first.municipality, 'Plaza de la Revolución');
    expect(ana.beneficiaries.first.notes, 'Llamar "antes"');
    expect(ana.beneficiaries.last.ref, 'fila 3');
    expect(customers.last.beneficiaries, isEmpty);
  });

  test('rows of the same customer group even if apart or written differently', () {
    const text =
        'cliente_nombre,cliente_telefono,cliente_direccion,beneficiario_nombre,beneficiario_telefono,'
        'beneficiario_calle,beneficiario_municipio\n'
        'Ana Pérez,+1305,Miami,Rosa,535,Calle 1,Boyeros\n'
        'Otro,+1306,,,,,\n'
        'ana  pérez,+1305,miami,Luis,536,Calle 2,Plaza\n';

    final customers = CustomerCsv.parse(text);

    expect(customers.map((c) => c.fullName), ['Ana Pérez', 'Otro']);
    expect(customers.first.beneficiaries.map((b) => b.ref), ['fila 2', 'fila 4']);
  });

  test('a file without the customer columns says what is missing', () {
    expect(
      () => CustomerCsv.parse('nombre;telefono\nAna;123'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('cliente_nombre'))),
    );
  });
}
