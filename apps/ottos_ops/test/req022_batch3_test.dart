import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/cash/view/movement_tile.dart';

/// REQ-022 batch 3 (OPT-F7): the panel's movements use the colour tokens.
void main() {
  setUpAll(OttosLocalization.initialize);

  Future<void> pump(WidgetTester tester, double signedAmount) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MovementTile(
          movement: CashMovement(
            id: 'm1',
            type: CashMovementType.courierFunding,
            amount: signedAmount.abs(),
            signedAmount: signedAmount,
            currency: 'USD',
          ),
        ),
      ),
    ),
  );

  testWidgets('OPT-F7: money in is painted with the success token', (tester) async {
    await pump(tester, 50);

    expect(tester.widget<Icon>(find.byIcon(Icons.south_west)).color, OttosColors.success);
  });

  testWidgets('OPT-F7: money out keeps the error colour', (tester) async {
    await pump(tester, -50);

    final context = tester.element(find.byType(MovementTile));
    expect(tester.widget<Icon>(find.byIcon(Icons.north_east)).color, Theme.of(context).colorScheme.error);
  });
}
