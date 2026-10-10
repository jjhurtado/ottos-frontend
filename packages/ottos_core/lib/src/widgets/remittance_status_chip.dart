import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';

/// Status of a remittance; red when it is late, green when it is completed.
class RemittanceStatusChip extends StatelessWidget {
  const RemittanceStatusChip({super.key, required this.remittance, this.onDark = false});

  final Remittance remittance;

  /// Solid white background, to stay readable on dark or colored headers.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (remittance) {
      Remittance(isCompleted: true) => (OttosColors.success, remittance.statusName),
      Remittance(late: true) => (OttosColors.danger, '${remittance.statusName} · ${CoreTexts.late}'),
      Remittance(courierId: != null) => (OttosColors.warning, remittance.statusName),
      _ => (OttosColors.teal, remittance.statusName),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
