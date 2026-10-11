import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';

/// Registers a remittance from the phone; whoever can assign also picks the
/// courier. Closes with the remittance registered.
class NewRemittancePage extends StatelessWidget {
  const NewRemittancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final canAssign = context.canDo(Permissions.remittancesAssign);
    return BlocProvider(
      create: (context) => NewRemittanceCubit(
        remittances: context.read<RemittanceRepository>(),
        customers: context.read<CustomerRepository>(),
        rates: context.read<RateRepository>(),
      )..load(canAssign: canAssign),
      child: BlocConsumer<NewRemittanceCubit, NewRemittanceState>(
        listenWhen: (previous, current) => previous.created == null && current.created != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error ?? CourierTexts.registered(state.created!.code))));
          Navigator.of(context).pop(state.created);
        },
        buildWhen: (previous, current) => previous.corridorsStatus != current.corridorsStatus,
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text(CourierTexts.newRemittance)),
          body: switch (state.corridorsStatus) {
            LoadStatus.loading => const LoadingView(),
            LoadStatus.failure => ErrorView(
              message: state.error!,
              onRetry: () => context.read<NewRemittanceCubit>().load(canAssign: canAssign),
            ),
            LoadStatus.success => const _Form(),
          },
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewRemittanceCubit>();
    return BlocBuilder<NewRemittanceCubit, NewRemittanceState>(
      builder: (context, state) {
        final enabled = !state.submitting;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<RemittanceType>(
              segments: [
                for (final type in RemittanceType.values)
                  ButtonSegment(
                    value: type,
                    icon: Icon(type.icon),
                    label: Text(type == RemittanceType.pickup ? CoreTexts.pickup : CoreTexts.delivery),
                  ),
              ],
              selected: {state.type},
              onSelectionChanged: enabled ? (types) => cubit.typeChanged(types.single) : null,
            ),
            const SizedBox(height: 20),
            _CustomerField(customer: state.customer, enabled: enabled),
            const SizedBox(height: 16),
            _BeneficiaryField(state: state),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                    decoration: const InputDecoration(
                      labelText: CourierTexts.amountToSend,
                      suffixText: NewRemittanceCubit.sourceCurrency,
                    ),
                    onChanged: (text) => cubit.amountChanged(double.tryParse(text.replaceAll(',', '.'))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    // Pickups and deliveries offer their own currencies.
                    key: ValueKey(state.type),
                    initialValue: state.targetCurrency,
                    decoration: const InputDecoration(labelText: CourierTexts.targetCurrency),
                    items: [
                      for (final currency in state.targetCurrencies)
                        DropdownMenuItem(value: currency, child: Text(currency)),
                    ],
                    onChanged: enabled ? cubit.targetCurrencyChanged : null,
                  ),
                ),
              ],
            ),
            if (state.targetCurrencies.isEmpty) ...[
              const SizedBox(height: 8),
              Text(CourierTexts.noRates, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            PickupRateField(state: state),
            _QuoteSummary(state: state),
            if (state.couriers.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<Courier?>(
                initialValue: state.courier,
                isExpanded: true,
                decoration: const InputDecoration(labelText: CourierTexts.courier),
                items: [
                  const DropdownMenuItem(value: null, child: Text(CourierTexts.noCourier)),
                  for (final courier in state.couriers)
                    DropdownMenuItem(
                      value: courier,
                      // The email tells apart couriers with the same name.
                      child: Text([courier.name, ?courier.email].join(' · '), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: enabled ? cubit.courierSelected : null,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              enabled: enabled,
              maxLines: 2,
              decoration: const InputDecoration(labelText: CourierTexts.notesOptional),
            ),
            if (state.error != null && state.quoteStatus != LoadStatus.failure) ...[
              const SizedBox(height: 16),
              Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: state.canSubmit ? () => cubit.submit(notes: _notes.text) : null,
              child: state.submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(CourierTexts.register),
            ),
          ],
        );
      },
    );
  }
}

/// Searches customers as the user types; shows the chosen one with a way to change it.
class _CustomerField extends StatelessWidget {
  const _CustomerField({required this.customer, required this.enabled});

  final Customer? customer;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewRemittanceCubit>();
    final selected = customer;
    if (selected != null) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: CourierTexts.customer),
        child: Row(
          children: [
            Expanded(child: Text('${selected.fullName} · ${selected.contactLine}')),
            IconButton(
              tooltip: CourierTexts.changeCustomer,
              onPressed: enabled ? () => cubit.customerSelected(null) : null,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }
    return Autocomplete<Customer>(
      displayStringForOption: (customer) => customer.fullName,
      optionsBuilder: (value) async {
        if (value.text.trim().length < 2) return const [];
        try {
          return await cubit.searchCustomers(value.text);
        } on ApiException {
          return const [];
        }
      },
      onSelected: cubit.customerSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        decoration: const InputDecoration(
          labelText: CourierTexts.customer,
          hintText: CourierTexts.searchCustomer,
          prefixIcon: Icon(Icons.search),
        ),
      ),
      // With the phone: two customers may share a name.
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 280, maxWidth: MediaQuery.sizeOf(context).width - 32),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final customer in options)
                  ListTile(
                    title: Text(customer.fullName),
                    subtitle: Text(customer.contactLine),
                    onTap: () => onSelected(customer),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BeneficiaryField extends StatelessWidget {
  const _BeneficiaryField({required this.state});

  final NewRemittanceState state;

  @override
  Widget build(BuildContext context) {
    if (state.customer == null) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: CourierTexts.beneficiary, enabled: false),
        child: Text(CourierTexts.chooseCustomerFirst),
      );
    }
    if (state.beneficiariesStatus == LoadStatus.loading) return const LinearProgressIndicator();
    final cubit = context.read<NewRemittanceCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.beneficiariesStatus == LoadStatus.success && state.beneficiaries.isEmpty)
          const InputDecorator(
            decoration: InputDecoration(labelText: CourierTexts.beneficiary),
            child: Text(CourierTexts.noBeneficiaries),
          )
        else
          _dropdown(context),
        // Beneficiaries loaded without a customer are linked by the remittance.
        TextButton.icon(
          onPressed: state.submitting
              ? null
              : () async {
                  final found = await showBeneficiarySearchDialog(context, search: cubit.searchBeneficiaries);
                  if (found != null) cubit.beneficiaryCreated(found);
                },
          icon: const Icon(Icons.person_search),
          label: const Text(CoreTexts.searchOtherBeneficiary),
        ),
      ],
    );
  }

  Widget _dropdown(BuildContext context) {
    return DropdownButtonFormField<Beneficiary>(
      key: ValueKey('${state.customer!.id}-${state.beneficiaries.length}'),
      initialValue: state.beneficiary,
      isExpanded: true,
      decoration: const InputDecoration(labelText: CourierTexts.beneficiary),
      items: [
        for (final beneficiary in state.beneficiaries)
          DropdownMenuItem(
            value: beneficiary,
            child: Text('${beneficiary.fullName} · ${beneficiary.address}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: state.submitting ? null : context.read<NewRemittanceCubit>().beneficiarySelected,
    );
  }
}

class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.state});

  final NewRemittanceState state;

  @override
  Widget build(BuildContext context) {
    final quote = state.quote;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: switch (state.quoteStatus) {
        LoadStatus.loading => const Center(child: CircularProgressIndicator()),
        LoadStatus.failure => Text(state.error ?? CoreTexts.unexpectedError, style: TextStyle(color: colors.error)),
        LoadStatus.success when quote == null => const Text(CourierTexts.quoteHint),
        LoadStatus.success => Column(
          children: [
            InfoRow(label: CourierTexts.fee, value: Formatters.money(quote!.fee, quote.sourceCurrency)),
            InfoRow(label: CourierTexts.total, value: Formatters.money(quote.total, quote.sourceCurrency)),
            InfoRow(
              label: CourierTexts.rate,
              value: [
                Formatters.money(quote.rate, null),
                if (quote.rateOverridden) CoreTexts.rateTypedByHand,
              ].join(' · '),
            ),
            InfoRow(
              label: state.type == RemittanceType.pickup ? CourierTexts.cashToCollect : CourierTexts.amountToDeliver,
              value: Formatters.money(quote.amountToDeliver, quote.targetCurrency),
            ),
          ],
        ),
      },
    );
  }
}
