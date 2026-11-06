import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// A rounded rectangle outline drawn as dashes. Use it as the `shape` of a `Card`: the
/// card still clips its child to the rounded rectangle and keeps the ink ripple.
class DashedRoundedBorder extends ShapeBorder {
  const DashedRoundedBorder({required this.color, this.radius = 14, this.width = 1, this.dash = 6, this.gap = 4});

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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()..addRRect(_rrect(rect).deflate(width / 2));
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  ShapeBorder scale(double t) =>
      DashedRoundedBorder(color: color, radius: radius * t, width: width * t, dash: dash * t, gap: gap * t);

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
