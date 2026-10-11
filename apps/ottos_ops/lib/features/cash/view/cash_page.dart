import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../app/router.dart';
import '../cubit/cash_overview_cubit.dart';
import 'movement_tile.dart';

class CashPage extends StatelessWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CashOverviewCubit(cash: context.read<CashRepository>())..load(),
      child: BlocBuilder<CashOverviewCubit, CashOverviewState>(
        builder: (context, state) => switch (state.status) {
          CashOverviewStatus.loading => const LoadingView(),
          CashOverviewStatus.failure => ErrorView(
            message: state.error!,
            onRetry: context.read<CashOverviewCubit>().load,
          ),
          CashOverviewStatus.success => _CashView(state: state),
        },
      ),
    );
  }
}

class _CashView extends StatelessWidget {
  const _CashView({required this.state});

  final CashOverviewState state;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user!);
    final cubit = context.read<CashOverviewCubit>();
    final cash = context.read<CashRepository>();
    final courierNames = {for (final courier in state.couriers) courier.courierId: courier.name};

    Future<void> operate({
      required String title,
      required String confirm,
      required Future<CashMovement> Function(CashInput) submit,
      bool noteRequired = false,
      String? help,
    }) async {
      final movement = await showCashOperationDialog(
        context,
        title: title,
        confirmLabel: confirm,
        currencies: state.currencies,
        submit: submit,
        noteRequired: noteRequired,
        help: help,
      );
      if (movement == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OpsTexts.movementRegistered(Formatters.money(movement.amount, movement.currency)))),
      );
      await cubit.load();
    }

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(child: Text(OpsTexts.cash, style: Theme.of(context).textTheme.headlineMedium)),
              IconButton(tooltip: CoreTexts.retry, onPressed: cubit.load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: OpsTexts.businessCash,
            actions: [
              if (user.can(Permissions.cashAdjust)) ...[
                OutlinedButton.icon(
                  onPressed: () => operate(
                    title: OpsTexts.deposit,
                    confirm: OpsTexts.deposit,
                    submit: cash.deposit,
                    noteRequired: true,
                    help: OpsTexts.depositHelp,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(OpsTexts.deposit),
                ),
                OutlinedButton.icon(
                  onPressed: () => operate(
                    title: OpsTexts.withdraw,
                    confirm: OpsTexts.withdraw,
                    submit: cash.withdraw,
                    noteRequired: true,
                    help: OpsTexts.withdrawHelp,
                  ),
                  icon: const Icon(Icons.remove),
                  label: const Text(OpsTexts.withdraw),
                ),
              ],
            ],
            child: state.balances.isEmpty
                ? const Text(OpsTexts.noBalances)
                : Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final balance in state.balances) _BalanceTile(balance: balance)],
                  ),
          ),
          _Section(
            title: OpsTexts.couriersCash,
            child: state.couriers.isEmpty
                ? const Text(OpsTexts.noCourierCash)
                : _CourierCashTable(
                    couriers: state.couriers,
                    canWrite: user.can(Permissions.cashWrite),
                    onFund: (courier) => operate(
                      title: OpsTexts.fundCourierTitle(courier.name),
                      confirm: OpsTexts.fund,
                      submit: (input) => cash.fundCourier(courier.courierId, input),
                    ),
                    onReturn: (courier) => operate(
                      title: OpsTexts.courierReturnTitle(courier.name),
                      confirm: OpsTexts.registerReturn,
                      submit: (input) => cash.courierReturn(courier.courierId, input),
                    ),
                  ),
          ),
          _Section(
            title: OpsTexts.latestMovements,
            child: state.movements.isEmpty
                ? const Text(OpsTexts.noMovements)
                : Column(
                    children: [
                      for (final movement in state.movements)
                        MovementTile(movement: movement, courierNames: courierNames),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.actions = const []});

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ...actions,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.balance});

  final Balance balance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(balance.currency, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            Formatters.money(balance.amount, null),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: balance.amount < 0 ? colors.error : null, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CourierCashTable extends StatelessWidget {
  const _CourierCashTable({
    required this.couriers,
    required this.canWrite,
    required this.onFund,
    required this.onReturn,
  });

  final List<CourierCash> couriers;
  final bool canWrite;
  final void Function(CourierCash) onFund;
  final void Function(CourierCash) onReturn;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return SizedBox(
      width: double.infinity,
      child: DataTable(
        showCheckboxColumn: false,
        columns: [
          const DataColumn(label: Text(OpsTexts.courier)),
          const DataColumn(label: Text(OpsTexts.balance)),
          if (canWrite) const DataColumn(label: Text('')),
        ],
        rows: [
          for (final courier in couriers)
            DataRow(
              onSelectChanged: (_) => context.go(Routes.courierCash(courier.courierId)),
              cells: [
                DataCell(
                  Row(
                    children: [
                      Text(courier.name),
                      if (courier.negative) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: OpsTexts.courierOwes,
                          child: Icon(Icons.warning_amber_rounded, size: 18, color: error),
                        ),
                      ],
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    courier.balances.isEmpty
                        ? '—'
                        : courier.balances.map((b) => Formatters.money(b.amount, b.currency)).join(' · '),
                    style: TextStyle(color: courier.negative ? error : null),
                  ),
                ),
                if (canWrite)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: () => onFund(courier), child: const Text(OpsTexts.fund)),
                        TextButton(onPressed: () => onReturn(courier), child: const Text(OpsTexts.registerReturn)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
