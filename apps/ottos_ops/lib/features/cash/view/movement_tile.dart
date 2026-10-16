import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../widgets/page_header.dart';
import '../../../app/router.dart';

/// One ledger movement: what it was, when, its note and the signed amount
/// (green when money enters the account being looked at).
class MovementTile extends StatelessWidget {
  const MovementTile({super.key, required this.movement, this.courierNames = const {}});

  final CashMovement movement;

  /// Courier names by id, to say who received or returned cash.
  final Map<String, String> courierNames;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final incoming = movement.signedAmount >= 0;
    final courierId = movement.toType == 'COURIER' ? movement.toOwnerId : movement.fromOwnerId;
    final courier = courierId == null ? null : courierNames[courierId];
    final remittanceId = movement.remittanceId;
    final title = courier == null
        ? OpsTexts.movementTitle(movement.type)
        : '${OpsTexts.movementTitle(movement.type)} · $courier';
    final amount = Text(
      '${incoming ? '+' : '−'}${Formatters.money(movement.signedAmount.abs(), movement.currency)}',
      style: TextStyle(fontWeight: FontWeight.w600, color: incoming ? Colors.green.shade700 : colors.error),
    );
    final compact = isCompact(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        incoming ? Icons.south_west : Icons.north_east,
        color: incoming ? Colors.green.shade700 : colors.error,
      ),
      // On a phone the amount goes under the title, so the text keeps the width.
      title: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title), amount])
          : Text(title),
      subtitle: Text(
        [
          Formatters.dateTime(movement.occurredAt),
          if (movement.rate != null) CoreTexts.exchangeRateValue(Formatters.money(movement.rate, null)),
          movement.note,
        ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: compact ? null : amount,
      onTap: remittanceId == null ? null : () => context.go(Routes.remittance(remittanceId)),
    );
  }
}
