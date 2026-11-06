import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

import 'fixtures.dart';

class _MockReports extends Mock implements ReportRepository {}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// The fixture's only «Asignada» row has an incident (red); this copy lifts it
/// so the amber chip is shown.
Map<String, dynamic> _withAssignedWithoutIncident() {
  final rows = [
    for (final row in detailJson['remittances'] as List<dynamic>)
      {...(row as Map<String, dynamic>), if (row['code'] == 'OT-R9T4BW') 'withIncident': false},
  ];
  return {...detailJson, 'remittances': rows};
}

/// REQ-007 (tester): the chips of the month's remittances report, which the
/// developer's tests do not reach.
void main() {
  setUpAll(() async {
    registerFallbackValue(DateTime(2000));
    await OttosLocalization.initialize();
  });

  testWidgets('REQ-007: report chips use the dark text shade and read at 4.5:1 on their tint', (tester) async {
    final reports = _MockReports();
    when(() => reports.monthlyRemittances(any(), any()))
        .thenAnswer((_) async => MonthlyReportDetail.fromJson(_withAssignedWithoutIncident()));
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: OttosLocalization.delegates,
        supportedLocales: OttosLocalization.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider(
              create: (_) => ReportRemittancesCubit(reports: reports, month: DateTime(2026, 10))..load(),
              child: const ReportRemittancesSection(compact: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Expected text colour per tint base, from the design tokens.
    final expectedText = <Color, Color>{
      OttosColors.success: OttosColors.successText,
      OttosColors.warning: OttosColors.warningText,
      OttosColors.tealDark: OttosColors.tealDark,
      OttosColors.danger: OttosColors.danger,
    };
    final seen = <Color>{};
    for (final container in tester.widgetList<Container>(find.byType(Container))) {
      final decoration = container.decoration;
      if (decoration is! BoxDecoration || decoration.color == null) continue;
      for (final MapEntry(key: base, value: textColor) in expectedText.entries) {
        if (decoration.color != base.withValues(alpha: 0.12)) continue;
        final text = find.descendant(of: find.byWidget(container), matching: find.byType(Text));
        if (text.evaluate().isEmpty) continue;
        final style = tester.widget<Text>(text.first).style!;
        expect(style.color, textColor, reason: 'chip on tint of $base');
        final tint = Color.alphaBlend(decoration.color!, Colors.white);
        expect(_contrast(style.color!, tint), greaterThanOrEqualTo(4.5), reason: 'chip on tint of $base');
        seen.add(base);
      }
    }
    expect(seen, containsAll([OttosColors.success, OttosColors.warning]));
  });
}
