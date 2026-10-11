import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  final now = DateTime(2026, 10, 10, 15, 30);

  test('postpones to the day after the expected date when that is in the future', () {
    expect(earliestPostponeDate(DateTime(2026, 10, 11), now: now), DateTime(2026, 10, 12));
    expect(earliestPostponeDate(DateTime(2026, 10, 20), now: now), DateTime(2026, 10, 21));
  });

  test('postpones to tomorrow when the expected date has passed or is today', () {
    expect(earliestPostponeDate(DateTime(2026, 10, 10), now: now), DateTime(2026, 10, 11));
    expect(earliestPostponeDate(DateTime(2026, 10, 2), now: now), DateTime(2026, 10, 11));
    expect(earliestPostponeDate(null, now: now), DateTime(2026, 10, 11));
  });

  testWidgets('the delivery PIN must have its 6 digits, or none', (tester) async {
    CompleteInput? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showCompleteDialog(context, isPickup: false);
              closed = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, CoreTexts.pin), '0000');
    await tester.tap(find.text(CoreTexts.confirm));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.pinLength(6)), findsOneWidget);
    expect(closed, isFalse);

    await tester.enterText(find.widgetWithText(TextField, CoreTexts.pin), '12345678');
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.pinLength(6)), findsNothing, reason: 'typing clears the error');
    await tester.tap(find.text(CoreTexts.confirm));
    await tester.pumpAndSettle();
    expect(result?.pin, '123456', reason: 'at most 6 digits are taken');
  });
}
