import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/destinations.dart';
import '../../../app/ops_texts.dart';
import '../cubit/remittance_detail_cubit.dart';

class RemittanceDetailPage extends StatelessWidget {
  const RemittanceDetailPage({super.key, required this.remittanceId});

  final String remittanceId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(remittanceId),
      create: (context) =>
          RemittanceDetailCubit(remittances: context.read<RemittanceRepository>(), id: remittanceId)..load(),
      child: BlocBuilder<RemittanceDetailCubit, RemittanceDetailState>(
        builder: (context, state) => switch (state.status) {
          RemittanceDetailStatus.loading => const LoadingView(),
          RemittanceDetailStatus.failure => ErrorView(
            message: state.error!,
            onRetry: context.read<RemittanceDetailCubit>().load,
          ),
          RemittanceDetailStatus.success => _RemittanceDetailView(state: state),
        },
      ),
    );
  }
}

class _RemittanceDetailView extends StatelessWidget {
  const _RemittanceDetailView({required this.state});

  final RemittanceDetailState state;

  @override
  Widget build(BuildContext context) {
    final remittance = state.remittance!;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(Destinations.remittances.path),
            icon: const Icon(Icons.arrow_back),
            label: const Text(OpsTexts.remittances),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${OpsTexts.remittance} ${remittance.code}', style: textTheme.headlineMedium),
            RemittanceStatusChip(remittance: remittance),
            Chip(label: Text(remittance.isPickup ? CoreTexts.pickup : CoreTexts.delivery)),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final summary = _SummaryCard(remittance: remittance);
            final money = _MoneyCard(remittance: remittance);
            final history = _HistoryCard(state: state);
            if (constraints.maxWidth < 900) {
              return Column(children: [summary, money, history]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: Column(children: [summary, money])),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: history),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.remittance});

  final Remittance remittance;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: OpsTexts.summary,
      children: [
        InfoRow(label: OpsTexts.customer, value: _join([remittance.customerName, remittance.customerPhone])),
        InfoRow(label: OpsTexts.beneficiary, value: remittance.beneficiaryName),
        InfoRow(label: OpsTexts.phone, value: remittance.beneficiaryPhone),
        InfoRow(label: OpsTexts.alternatePhone, value: remittance.beneficiaryAlternatePhone),
        InfoRow(label: OpsTexts.address, value: remittance.beneficiaryAddress),
        InfoRow(label: OpsTexts.municipality, value: remittance.municipalityName),
        InfoRow(label: OpsTexts.reference, value: remittance.beneficiaryReference),
        InfoRow(label: OpsTexts.courier, value: remittance.courierName ?? OpsTexts.noCourier),
        InfoRow(label: OpsTexts.expectedDate, value: Formatters.date(remittance.expectedDate)),
        if (remittance.postponements > 0) InfoRow(label: OpsTexts.postponements, value: '${remittance.postponements}'),
        InfoRow(label: OpsTexts.pin, value: remittance.pin),
        InfoRow(label: OpsTexts.notes, value: remittance.notes),
        InfoRow(label: OpsTexts.createdAt, value: Formatters.dateTime(remittance.createdAt)),
        InfoRow(label: OpsTexts.completedAt, value: Formatters.dateTime(remittance.completedAt)),
      ],
    );
  }

  static String _join(List<String?> parts) => parts.where((part) => part != null && part.isNotEmpty).join(' · ');
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.remittance});

  final Remittance remittance;

  @override
  Widget build(BuildContext context) {
    final source = remittance.sourceCurrency;
    return _Section(
      title: OpsTexts.money,
      children: [
        InfoRow(label: OpsTexts.amount, value: Formatters.money(remittance.amount, source)),
        InfoRow(label: OpsTexts.fee, value: Formatters.money(remittance.fee, source)),
        InfoRow(label: OpsTexts.total, value: Formatters.money(remittance.total, source)),
        InfoRow(label: OpsTexts.rate, value: Formatters.money(remittance.rate, null)),
        InfoRow(
          label: OpsTexts.amountToDeliver,
          value: Formatters.money(remittance.amountToDeliver, remittance.targetCurrency),
        ),
        if (remittance.isPickup)
          InfoRow(
            label: OpsTexts.cashToCollect,
            value: Formatters.money(remittance.cashAmount, remittance.cashCurrency),
          ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.state});

  final RemittanceDetailState state;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return _Section(
      title: OpsTexts.history,
      children: [
        if (state.events.isEmpty) const Text(OpsTexts.noHistory),
        for (final event in state.events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.circle, size: 12, color: OttosColors.teal),
            minLeadingWidth: 12,
            title: Text(OpsTexts.eventTitle(event.type)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.toStatus != null)
                  Text(
                    [
                      state.statusName(event.fromStatus),
                      state.statusName(event.toStatus),
                    ].where((name) => name.isNotEmpty).join(' → '),
                  ),
                if (event.newDate != null)
                  Text('${Formatters.date(event.previousDate)} → ${Formatters.date(event.newDate)}'),
                if (event.note != null && event.note!.isNotEmpty) Text(event.note!),
                Text(Formatters.dateTime(event.occurredAt), style: TextStyle(color: outline, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}
