import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// The tint as it shows on a white card.
Color _tint(Color base, [double alpha = 0.12]) => Color.alphaBlend(base.withValues(alpha: alpha), Colors.white);

Remittance _remittance(Map<String, dynamic> extra) =>
    Remittance.fromJson({'id': 'r1', 'code': 'OT-1', 'type': 'DELIVERY', 'status': 'PAID', ...extra});

Future<(Color text, Color background)> _pumpChip(
  WidgetTester tester,
  Remittance remittance, {
  bool onDark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RemittanceStatusChip(remittance: remittance, onDark: onDark),
      ),
    ),
  );
  final text = tester.widget<Text>(find.byType(Text));
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(RemittanceStatusChip), matching: find.byType(Container)),
  );
  return (text.style!.color!, (container.decoration! as BoxDecoration).color!);
}

void main() {
  group('REQ-007: status chip text colours', () {
    test('REQ-007: the darker text shades read at 4.5:1 or more on their 12% tint and on white', () {
      final pairs = {
        OttosColors.tealDark: OttosColors.teal,
        OttosColors.warningText: OttosColors.warning,
        OttosColors.successText: OttosColors.success,
      };
      for (final MapEntry(key: text, value: base) in pairs.entries) {
        expect(_contrast(text, _tint(base)), greaterThanOrEqualTo(4.5), reason: '$text on tint of $base');
        expect(_contrast(text, Colors.white), greaterThanOrEqualTo(4.5), reason: '$text on white');
      }
      expect(OttosColors.warningText, const Color(0xFF926119));
      expect(OttosColors.successText, const Color(0xFF297047));
    });

    testWidgets('REQ-007: «Pagada» uses dark teal text on the teal tint', (tester) async {
      final (text, background) = await _pumpChip(tester, _remittance({}));
      expect(text, OttosColors.tealDark);
      expect(background, OttosColors.teal.withValues(alpha: 0.12));
      expect(_contrast(text, _tint(OttosColors.teal)), greaterThanOrEqualTo(4.5));
    });

    testWidgets('REQ-007: «Asignada» uses the darker amber text on the amber tint', (tester) async {
      final (text, background) = await _pumpChip(tester, _remittance({'status': 'ASSIGNED', 'courierId': 'c1'}));
      expect(text, OttosColors.warningText);
      expect(background, OttosColors.warning.withValues(alpha: 0.12));
      expect(_contrast(text, _tint(OttosColors.warning)), greaterThanOrEqualTo(4.5));
    });

    testWidgets('REQ-007: «Entregada» uses the darker green text on the green tint', (tester) async {
      final (text, background) = await _pumpChip(
        tester,
        _remittance({'status': 'DELIVERED', 'courierId': 'c1', 'completedAt': '2026-11-05T12:00:00Z'}),
      );
      expect(text, OttosColors.successText);
      expect(background, OttosColors.success.withValues(alpha: 0.12));
      expect(_contrast(text, _tint(OttosColors.success)), greaterThanOrEqualTo(4.5));
    });

    testWidgets('REQ-007: on dark headers the chip is white with the same darker text', (tester) async {
      final (text, background) = await _pumpChip(
        tester,
        _remittance({'status': 'ASSIGNED', 'courierId': 'c1'}),
        onDark: true,
      );
      expect(background, Colors.white);
      expect(text, OttosColors.warningText);
      expect(_contrast(text, background), greaterThanOrEqualTo(4.5));
    });

    testWidgets('REQ-007: late and voided chips stay red', (tester) async {
      var (text, _) = await _pumpChip(tester, _remittance({'courierId': 'c1', 'late': true}));
      expect(text, OttosColors.danger);
      (text, _) = await _pumpChip(
        tester,
        _remittance({
          'voided': {'at': '2026-10-13T15:00:00Z', 'by': 'u1', 'reason': 'Duplicada'},
        }),
      );
      expect(text, OttosColors.danger);
    });

    testWidgets('REQ-007: the review badge and banner use the darker amber text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const ReviewBadge(),
                ReviewBanner(review: Review.fromJson(const {'reason': 'MANUAL'})),
              ],
            ),
          ),
        ),
      );
      final texts = tester.widgetList<Text>(find.textContaining(CoreTexts.toReview)).toList();
      expect(texts, hasLength(2));
      for (final text in texts) {
        expect(text.style!.color, OttosColors.warningText);
      }
      expect(_contrast(OttosColors.warningText, _tint(OttosColors.warning)), greaterThanOrEqualTo(4.5));
      expect(_contrast(OttosColors.warningText, _tint(OttosColors.warning, 0.08)), greaterThanOrEqualTo(4.5));
    });
  });
}
