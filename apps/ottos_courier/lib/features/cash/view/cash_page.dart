import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';
import '../../../offline/sync_bar.dart';
import '../../../offline/sync_cubit.dart';
import '../cubit/cash_cubit.dart';

class CashPage extends StatelessWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ownCash = context.canDo(Permissions.cashReadOwn);
    final couriersCash = context.canDo(Permissions.cashRead);
    final sync = context.syncCubit;
    return BlocProvider(
      create: (context) => CashCubit(
        cash: context.read<CashRepository>(),
        ownCash: ownCash,
        couriersCash: couriersCash,
        // A courier's cash as of the last sync, also without network.
        ownStatement: sync?.cash,
      )..load(),
      child: _ReloadOnSync(
        sync: sync,
        child: BlocBuilder<CashCubit, CashState>(
          builder: (context, state) {
            final cubit = context.read<CashCubit>();
            final statement = state.statement;
            final couriers = state.couriers;
            if (!state.loaded) {
              return state.status == CashStatus.failure
                  ? ErrorView(message: state.error!, onRetry: cubit.load)
                  : const LoadingView();
            }
            return RefreshIndicator(
              onRefresh: () async {
                await sync?.sync();
                await cubit.load();
              },
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (couriers != null) ...[
                    _SectionTitle(CourierTexts.couriersCash),
                    if (couriers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: EmptyView(message: CourierTexts.noCouriers),
                      ),
                    for (final courier in couriers) _CourierCashTile(courier: courier),
                    const SizedBox(height: 12),
                  ],
                  if (statement != null) ...[
                    _BalancesCard(cash: statement.cash),
                    if (context.canDo(Permissions.cashExchangeOwn)) ...[
                      const SizedBox(height: 8),
                      _ExchangeButton(sync: sync),
                    ],
                    const SizedBox(height: 12),
                    _SectionTitle(CourierTexts.movements),
                    if (statement.movements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: EmptyView(message: CourierTexts.noMovements),
                      ),
                    for (final movement in statement.movements) _MovementTile(movement: movement),
                  ],
                ],
              ),
            );
          },
        ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// A courier's balances, with funding and returns for who can move cash.
class _CourierCashTile extends StatelessWidget {
  const _CourierCashTile({required this.courier});

  final CourierCash courier;

  @override
  Widget build(BuildContext context) {
    final canWrite = context.canDo(Permissions.cashWrite);
    final cubit = context.read<CashCubit>();
    final textTheme = Theme.of(context).textTheme;
    final currencies = {'USD', 'CUP', for (final balance in courier.balances) balance.currency}.toList();

    Future<void> operate(String title, String confirm, Future<CashMovement> Function(CashInput) submit) async {
      final movement = await showCashOperationDialog(
        context,
        title: title,
        confirmLabel: confirm,
        currencies: currencies,
        submit: submit,
      );
      if (movement == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CourierTexts.movementRegistered(Formatters.money(movement.amount, movement.currency)))),
      );
      await cubit.load();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(courier.name, style: textTheme.titleSmall)),
                if (courier.negative) const Icon(Icons.warning_amber, color: OttosColors.danger, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              courier.balances.isEmpty
                  ? Formatters.money(0, null)
                  : courier.balances.map((balance) => Formatters.money(balance.amount, balance.currency)).join(' · '),
              style: textTheme.bodyMedium?.copyWith(color: courier.negative ? OttosColors.danger : null),
            ),
            if (canWrite)
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => operate(
                      CourierTexts.fundTitle(courier.name),
                      CourierTexts.fund,
                      (input) => cubit.fund(courier, input),
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(CourierTexts.fund),
                  ),
                  TextButton.icon(
                    onPressed: () => operate(
                      CourierTexts.returnTitle(courier.name),
                      CourierTexts.registerReturn,
                      (input) => cubit.registerReturn(courier, input),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text(CourierTexts.registerReturn),
                  ),
                ],
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Reloads the cash after each sync, which may bring the server's balance.
class _ReloadOnSync extends StatelessWidget {
  const _ReloadOnSync({required this.sync, required this.child});

  final SyncCubit? sync;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sync = this.sync;
    if (sync == null) return child;
    return BlocListener<SyncCubit, SyncStatus>(
      bloc: sync,
      listenWhen: (previous, current) => previous.revision != current.revision,
      listener: (context, _) => context.read<CashCubit>().load(),
      child: child,
    );
  }
}

/// Records a currency exchange of the courier's own cash; offline it waits in
/// the queue and the balance already shows it.
class _ExchangeButton extends StatelessWidget {
  const _ExchangeButton({required this.sync});

  final SyncCubit? sync;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CashCubit>();
    final cash = context.read<CashRepository>();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final input = await showExchangeDialog(context);
        if (input == null) return;
        final sync = this.sync;
        final outcome = sync != null ? await sync.exchange(input) : await _online(cash, input);
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (outcome) {
              Applied(flaggedForReview: true) => CourierTexts.exchangeFlagged,
              _ => CourierTexts.outcome(outcome, done: CourierTexts.exchangeDone),
            }),
          ),
        );
        await cubit.load();
      },
      icon: const Icon(Icons.currency_exchange),
      label: const Text(CoreTexts.exchangeTitle),
    );
  }

  /// Without sync (tests, or a user who works online) it goes straight to the server.
  static Future<ActionOutcome> _online(CashRepository cash, ExchangeInput input) async {
    try {
      final exchange = await cash.exchangeOwn(input);
      return Applied(null, flaggedForReview: exchange.pendingReview);
    } on ApiException catch (error) {
      return Rejected(error.message);
    }
  }
}
