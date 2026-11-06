import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/src/widgets/dashed_rounded_border.dart';

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
}
