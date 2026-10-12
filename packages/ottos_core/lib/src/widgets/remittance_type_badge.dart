import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';

/// How each remittance type looks, so deliveries and pickups never look alike.
extension RemittanceTypeStyle on RemittanceType {
  Color get color => switch (this) {
    RemittanceType.delivery => OttosColors.delivery,
    RemittanceType.pickup => OttosColors.pickup,
  };

  IconData get icon => switch (this) {
    RemittanceType.delivery => Icons.local_shipping_outlined,
    RemittanceType.pickup => Icons.move_to_inbox_outlined,
  };

  String get label => switch (this) {
    RemittanceType.delivery => CoreTexts.delivery,
    RemittanceType.pickup => CoreTexts.pickup,
  };
}

/// "Entrega" or "Recogida", with the type's icon and color.
class RemittanceTypeBadge extends StatelessWidget {
  const RemittanceTypeBadge({super.key, required this.type, this.onDark = false});

  final RemittanceType type;

  /// White on the type's color, for dark or colored headers.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : type.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.18) : type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            type.label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
