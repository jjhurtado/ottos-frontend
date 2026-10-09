import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';
import '../cubit/cash_cubit.dart';

class CashPage extends StatelessWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CashCubit(cash: context.read<CashRepository>())..load(),
      child: BlocBuilder<CashCubit, CashState>(
        builder: (context, state) {
          final cubit = context.read<CashCubit>();
          final statement = state.statement;
          if (statement == null) {
            return state.status == CashStatus.failure
                ? ErrorView(message: state.error!, onRetry: cubit.load)
                : const LoadingView();
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _BalancesCard(cash: statement.cash),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(CourierTexts.movements, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (statement.movements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: EmptyView(message: CourierTexts.noMovements),
                  ),
                for (final movement in statement.movements) _MovementTile(movement: movement),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalancesCard extends StatelessWidget {
  const _BalancesCard({required this.cash});

  final CourierCash cash;

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
              Text(CourierTexts.owesBusiness, style: textTheme.bodySmall?.copyWith(color: OttosColors.cream)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

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
          [Formatters.dateTime(movement.occurredAt), if (movement.note != null) movement.note!].join(' · '),
        ),
        trailing: Text(
          '${incoming ? '+' : ''}${Formatters.money(movement.signedAmount, movement.currency)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
