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
            itemCount: state.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _AssignedCard(
              remittance: state.items[index],
              onTap: () async {
                // Reload on return: the remittance may have been completed or postponed.
                await context.push(Routes.remittance(state.items[index].id));
                await cubit.load();
              },
            ),
          ),
        );
      },
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
                            CourierTexts.dueOn(Formatters.date(remittance.expectedDate)),
                            style: textTheme.bodySmall?.copyWith(color: remittance.late ? OttosColors.danger : null),
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
