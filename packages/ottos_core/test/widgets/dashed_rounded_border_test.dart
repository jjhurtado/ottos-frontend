import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('CR-7: painting a border scaled to zero finishes', () {
    final scaled = const DashedRoundedBorder(color: Colors.black).scale(0);
    final recorder = PictureRecorder();
    scaled.paint(Canvas(recorder), const Rect.fromLTWH(0, 0, 100, 50));
    recorder.endRecording();
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('CR-7: lerp to null at 1 paints without looping', () {
    final lerped = ShapeBorder.lerp(const DashedRoundedBorder(color: Colors.black), null, 1);
    final recorder = PictureRecorder();
    lerped?.paint(Canvas(recorder), const Rect.fromLTWH(0, 0, 100, 50));
    recorder.endRecording();
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('CR-7: non-positive dash or gap is rejected', () {
    expect(() => DashedRoundedBorder(color: Colors.black, dash: 0), throwsAssertionError);
    expect(() => DashedRoundedBorder(color: Colors.black, gap: -1), throwsAssertionError);
  });

  test('REQ-020 CR-2: the default radius is the theme card radius', () {
    final shape = OttosTheme.light().cardTheme.shape! as RoundedRectangleBorder;
    expect((shape.borderRadius as BorderRadius).topLeft.x, OttosTheme.cardRadius);
    expect(const DashedRoundedBorder(color: Colors.black).radius, OttosTheme.cardRadius);
  });

  group('REQ-020 CR-8: the shape', () {
    const border = DashedRoundedBorder(color: Colors.black, width: 2);
    const rect = Rect.fromLTWH(0, 0, 200, 80);

    test('outer path covers the rect, inner path is smaller', () {
      final outer = border.getOuterPath(rect).getBounds();
      final inner = border.getInnerPath(rect).getBounds();
      expect(outer, rect);
      expect(inner, rect.deflate(2));
      expect(border.dimensions, const EdgeInsets.all(2));
    });

    test('scale multiplies every size and keeps the colour', () {
      final scaled = border.scale(2) as DashedRoundedBorder;
      expect(
        (scaled.radius, scaled.width, scaled.dash, scaled.gap, scaled.color),
        (border.radius * 2, 4.0, border.dash * 2, border.gap * 2, Colors.black),
      );
    });

    test('equality and hashCode cover every field', () {
      expect(border, const DashedRoundedBorder(color: Colors.black, width: 2));
      expect(border.hashCode, const DashedRoundedBorder(color: Colors.black, width: 2).hashCode);
      expect(border, isNot(const DashedRoundedBorder(color: Colors.red, width: 2)));
      expect(border, isNot(const DashedRoundedBorder(color: Colors.black, width: 2, dash: 5)));
      expect(border, isNot(const DashedRoundedBorder(color: Colors.black, width: 2, gap: 5)));
      expect(border, isNot(const DashedRoundedBorder(color: Colors.black, width: 2, radius: 3)));
      expect(border, isNot(const DashedRoundedBorder(color: Colors.black, width: 1)));
    });
  });
}
