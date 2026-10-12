import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('round-trips accents, separators, quotes and line breaks', () {
    final rows = [
      ['nombre', 'dirección', 'notas'],
      ['Rosa Martínez', 'Calle 10; #1', 'Dijo "llamar antes"\nsegunda línea'],
      ['Ana', '', null],
    ];

    final text = Csv.encode(rows);

    expect(text.startsWith(Csv.bom), isTrue, reason: 'Excel needs it to read UTF-8');
    expect(Csv.decode(text), [
      ['nombre', 'dirección', 'notas'],
      ['Rosa Martínez', 'Calle 10; #1', 'Dijo "llamar antes"\nsegunda línea'],
      ['Ana', '', ''],
    ]);
  });

  test('keeps blank lines in between, so rows keep their numbers', () {
    expect(Csv.decode('a;b\n1;2\n\n3;4\n'), [
      ['a', 'b'],
      ['1', '2'],
      [''],
      ['3', '4'],
    ]);
  });

  test('reads files saved with commas or tabs, and skips blank lines at the end', () {
    expect(Csv.decode('a,b\r\n1,"2,5"\r\n\r\n,\r\n'), [
      ['a', 'b'],
      ['1', '2,5'],
    ]);
    expect(Csv.decode('a\tb\n1\t2'), [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('an import result adds batches and lists what was rejected', () {
    ImportResult batch(String ref, String status) => ImportResult.fromJson({
      'dryRun': true,
      'summary': {'customersCreated': status == 'CREATED' ? 1 : 0, 'customersRejected': status == 'REJECTED' ? 1 : 0},
      'results': [
        {
          'index': 0,
          'ref': ref,
          'status': status,
          'code': status == 'REJECTED' ? 'INVALID_PHONE' : null,
          'beneficiaries': [
            {'index': 0, 'ref': ref, 'status': 'REJECTED', 'code': 'UNKNOWN_MUNICIPALITY'},
          ],
        },
      ],
    });

    final result = batch('fila 2', 'CREATED') + batch('fila 3', 'REJECTED');

    expect(result.customersCreated, 1);
    expect(result.customersRejected, 1);
    expect(result.rejected.map((item) => '${item.ref} ${item.code}'), [
      'fila 2 UNKNOWN_MUNICIPALITY',
      'fila 3 INVALID_PHONE',
      'fila 3 UNKNOWN_MUNICIPALITY',
    ]);
  });
}
