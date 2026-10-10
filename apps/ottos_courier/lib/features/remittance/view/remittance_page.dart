import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/courier_texts.dart';
import '../cubit/remittance_cubit.dart';

class RemittancePage extends StatelessWidget {
  const RemittancePage({super.key, required this.remittanceId});

  final String remittanceId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RemittanceCubit(remittances: context.read<RemittanceRepository>(), id: remittanceId)..load(),
      child: BlocConsumer<RemittanceCubit, RemittanceState>(
        listenWhen: (previous, current) => current.actionResult != RemittanceActionResult.none,
        listener: (context, state) {
          final message = switch (state.actionResult) {
            RemittanceActionResult.completed => CourierTexts.completed,
            RemittanceActionResult.postponed => CourierTexts.postponed,
            RemittanceActionResult.incidentReported => CoreTexts.incidentReported,
            RemittanceActionResult.failed => state.error!,
            RemittanceActionResult.none => null,
          };
          if (message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          // With the incident reported there is nothing left to do here for now:
          // back to the list, which puts it at the end.
          if (state.actionResult == RemittanceActionResult.incidentReported) Navigator.of(context).maybePop();
        },
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(state.remittance?.code ?? '')),
          body: switch (state.status) {
            RemittanceLoadStatus.loading => const LoadingView(),
            RemittanceLoadStatus.failure => ErrorView(
              message: state.error!,
              onRetry: context.read<RemittanceCubit>().load,
            ),
            RemittanceLoadStatus.success => _RemittanceView(remittance: state.remittance!),
          },
          bottomNavigationBar: state.remittance == null || state.remittance!.isCompleted
              ? null
              : _Actions(remittance: state.remittance!, submitting: state.submitting),
        ),
      ),
    );
  }
}

class _RemittanceView extends StatelessWidget {
  const _RemittanceView({required this.remittance});

  final Remittance remittance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final incident = remittance.incident;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (incident != null) ...[IncidentBanner(incident: incident), const SizedBox(height: 12)],
        Card(
          // Colored by type, as in the list: delivery and pickup never look alike.
          color: remittance.type.color,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RemittanceTypeBadge(type: remittance.type, onDark: true),
                const SizedBox(height: 12),
                Text(
                  remittance.isPickup ? CourierTexts.toCollect : CourierTexts.toDeliver,
                  style: textTheme.titleSmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.money(remittance.cashAmount, remittance.cashCurrency),
                  style: textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                RemittanceStatusChip(remittance: remittance, onDark: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoRow(label: CourierTexts.beneficiary, value: remittance.beneficiaryName, labelWidth: 110),
                _PhoneRow(label: CourierTexts.phone, phone: remittance.beneficiaryPhone),
                _PhoneRow(label: CourierTexts.alternatePhone, phone: remittance.beneficiaryAlternatePhone),
                InfoRow(label: CourierTexts.address, value: remittance.beneficiaryAddress, labelWidth: 110),
                InfoRow(label: CourierTexts.municipality, value: remittance.municipalityName, labelWidth: 110),
                InfoRow(label: CourierTexts.reference, value: remittance.beneficiaryReference, labelWidth: 110),
                InfoRow(
                  label: CourierTexts.expectedDate,
                  value: Formatters.date(remittance.expectedDate),
                  labelWidth: 110,
                ),
                InfoRow(label: CourierTexts.sender, value: remittance.customerName, labelWidth: 110),
                InfoRow(label: CourierTexts.notes, value: remittance.notes, labelWidth: 110),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.label, required this.phone});

  final String label;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final number = phone;
    if (number == null || number.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: InfoRow(label: label, value: number, labelWidth: 110),
        ),
        IconButton(
          tooltip: CourierTexts.whatsApp,
          icon: const Icon(Icons.chat_outlined, color: OttosColors.success),
          onPressed: () => launchUrl(Phones.whatsApp(number), mode: LaunchMode.externalApplication),
        ),
        IconButton(
          tooltip: CourierTexts.call,
          icon: const Icon(Icons.phone, color: OttosColors.teal),
          onPressed: () => launchUrl(Phones.call(number)),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.remittance, required this.submitting});

  final Remittance remittance;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user!);
    final cubit = context.read<RemittanceCubit>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (user.can(Permissions.remittancesPostpone)) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
                      onPressed: submitting
                          ? null
                          : () async {
                              final result = await showPostponeDialog(context, current: remittance.expectedDate);
                              if (result != null) await cubit.postpone(newDate: result.newDate, reason: result.reason);
                            },
                      child: const Text(CoreTexts.postpone),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (user.can(Permissions.remittancesDeliver))
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: remittance.type.color),
                      onPressed: submitting
                          ? null
                          : () async {
                              final result = await showCompleteDialog(context, isPickup: remittance.isPickup);
                              if (result != null) await cubit.complete(pin: result.pin, note: result.note);
                            },
                      child: submitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(remittance.isPickup ? CourierTexts.markCollected : CourierTexts.markDelivered),
                    ),
                  ),
              ],
            ),
            if (user.can(Permissions.remittancesReportIncident))
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: OttosColors.danger, minimumSize: const Size(64, 48)),
                onPressed: submitting
                    ? null
                    : () async {
                        final result = await showIncidentDialog(context, isPickup: remittance.isPickup);
                        if (result != null) await cubit.reportIncident(reason: result.reason, note: result.note);
                      },
                icon: const Icon(Icons.report_outlined),
                label: Text(remittance.isPickup ? CoreTexts.reportIncidentPickup : CoreTexts.reportIncident),
              ),
          ],
        ),
      ),
    );
  }
}
