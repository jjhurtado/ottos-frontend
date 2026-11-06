import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('RemittanceTitle (REQ-019)', () {
    testWidgets('the beneficiary as the title, the code small under it', (tester) async {
      await tester.pumpWidget(_wrap(const RemittanceTitle(name: 'Rosa Pérez', code: 'OT-ABC123')));

      final name = tester.widget<Text>(find.text('Rosa Pérez'));
      final code = tester.widget<Text>(find.text('OT-ABC123'));
      expect(tester.getTopLeft(find.text('OT-ABC123')).dy, greaterThan(tester.getTopLeft(find.text('Rosa Pérez')).dy));
      expect(code.style!.fontSize!, lessThan(name.style!.fontSize!), reason: 'BR-2: the code smaller');
    });

    testWidgets('REQ-019 CR-2: a screen reader gets name and code as one item', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const RemittanceTitle(name: 'Rosa Pérez', code: 'OT-ABC123')));

      expect(find.bySemanticsLabel('Rosa Pérez · OT-ABC123'), findsOneWidget);
      expect(find.bySemanticsLabel('OT-ABC123'), findsNothing);
      handle.dispose();
    });

    testWidgets('with no name, the code takes the title', (tester) async {
      for (final name in [null, '', '  ']) {
        await tester.pumpWidget(_wrap(RemittanceTitle(name: name, code: 'OT-ABC123')));
        expect(find.byType(Text), findsOneWidget);
        expect(find.text('OT-ABC123'), findsOneWidget);
      }
    });
  });

  test('REQ-019 CR-4: cleanName trims and gives null for no name', () {
    expect(Formatters.cleanName(' Rosa '), 'Rosa');
    for (final none in [null, '', '   ']) {
      expect(Formatters.cleanName(none), isNull);
    }
  });

  test('remittanceLabel: name first, code last, or the code alone', () {
    expect(remittanceLabel('Rosa Pérez', 'OT-1'), 'Rosa Pérez · OT-1');
    expect(remittanceLabel(' Rosa ', 'OT-1'), 'Rosa · OT-1');
    expect(remittanceLabel(null, 'OT-1'), 'OT-1');
    expect(remittanceLabel('', 'OT-1'), 'OT-1');
  });
}
