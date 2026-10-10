import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  /// Opens the dialog and returns a getter for what it closed with.
  Future<IncidentInput? Function()> open(WidgetTester tester) async {
    IncidentInput? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showIncidentDialog(context, isPickup: false);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(closed, isTrue);
      return result;
    };
  }

  FilledButton reportButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, CoreTexts.report));

  testWidgets('a reason must be chosen before reporting', (tester) async {
    final result = await open(tester);

    expect(find.text(CoreTexts.reportIncident), findsOneWidget);
    expect(reportButton(tester).onPressed, isNull);

    await tester.tap(find.text(CoreTexts.incidentReason(IncidentReason.unreachable)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CoreTexts.report));
    await tester.pumpAndSettle();

    expect(result(), (reason: IncidentReason.unreachable, note: null));
  });

  testWidgets('another reason needs a note, and the error goes when the reason changes', (tester) async {
    final result = await open(tester);

    await tester.tap(find.text(CoreTexts.incidentReason(IncidentReason.other)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CoreTexts.report));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.incidentNoteRequired), findsOneWidget);

    await tester.tap(find.text(CoreTexts.incidentReason(IncidentReason.notHome)));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.incidentNoteRequired), findsNothing);

    await tester.enterText(find.byType(TextFormField), '  Nadie abrió  ');
    await tester.tap(find.text(CoreTexts.report));
    await tester.pumpAndSettle();

    expect(result(), (reason: IncidentReason.notHome, note: 'Nadie abrió'));
  });
}
