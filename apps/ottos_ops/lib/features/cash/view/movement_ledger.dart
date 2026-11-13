import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../widgets/pagination_bar.dart';
import '../cubit/movement_ledger_cubit.dart';
import 'movement_tile.dart';

/// The movements of a cash ledger with its filters (dates, type) and the
/// paging bar of the audit log (REQ-024 SCR-11, SCR-12). Needs a
/// [MovementLedgerCubit] above it.
class MovementLedger extends StatelessWidget {
  const MovementLedger({super.key, this.courierNames = const {}});

  /// Courier names by id, to say who received or returned cash.
  final Map<String, String> courierNames;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MovementLedgerCubit, MovementLedgerState>(
      builder: (context, state) {
        final cubit = context.read<MovementLedgerCubit>();
        final result = state.result;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Filters(filter: state.filter),
            const SizedBox(height: 8),
            switch ((state.status, result)) {
              (MovementLedgerStatus.failure, _) => ErrorView(message: state.error!, onRetry: cubit.load),
              (_, null) => const Padding(padding: EdgeInsets.all(24), child: LoadingView()),
              (_, final page?) when page.items.isEmpty && state.status == MovementLedgerStatus.success =>
                state.filter.isEmpty
                    ? const Text(OpsTexts.noMovements)
                    : Column(
                        children: [
                          const Text(OpsTexts.noMovementsFiltered),
                          TextButton.icon(
                            onPressed: () => cubit.filter(const MovementFilter()),
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: const Text(OpsTexts.clearFilters),
                          ),
                        ],
                      ),
              (_, final page?) => Column(
                children: [
                  if (state.status == MovementLedgerStatus.loading) const LinearProgressIndicator(),
                  for (final movement in page.items) MovementTile(movement: movement, courierNames: courierNames),
                  const Divider(height: 1),
                  PaginationBar(
                    result: page,
                    onPage: (index) => cubit.load(page: index),
                  ),
                ],
              ),
            },
          ],
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.filter});

  final MovementFilter filter;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MovementLedgerCubit>();

    Future<void> pickDate({required bool from}) async {
      final now = BusinessTime.today();
      final picked = await showDatePicker(
        context: context,
        initialDate: (from ? filter.from : filter.to) ?? now,
        firstDate: DateTime(2026),
        lastDate: now,
      );
      if (picked == null) return;
      await cubit.filter(from ? filter.copyWith(from: picked) : filter.copyWith(to: picked));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<CashMovementType?>(
            key: ValueKey('type-${filter.type}'),
            initialValue: filter.type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: OpsTexts.type, isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text(OpsTexts.allMovementTypes)),
              for (final type in CashMovementType.values)
                if (type != CashMovementType.unknown)
                  DropdownMenuItem(value: type, child: Text(OpsTexts.movementTitle(type))),
            ],
            onChanged: (type) => cubit.filter(filter.copyWith(type: type)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => pickDate(from: true),
          icon: const Icon(Icons.event_outlined),
          label: Text(filter.from == null ? OpsTexts.fromDate : '${OpsTexts.fromDate} ${Formatters.date(filter.from)}'),
        ),
        OutlinedButton.icon(
          onPressed: () => pickDate(from: false),
          icon: const Icon(Icons.event_outlined),
          label: Text(filter.to == null ? OpsTexts.toDate : '${OpsTexts.toDate} ${Formatters.date(filter.to)}'),
        ),
        if (!filter.isEmpty)
          TextButton.icon(
            onPressed: () => cubit.filter(const MovementFilter()),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text(OpsTexts.clearFilters),
          ),
      ],
    );
  }
}
