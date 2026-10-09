import 'package:flutter/material.dart';

/// The Ottos logo. The image has its own navy background, so place it on a
/// navy surface.
class OttosLogo extends StatelessWidget {
  const OttosLogo({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'packages/ottos_core/assets/brand/ottos_logo.jpg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: "Otto's",
    );
  }
}
