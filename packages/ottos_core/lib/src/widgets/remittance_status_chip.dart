import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';

/// Status of a remittance; red when it is late or voided, green when it is completed.
class RemittanceStatusChip extends StatelessWidget {
  const RemittanceStatusChip({super.key, required this.remittance, this.onDark = false, this.showCheck = false});

  final Remittance remittance;

  /// Solid white background, to stay readable on dark or colored headers.
  final bool onDark;

  /// A check mark before the word of a completed remittance, so it does not
  /// rely on colour alone (REQ-020). The mobile app uses it; the panel does not.
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    // The tint comes from the base colour; the text uses a darker shade of the
    // same hue so it reads at 4.5:1 on the tint and on white.
    final (:color, :textColor, :label) = switch (remittance) {
      // Voided wins over everything: it no longer counts, whatever its status.
      Remittance(isVoided: true) => (color: OttosColors.danger, textColor: OttosColors.danger, label: CoreTexts.voided),
      Remittance(isCompleted: true) => (
        color: OttosColors.success,
        textColor: OttosColors.successText,
        label: remittance.displayStatus,
      ),
      Remittance(late: true) => (
        color: OttosColors.danger,
        textColor: OttosColors.danger,
        label: '${remittance.displayStatus} · ${CoreTexts.late}',
      ),
      Remittance(courierId: != null) => (
        color: OttosColors.warning,
        textColor: OttosColors.warningText,
        label: remittance.displayStatus,
      ),
      _ => (color: OttosColors.teal, textColor: OttosColors.tealDark, label: remittance.displayStatus),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCheck && remittance.isDone) ...[
            Icon(Icons.check, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
