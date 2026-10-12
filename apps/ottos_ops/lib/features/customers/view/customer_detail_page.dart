import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/destinations.dart';
import '../../../app/ops_texts.dart';
import '../../../app/router.dart';
import '../cubit/customer_detail_cubit.dart';
import 'beneficiary_form_dialog.dart';
import 'customer_form_dialog.dart';

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final canReadRemittances = context.canDo(Permissions.remittancesRead);
    return BlocProvider(
      key: ValueKey(customerId),
      create: (context) => CustomerDetailCubit(
        customers: context.read<CustomerRepository>(),
        id: customerId,
        loadStats: canReadRemittances,
      )..load(),
      child: BlocConsumer<CustomerDetailCubit, CustomerDetailState>(
        listenWhen: (previous, current) => current.actionError != null,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.actionError!))),
        builder: (context, state) => switch (state.status) {
          CustomerDetailStatus.loading => const LoadingView(),
          CustomerDetailStatus.failure => ErrorView(
            message: state.error!,
            onRetry: context.read<CustomerDetailCubit>().load,
          ),
          CustomerDetailStatus.success => _CustomerDetailView(state: state),
        },
      ),
    );
  }
}

class _CustomerDetailView extends StatelessWidget {
  const _CustomerDetailView({required this.state});

  final CustomerDetailState state;

  @override
  Widget build(BuildContext context) {
    final customer = state.customer!;
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    // No user while logging out: the page goes before the redirect.
    if (user == null) return const SizedBox.shrink();
    final cubit = context.read<CustomerDetailCubit>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(Destinations.customers.path),
            icon: const Icon(Icons.arrow_back),
            label: const Text(OpsTexts.customers),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(customer.fullName, style: Theme.of(context).textTheme.headlineMedium),
            if (!customer.active) const Chip(label: Text(OpsTexts.inactive)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (user.can(Permissions.remittancesCreate) && customer.active)
              FilledButton.icon(
                onPressed: () => context.go(Routes.newRemittanceFor(customer.id)),
                icon: const Icon(Icons.add),
                label: const Text(OpsTexts.newRemittance),
              ),
            if (user.can(Permissions.customersWrite))
              OutlinedButton.icon(
                onPressed: () async {
                  final saved = await showCustomerFormDialog(context, customer: customer);
                  if (saved != null) cubit.customerSaved(saved);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text(OpsTexts.edit),
              ),
            if (user.can(Permissions.remittancesRead))
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.remittancesOf(customer.id)),
                icon: const Icon(Icons.list_alt),
                label: const Text(OpsTexts.viewRemittances),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final details = _DetailsCard(customer: customer, stats: state.stats);
            final beneficiaries = _BeneficiariesCard(state: state, canWrite: user.can(Permissions.customersWrite));
            if (constraints.maxWidth < 900) return Column(children: [details, beneficiaries]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: details),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: beneficiaries),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.customer, required this.stats});

  final Customer customer;
  final CustomerStats? stats;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats;
    return Column(
      children: [
        _Section(
          title: OpsTexts.customerData,
          children: [
            InfoRow(label: OpsTexts.phone, value: customer.phone),
            InfoRow(label: OpsTexts.email, value: customer.email),
            InfoRow(
              label: OpsTexts.document,
              value: [customer.documentType, customer.documentNumber].whereType<String>().join(' '),
            ),
            InfoRow(label: OpsTexts.address, value: customer.address),
            InfoRow(label: OpsTexts.notes, value: customer.notes),
            InfoRow(label: OpsTexts.createdAt, value: Formatters.date(customer.createdAt)),
          ],
        ),
        if (stats != null)
          _Section(
            title: OpsTexts.remittances,
            children: [
              InfoRow(label: OpsTexts.totalRemittances, value: '${stats.remittances}'),
              InfoRow(label: OpsTexts.openRemittancesLabel, value: '${stats.open}'),
              if (stats.late > 0) InfoRow(label: OpsTexts.lateRemittances, value: '${stats.late}'),
              if (stats.deliveries > 0) ...[
                InfoRow(label: OpsTexts.amountSent, value: Formatters.money(stats.amountSent, 'USD')),
                InfoRow(label: OpsTexts.totalCharged, value: Formatters.money(stats.charged, 'USD')),
              ],
              if (stats.pickups > 0)
                InfoRow(label: OpsTexts.amountCollected, value: Formatters.money(stats.amountCollected, 'USD')),
              InfoRow(label: OpsTexts.lastRemittance, value: Formatters.date(stats.lastAt)),
            ],
          ),
      ],
    );
  }
}

class _BeneficiariesCard extends StatelessWidget {
  const _BeneficiariesCard({required this.state, required this.canWrite});

  final CustomerDetailState state;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerDetailCubit>();
    final customer = state.customer!;
    return _Section(
      title: OpsTexts.beneficiaries,
      action: canWrite
          ? TextButton.icon(
              onPressed: () async {
                final saved = await showBeneficiaryFormDialog(context, customerId: customer.id);
                if (saved != null) cubit.beneficiarySaved(saved);
              },
              icon: const Icon(Icons.add),
              label: const Text(OpsTexts.newBeneficiary),
            )
          : null,
      children: [
        if (state.beneficiaries.isEmpty) const Text(OpsTexts.noBeneficiaries),
        for (final beneficiary in state.beneficiaries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_pin_circle_outlined),
            title: Text(beneficiary.fullName),
            subtitle: Text([beneficiary.phone, beneficiary.address].where((part) => part.isNotEmpty).join(' · ')),
            trailing: canWrite
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: OpsTexts.edit,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final saved = await showBeneficiaryFormDialog(
                            context,
                            customerId: customer.id,
                            beneficiary: beneficiary,
                          );
                          if (saved != null) cubit.beneficiarySaved(saved);
                        },
                      ),
                      IconButton(
                        tooltip: OpsTexts.unlink,
                        icon: const Icon(Icons.link_off),
                        onPressed: () async {
                          if (await _confirmUnlink(context, beneficiary)) await cubit.unlink(beneficiary);
                        },
                      ),
                    ],
                  )
                : null,
          ),
      ],
    );
  }

  static Future<bool> _confirmUnlink(BuildContext context, Beneficiary beneficiary) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(OpsTexts.unlinkTitle),
          content: Text(OpsTexts.unlinkMessage(beneficiary.fullName)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(CoreTexts.cancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(OpsTexts.unlink)),
          ],
        ),
      ) ??
      false;
}
