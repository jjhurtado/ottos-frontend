import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';
import '../../../app/router.dart';
import '../../../offline/remittance_source.dart';
import '../../../offline/sync_cubit.dart';
import '../cubit/assigned_cubit.dart';

class AssignedPage extends StatelessWidget {
  const AssignedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canCreate = context.canDo(Permissions.remittancesCreate);
    return BlocProvider(
      create: (context) => AssignedCubit(source: context.read<RemittanceSource>())..load(),
      child: Scaffold(
        body: const _AssignedView(),
        floatingActionButton: canCreate ? const _NewRemittanceButton() : null,
      ),
    );
  }
}

class _AssignedView extends StatelessWidget {
  const _AssignedView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssignedCubit>();
    return BlocConsumer<AssignedCubit, AssignedState>(
      listenWhen: (_, current) => current.status == AssignedStatus.failure && current.items.isNotEmpty,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!))),
      builder: (context, state) {
        final selector = _SortSelector(
          sort: state.sort,
          onChanged: cubit.sortBy,
          showCompleted: cubit.canShowCompleted ? state.showCompleted : null,
          onShowCompleted: cubit.showCompleted,
        );
        if (state.items.isEmpty) {
          return switch (state.status) {
            AssignedStatus.loading => const LoadingView(),
            AssignedStatus.failure => ErrorView(message: state.error!, onRetry: cubit.load),
            AssignedStatus.success => RefreshIndicator(
              onRefresh: cubit.refresh,
              child: ListView(
                padding: cubit.canShowCompleted ? const EdgeInsets.all(12) : null,
                children: [
                  // Sales can still turn on the completed ones when nothing is open.
                  if (cubit.canShowCompleted) selector,
                  SizedBox(
                    height: 200,
                    child: EmptyView(
                      message: state.showCompleted ? CourierTexts.noRemittances : CourierTexts.noAssigned,
                    ),
                  ),
                ],
              ),
            ),
          };
        }
        return RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: state.items.length + (state.moreCompleted ? 2 : 1),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) return selector;
              if (index > state.items.length) {
                return Center(
                  child: TextButton(
                    onPressed: state.status == AssignedStatus.loading ? null : cubit.moreCompleted,
                    child: const Text(CourierTexts.showMore),
                  ),
                );
              }
              final remittance = state.items[index - 1];
              return _Swipeable(
                remittance: remittance,
                child: _AssignedCard(
                  remittance: remittance,
                  unsent: state.pendingIds.contains(remittance.id),
                  onTap: () async {
                    // Reload on return: the remittance may have been completed or postponed.
                    await context.push(Routes.remittance(remittance.id));
                    await cubit.load();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NewRemittanceButton extends StatelessWidget {
  const _NewRemittanceButton();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final created = await context.push<Remittance>(Routes.newRemittance);
        if (created != null && context.mounted) await context.read<AssignedCubit>().load();
      },
      icon: const Icon(Icons.add),
      label: const Text(CourierTexts.newRemittance),
    );
  }
}

class _SortSelector extends StatelessWidget {
  const _SortSelector({required this.sort, required this.onChanged, this.showCompleted, this.onShowCompleted});

  final AssignedSort sort;
  final ValueChanged<AssignedSort> onChanged;

  /// Whether the completed ones are shown; null hides the option (the courier).
  final bool? showCompleted;
  final ValueChanged<bool>? onShowCompleted;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (option, label) in const [
          (AssignedSort.byDay, CourierTexts.sortByDay),
          (AssignedSort.mostLate, CourierTexts.sortMostLate),
        ])
          ChoiceChip(label: Text(label), selected: sort == option, onSelected: (_) => onChanged(option)),
        if (showCompleted case final shown?)
          FilterChip(
            label: const Text(CourierTexts.showCompleted),
            selected: shown,
            onSelected: (selected) => onShowCompleted?.call(selected),
          ),
      ],
    );
  }
}

/// Swipe right to complete, left to report an incident; each asks in a dialog first
/// and the card stays in place until the list reloads.
class _Swipeable extends StatelessWidget {
  const _Swipeable({required this.remittance, required this.child});

  final Remittance remittance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canComplete = context.canDo(Permissions.remittancesDeliver);
    final canReportIncident = context.canDo(Permissions.remittancesReportIncident);
    final direction = switch ((canComplete, canReportIncident)) {
      // A completed one has nothing left to do from the list.
      _ when remittance.isCompleted => DismissDirection.none,
      (true, true) => DismissDirection.horizontal,
      (true, false) => DismissDirection.startToEnd,
      (false, true) => DismissDirection.endToStart,
      (false, false) => DismissDirection.none,
    };
    final cubit = context.read<AssignedCubit>();
    final messenger = ScaffoldMessenger.of(context);

    Future<bool> act(DismissDirection direction) async {
      final ActionOutcome outcome;
      final String done;
      if (direction == DismissDirection.startToEnd) {
        final input = await showCompleteDialog(context, isPickup: remittance.isPickup);
        if (input == null) return false;
        outcome = await cubit.complete(remittance, pin: input.pin, note: input.note);
        done = CourierTexts.completed;
      } else {
        if (!context.mounted) return false;
        final input = await showIncidentDialog(context, isPickup: remittance.isPickup);
        if (input == null) return false;
        outcome = await cubit.reportIncident(remittance, reason: input.reason, note: input.note);
        done = CoreTexts.incidentReported;
      }
      messenger.showSnackBar(SnackBar(content: Text(CourierTexts.outcome(outcome, done: done))));
      // Never dismissed here: the reload takes the remittance out of the list.
      return false;
    }

    return Dismissible(
      key: ValueKey(remittance.id),
      direction: direction,
      confirmDismiss: act,
      background: _SwipeBackground(
        color: remittance.type.color,
        icon: Icons.check_circle_outline,
        label: remittance.isPickup ? CourierTexts.markCollected : CourierTexts.markDelivered,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: OttosColors.danger,
        icon: Icons.report_outlined,
        label: remittance.isPickup ? CoreTexts.reportIncidentPickup : CoreTexts.reportIncident,
        alignment: Alignment.centerRight,
      ),
      child: child,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.color, required this.icon, required this.label, required this.alignment});

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final content = [
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ];
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft ? content : content.reversed.toList(),
      ),
    );
  }
}

class _AssignedCard extends StatelessWidget {
  const _AssignedCard({required this.remittance, required this.onTap, this.unsent = false});

  final Remittance remittance;
  final VoidCallback onTap;

  /// An action on it waits for network.
  final bool unsent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final type = remittance.type;
    final action = remittance.isPickup ? CourierTexts.toCollect : CourierTexts.toDeliver;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The type's color down the side tells deliveries and pickups apart at a glance.
              Container(width: 6, color: type.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(remittance.code, style: textTheme.titleMedium)),
                          RemittanceStatusChip(remittance: remittance),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          RemittanceTypeBadge(type: type),
                          if (remittance.incident case final incident?) IncidentBadge(incident: incident),
                          if (unsent) const _UnsentBadge(),
                          if (remittance.review != null) const ReviewBadge(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(remittance.beneficiaryName ?? '', style: textTheme.titleSmall),
                      // The address already ends with the municipality and province.
                      Text(
                        remittance.beneficiaryAddress ?? remittance.municipalityName ?? '',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(type.icon, size: 20, color: type.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$action: ${Formatters.money(remittance.cashAmount, remittance.cashCurrency)}',
                              style: textTheme.titleSmall?.copyWith(color: type.color, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            switch (remittance.daysLate()) {
                              _ when remittance.isCompleted => CourierTexts.completedOn(
                                Formatters.date(remittance.completedAt),
                              ),
                              0 => CourierTexts.dueOn(Formatters.date(remittance.expectedDate)),
                              final days => CourierTexts.daysLate(days),
                            },
                            style: textTheme.bodySmall?.copyWith(
                              color: remittance.late && !remittance.isCompleted ? OttosColors.danger : null,
                              fontWeight: remittance.late && !remittance.isCompleted ? FontWeight.w600 : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An action on the remittance waits for network to reach the server.
class _UnsentBadge extends StatelessWidget {
  const _UnsentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: OttosColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 16, color: OttosColors.warning),
          SizedBox(width: 6),
          Text(
            CourierTexts.unsent,
            style: TextStyle(color: OttosColors.warning, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
