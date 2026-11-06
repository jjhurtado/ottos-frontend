import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/pending_totals.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';
import '../utils/formatters.dart';

/// The two tiles of money pending (REQ-021): to deliver and to collect, one
/// line per currency with its number of remittances. Side by side; on a narrow
/// screen each takes half. [onTap] opens what a tile adds up, when given.
class PendingTotalsTiles extends StatelessWidget {
  const PendingTotalsTiles({
    super.key,
    required this.totals,
    this.deliverLabel = CoreTexts.pendingToDeliver,
    this.collectLabel = CoreTexts.pendingToCollect,
    this.onTap,
  });

  final PendingTotals totals;
  final String deliverLabel;
  final String collectLabel;
  final ValueChanged<RemittanceType>? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PendingTotalsTile(
              label: deliverLabel,
              amounts: totals.toDeliver,
              color: OttosColors.delivery,
              icon: Icons.south_east,
              onTap: onTap == null ? null : () => onTap(RemittanceType.delivery),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PendingTotalsTile(
              label: collectLabel,
              amounts: totals.toCollect,
              color: OttosColors.pickup,
              icon: Icons.north_west,
              onTap: onTap == null ? null : () => onTap(RemittanceType.pickup),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tile of money pending, like the counters of the panel Home.
class PendingTotalsTile extends StatelessWidget {
  const PendingTotalsTile({
    super.key,
    required this.label,
    required this.amounts,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final List<PendingAmount> amounts;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label, style: textTheme.titleSmall)),
                ],
              ),
              const SizedBox(height: 8),
              if (amounts.isEmpty)
                Text(CoreTexts.nothingPending, style: textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              for (final amount in amounts)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large amounts shrink instead of overflowing a narrow tile.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.money(amount.amount, amount.currency),
                          style: textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        CoreTexts.remittanceCount(amount.remittances),
                        style: textTheme.bodySmall?.copyWith(color: OttosColors.inkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
