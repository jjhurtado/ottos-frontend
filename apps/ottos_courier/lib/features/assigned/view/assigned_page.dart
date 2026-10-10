import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';
import '../../../app/router.dart';
import '../cubit/assigned_cubit.dart';

class AssignedPage extends StatelessWidget {
  const AssignedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AssignedCubit(remittances: context.read<RemittanceRepository>())..load(),
      child: const _AssignedView(),
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
        if (state.items.isEmpty) {
          return switch (state.status) {
            AssignedStatus.loading => const LoadingView(),
            AssignedStatus.failure => ErrorView(message: state.error!, onRetry: cubit.load),
            AssignedStatus.success => RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                children: const [SizedBox(height: 200, child: EmptyView(message: CourierTexts.noAssigned))],
              ),
            ),
          };
        }
        return RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: state.items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) return _SortSelector(sort: state.sort, onChanged: cubit.sortBy);
              final remittance = state.items[index - 1];
              return _Swipeable(
                remittance: remittance,
                child: _AssignedCard(
                  remittance: remittance,
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

class _SortSelector extends StatelessWidget {
  const _SortSelector({required this.sort, required this.onChanged});

  final AssignedSort sort;
  final ValueChanged<AssignedSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final (option, label) in const [
          (AssignedSort.byDay, CourierTexts.sortByDay),
          (AssignedSort.mostLate, CourierTexts.sortMostLate),
        ])
          ChoiceChip(label: Text(label), selected: sort == option, onSelected: (_) => onChanged(option)),
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
    final user = context.select((AuthBloc bloc) => bloc.state.user!);
    final canComplete = user.can(Permissions.remittancesDeliver);
    final canReportIncident = user.can(Permissions.remittancesReportIncident);
    final direction = switch ((canComplete, canReportIncident)) {
      (true, true) => DismissDirection.horizontal,
      (true, false) => DismissDirection.startToEnd,
      (false, true) => DismissDirection.endToStart,
      (false, false) => DismissDirection.none,
    };
    final cubit = context.read<AssignedCubit>();
    final messenger = ScaffoldMessenger.of(context);

    Future<bool> act(DismissDirection direction) async {
      final String? error;
      final String done;
      if (direction == DismissDirection.startToEnd) {
        final input = await showCompleteDialog(context, isPickup: remittance.isPickup);
        if (input == null) return false;
        error = await cubit.complete(remittance, pin: input.pin, note: input.note);
        done = CourierTexts.completed;
      } else {
        if (!context.mounted) return false;
        final input = await showIncidentDialog(context, isPickup: remittance.isPickup);
        if (input == null) return false;
        error = await cubit.reportIncident(remittance, reason: input.reason, note: input.note);
        done = CoreTexts.incidentReported;
      }
      messenger.showSnackBar(SnackBar(content: Text(error ?? done)));
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
  const _AssignedCard({required this.remittance, required this.onTap});

  final Remittance remittance;
  final VoidCallback onTap;

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
                              0 => CourierTexts.dueOn(Formatters.date(remittance.expectedDate)),
                              final days => CourierTexts.daysLate(days),
                            },
                            style: textTheme.bodySmall?.copyWith(
                              color: remittance.late ? OttosColors.danger : null,
                              fontWeight: remittance.late ? FontWeight.w600 : null,
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
