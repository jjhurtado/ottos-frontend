import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';
import '../utils/formatters.dart';

/// A voided remittance: who voided it, when and why. It stays visible but no
/// longer counts and cannot change.
class VoidedBanner extends StatelessWidget {
  const VoidedBanner({super.key, required this.voided});

  final Voided voided;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OttosColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: OttosColors.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, color: OttosColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CoreTexts.voidedBy(voided.byName),
                  style: const TextStyle(color: OttosColors.danger, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('${CoreTexts.voidReason}: ${voided.reason}'),
                if (voided.at != null) ...[
                  const SizedBox(height: 4),
                  Text(Formatters.dateTime(voided.at), style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 4),
                Text(CoreTexts.voidedHelp, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
