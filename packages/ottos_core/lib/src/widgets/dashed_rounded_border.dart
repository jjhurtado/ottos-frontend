import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/ottos_theme.dart';

/// A rounded rectangle outline drawn as dashes. Use it as the `shape` of a `Card`: the
/// card still clips its child to the rounded rectangle and keeps the ink ripple.
class DashedRoundedBorder extends ShapeBorder {
  const DashedRoundedBorder({
    required this.color,
    this.radius = OttosTheme.cardRadius,
    this.width = 1,
    this.dash = 6,
    this.gap = 4,
  }) : assert(dash > 0, 'dash must be positive'),
       assert(gap > 0, 'gap must be positive');

  /// Used by [scale], which may reach zero (for example `ShapeBorder.lerp(dashed, null, 1)`); [paint] draws nothing then.
  const DashedRoundedBorder._scaled({
    required this.color,
    required this.radius,
    required this.width,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double width;
  final double dash;
  final double gap;

  RRect _rrect(Rect rect) => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_rrect(rect).deflate(width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_rrect(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (dash + gap <= 0 || width <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final outline = Path()..addRRect(_rrect(rect).deflate(width / 2));
    final dashes = Path();
    for (final PathMetric metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashes.addPath(metric.extractPath(distance, distance + dash), Offset.zero);
        distance += dash + gap;
      }
    }
    canvas.drawPath(dashes, paint);
  }

  @override
  ShapeBorder scale(double t) =>
      DashedRoundedBorder._scaled(color: color, radius: radius * t, width: width * t, dash: dash * t, gap: gap * t);

  @override
  bool operator ==(Object other) =>
      other is DashedRoundedBorder &&
      other.color == color &&
      other.radius == radius &&
      other.width == width &&
      other.dash == dash &&
      other.gap == gap;

  @override
  int get hashCode => Object.hash(color, radius, width, dash, gap);
}
