import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  setUpAll(OttosLocalization.initialize);
  tearDown(BusinessTime.reset);

  testWidgets('AC-2.3: the times on screen follow a new zone without a reload', (tester) async {
    final instant = DateTime.utc(2026, 11, 5, 18, 32);
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessTimeScope(child: Builder(builder: (_) => Text(Formatters.time(instant)))),
      ),
    );
    expect(find.text('14:32'), findsOneWidget);

    BusinessTime.setZone(BusinessTimeZone.ofMinutes(-300));
    await tester.pump();

    expect(find.text('13:32'), findsOneWidget);
  });
}
