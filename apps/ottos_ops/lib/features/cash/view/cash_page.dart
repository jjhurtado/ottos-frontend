import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../app/router.dart';
import '../cubit/cash_overview_cubit.dart';
import 'exchanges_to_review.dart';
import 'movement_tile.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/refresh_on_return.dart';

class CashPage extends StatelessWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CashOverviewCubit(cash: context.read<CashRepository>())..load(),
      // Back from a courier's cash, where money may have moved: refresh.
      child: Builder(
        builder: (context) => RefreshOnReturn(
          onReturn: context.read<CashOverviewCubit>().load,
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
        ),
      ),
    );
  }
}

class _CashView extends StatelessWidget {
  const _CashView({required this.state});

  final CashOverviewState state;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    // No user while logging out: the page goes before the redirect.
    if (user == null) return const SizedBox.shrink();
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
        padding: pagePadding(context),
        children: [
          Row(
            children: [
              Expanded(child: Text(OpsTexts.cash, style: Theme.of(context).textTheme.headlineMedium)),
              IconButton(tooltip: CoreTexts.retry, onPressed: cubit.load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          // A new key reloads it with the page (pull to refresh, after an operation).
          ExchangesToReview(key: ValueKey(state.movements.firstOrNull?.id)),
          _Section(
            title: OpsTexts.businessCash,
            help: OpsTexts.businessCashHelp,
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
                    runSpacing: isCompact(context) ? 8 : 16,
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
  const _Section({required this.title, required this.child, this.actions = const [], this.help});

  final String title;
  final Widget child;
  final List<Widget> actions;

  /// What the section counts, under the title.
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(isCompact(context) ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            // Under the title, so they never squeeze it.
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, children: actions),
            ],
            if (help != null) ...[const SizedBox(height: 8), Text(help!, style: Theme.of(context).textTheme.bodySmall)],
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
    final textTheme = Theme.of(context).textTheme;
    final currency = Text(balance.currency, style: textTheme.labelLarge);
    final amount = Text(
      Formatters.money(balance.amount, null),
      style: textTheme.headlineSmall?.copyWith(
        color: balance.amount < 0 ? colors.error : null,
        fontWeight: FontWeight.w600,
      ),
    );
    final decoration = BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12));
    // On a phone, one full-width row per currency: big amounts never wrap.
    if (isCompact(context)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: decoration,
        child: Row(
          children: [
            currency,
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(fit: BoxFit.scaleDown, child: amount),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [currency, const SizedBox(height: 4), amount],
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
    if (isCompact(context)) {
      return Column(
        children: [
          for (final courier in couriers) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => context.go(Routes.courierCash(courier.courierId)),
              title: Row(
                children: [
                  Flexible(child: Text(courier.name)),
                  if (courier.negative) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: OpsTexts.courierOwes,
                      child: Icon(Icons.warning_amber_rounded, size: 18, color: error),
                    ),
                  ],
                ],
              ),
              subtitle: BalancesText(balances: courier.balances, empty: '—', negativeColor: error),
            ),
            if (canWrite)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(onPressed: () => onFund(courier), child: const Text(OpsTexts.fund)),
                  TextButton(onPressed: () => onReturn(courier), child: const Text(OpsTexts.registerReturn)),
                ],
              ),
          ],
        ],
      );
    }
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
                DataCell(BalancesText(balances: courier.balances, empty: '—', negativeColor: error)),
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
