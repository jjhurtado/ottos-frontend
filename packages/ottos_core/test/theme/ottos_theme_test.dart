import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('filled buttons have navy text on teal, readable at 4.5:1', () {
    final style = OttosTheme.light().filledButtonTheme.style!;
    final background = style.backgroundColor!.resolve({})!;
    final foreground = style.foregroundColor!.resolve({})!;

    expect(background, OttosColors.teal);
    expect(foreground, OttosColors.navy);
    expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
  });

  test('text on the secondary colour is navy', () {
    final scheme = OttosTheme.light().colorScheme;

    expect(scheme.onSecondary, OttosColors.navy);
    expect(_contrast(scheme.onSecondary, scheme.secondary), greaterThanOrEqualTo(4.5));
  });
}
