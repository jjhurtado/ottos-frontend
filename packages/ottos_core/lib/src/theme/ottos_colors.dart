import 'package:flutter/material.dart';

/// Brand colors, taken from the Ottos logo.
abstract final class OttosColors {
  /// Logo background.
  static const navy = Color(0xFF040A30);
  static const navyLight = Color(0xFF1B2250);

  /// Logo chevrons.
  static const teal = Color(0xFF0096B1);
  static const tealDark = Color(0xFF00718A);

  /// Logo lettering.
  static const cream = Color(0xFFFAE3BB);
  static const creamLight = Color(0xFFFDF6EA);

  /// Remittance types: the courier hands cash over (delivery) or collects it (pickup).
  /// Pickup avoids amber, which marks assigned remittances.
  static const delivery = tealDark;
  static const pickup = Color(0xFF6B46C1);

  static const success = Color(0xFF2E7D4F);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFC0392B);
}
