import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';
import '../../../offline/sync_cubit.dart';

/// A courier's balances, as the courier and sales see them.
class BalancesCard extends StatelessWidget {
  const BalancesCard({super.key, required this.cash, this.owesText = CourierTexts.owesBusiness});

  final CourierCash cash;

  /// Under the balances when some currency is negative.
  final String owesText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: OttosColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(CourierTexts.balances, style: textTheme.titleSmall?.copyWith(color: OttosColors.cream)),
            const SizedBox(height: 8),
            if (cash.balances.isEmpty)
              Text(Formatters.money(0, null), style: textTheme.headlineSmall?.copyWith(color: Colors.white)),
            for (final balance in cash.balances)
              Text(
                Formatters.money(balance.amount, balance.currency),
                style: textTheme.headlineSmall?.copyWith(
                  color: balance.amount < 0 ? const Color(0xFFFF8A80) : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (cash.negative) ...[
              const SizedBox(height: 8),
              Text(owesText, style: textTheme.bodySmall?.copyWith(color: OttosColors.cream)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One cash movement, signed: green what came in, red what went out.
class MovementTile extends StatelessWidget {
  const MovementTile({super.key, required this.movement});

  final CashMovement movement;

  @override
  Widget build(BuildContext context) {
    final incoming = movement.signedAmount >= 0;
    final color = incoming ? OttosColors.success : OttosColors.danger;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(incoming ? Icons.south_west : Icons.north_east, color: color),
        title: Text(CourierTexts.movementTitle(movement.type.code)),
        subtitle: Text(
          [
            Formatters.dateTime(movement.occurredAt),
            if (movement.rate != null) CoreTexts.exchangeRateValue(Formatters.money(movement.rate, null)),
            if (movement.note != null) movement.note!,
            // Counted already, though the server does not have it yet.
            if (SyncCubit.isUnsent(movement)) CourierTexts.unsent,
          ].join(' · '),
        ),
        trailing: Text(
          '${incoming ? '+' : ''}${Formatters.money(movement.signedAmount, movement.currency)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
