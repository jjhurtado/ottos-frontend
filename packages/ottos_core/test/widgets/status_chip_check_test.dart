import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

Remittance _remittance(Map<String, dynamic> extra) =>
    Remittance.fromJson({'id': 'r1', 'code': 'OT-1', 'type': 'DELIVERY', 'status': 'PAID', ...extra});

Future<void> _pump(WidgetTester tester, Remittance remittance, {bool showCheck = false}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: RemittanceStatusChip(remittance: remittance, showCheck: showCheck),
    ),
  ),
);

void main() {
  final completed = _remittance({
    'status': 'DELIVERED',
    'statusName': 'Entregada',
    'completedAt': '2026-11-05T18:00:00Z',
  });

  testWidgets('REQ-020 BR-1: a completed remittance gets a check mark, not only a colour', (tester) async {
    await _pump(tester, completed, showCheck: true);

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Entregada'), findsOneWidget);
  });

  testWidgets('REQ-020: the panel keeps the chip as it was', (tester) async {
    await _pump(tester, completed);

    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('REQ-020: open and voided remittances get no check mark', (tester) async {
    await _pump(tester, _remittance({'statusName': 'Pagada'}), showCheck: true);
    expect(find.byIcon(Icons.check), findsNothing);

    await _pump(
      tester,
      _remittance({
        'status': 'DELIVERED',
        'completedAt': '2026-11-05T18:00:00Z',
        'voided': {'at': '2026-11-05T19:00:00Z', 'byName': 'Admin', 'reason': 'Error'},
      }),
      showCheck: true,
    );
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
