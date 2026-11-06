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

  test('REQ-007 CR-1: the voided grey keeps its value and reads at 4.5:1 on white and on its tint', () {
    expect(OttosColors.voidedGrey, const Color(0xFF44474E));
    expect(_contrast(OttosColors.voidedGrey, Colors.white), greaterThanOrEqualTo(4.5));
    final tint = Color.alphaBlend(OttosColors.voidedGrey.withValues(alpha: 0.12), Colors.white);
    expect(_contrast(OttosColors.voidedGrey, tint), greaterThanOrEqualTo(4.5));
  });
}
