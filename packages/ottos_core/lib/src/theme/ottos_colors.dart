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

  /// Deliveries on the house (no fee): a gift, unlike any status or type color.
  static const onTheHouse = Color(0xFFB83280);

  static const success = Color(0xFF2E7D4F);
  static const warning = Color(0xFFB7791F);

  /// Small text on a light tint of [success] or [warning] (status chips,
  /// review badges): same hue, dark enough for 4.5:1 on the tint.
  static const successText = Color(0xFF297047);
  static const warningText = Color(0xFF926119);
  static const danger = Color(0xFFC0392B);

  /// Voided rows and muted report text (7.7:1 on white).
  static const voidedGrey = Color(0xFF44474E);

  /// A completed remittance in the app's lists (REQ-020): grey card, outline
  /// and muted text, so it reads as done next to the open ones.
  static const completedSurface = Color(0xFFF1F2F5);
  static const completedBorder = Color(0xFFB9BCC8);
  static const inkMuted = Color(0xFF5F6170);
}
