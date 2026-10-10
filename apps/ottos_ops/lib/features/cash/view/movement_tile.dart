import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        incoming ? Icons.south_west : Icons.north_east,
        color: incoming ? Colors.green.shade700 : colors.error,
      ),
      title: Text(
        courier == null ? OpsTexts.movementTitle(movement.type) : '${OpsTexts.movementTitle(movement.type)} · $courier',
      ),
      subtitle: Text(
        [
          Formatters.dateTime(movement.occurredAt),
          movement.note,
        ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: Text(
        '${incoming ? '+' : '−'}${Formatters.money(movement.signedAmount.abs(), movement.currency)}',
        style: TextStyle(fontWeight: FontWeight.w600, color: incoming ? Colors.green.shade700 : colors.error),
      ),
      onTap: remittanceId == null ? null : () => context.go(Routes.remittance(remittanceId)),
    );
  }
}
