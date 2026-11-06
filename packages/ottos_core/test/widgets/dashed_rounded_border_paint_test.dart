import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  const red = Color(0xFFFF0000);

  testWidgets('REQ-020 DEF-1: the outline is drawn as several separate dashes, not one closed line', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 80,
            child: Card(
              shape: DashedRoundedBorder(color: red),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    // The perimeter is about 536 px; a dash every 10 px gives dozens of strokes in the
    // border colour. A solid outline would draw one path.
    var strokes = 0;
    final matcher = paints
      ..everything((Symbol method, List<dynamic> args) {
        if (method == #drawPath) {
          final paint = args[1] as Paint;
          if (paint.color == red && paint.style == PaintingStyle.stroke) strokes++;
        }
        return true;
      });
    expect(find.byType(Card), matcher);
    expect(strokes, greaterThan(40));
  });

  test('REQ-020 DEF-1: the border keeps the rounded clip and scales', () {
    const border = DashedRoundedBorder(color: red);
    const rect = Rect.fromLTWH(0, 0, 200, 80);
    expect(border.getOuterPath(rect).contains(const Offset(1, 1)), isFalse, reason: 'the corner is rounded');
    expect(border.getOuterPath(rect).contains(const Offset(100, 40)), isTrue);
    expect((border.scale(2) as DashedRoundedBorder).dash, 12);
    expect(border, const DashedRoundedBorder(color: red));
  });
}
