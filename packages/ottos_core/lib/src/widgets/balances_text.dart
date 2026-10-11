import 'package:flutter/material.dart';

import '../models/cash.dart';
import '../utils/formatters.dart';

/// "-76.000,00 CUP · 200,00 USD", each amount in [negativeColor] only when it
/// is below zero: one currency owed does not make the others look owed.
class BalancesText extends StatelessWidget {
  const BalancesText({super.key, required this.balances, required this.empty, this.style, this.negativeColor});

  final List<Balance> balances;

  /// Shown when there are no balances yet.
  final String empty;
  final TextStyle? style;

  /// Defaults to the theme's error color.
  final Color? negativeColor;

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) return Text(empty, style: style);
    final negative = negativeColor ?? Theme.of(context).colorScheme.error;
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < balances.length; i++) ...[
            if (i > 0) const TextSpan(text: ' · '),
            TextSpan(
              text: Formatters.money(balances[i].amount, balances[i].currency),
              style: balances[i].amount < 0 ? TextStyle(color: negative) : null,
            ),
          ],
        ],
      ),
      style: style,
    );
  }
}
