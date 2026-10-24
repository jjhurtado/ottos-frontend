import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/destinations.dart';
import '../../../app/ops_texts.dart';
import '../../../app/router.dart';

class NewRemittancePage extends StatelessWidget {
  const NewRemittancePage({super.key, this.initialCustomerId});

  /// Customer to start with, e.g. when coming from their page.
  final String? initialCustomerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NewRemittanceCubit(
        remittances: context.read<RemittanceRepository>(),
        customers: context.read<CustomerRepository>(),
        rates: context.read<RateRepository>(),
      )..load(customerId: initialCustomerId),
      child: BlocConsumer<NewRemittanceCubit, NewRemittanceState>(
        listenWhen: (previous, current) => previous.created == null && current.created != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(OpsTexts.remittanceRegistered(state.created!.code))));
          context.go(Routes.remittance(state.created!.id));
        },
        buildWhen: (previous, current) => previous.corridorsStatus != current.corridorsStatus,
        builder: (context, state) => switch (state.corridorsStatus) {
          LoadStatus.loading => const LoadingView(),
          LoadStatus.failure => ErrorView(message: state.error!, onRetry: context.read<NewRemittanceCubit>().load),
          LoadStatus.success => const _NewRemittanceView(),
        },
      ),
    );
  }
}

class _NewRemittanceView extends StatefulWidget {
  const _NewRemittanceView();

  @override
  State<_NewRemittanceView> createState() => _NewRemittanceViewState();
}

class _NewRemittanceViewState extends State<_NewRemittanceView> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewRemittanceCubit>();
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
        Text(OpsTexts.newRemittance, style: textTheme.headlineMedium),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: BlocBuilder<NewRemittanceCubit, NewRemittanceState>(
                  builder: (context, state) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<RemittanceType>(
                        segments: const [
                          ButtonSegment(value: RemittanceType.delivery, label: Text(CoreTexts.delivery)),
                          ButtonSegment(value: RemittanceType.pickup, label: Text(CoreTexts.pickup)),
                        ],
                        selected: {state.type},
                        onSelectionChanged: state.submitting ? null : (types) => cubit.typeChanged(types.single),
                      ),
                      const SizedBox(height: 20),
                      _CustomerField(customer: state.customer, enabled: !state.submitting),
                      const SizedBox(height: 16),
                      _BeneficiaryField(state: state),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              enabled: !state.submitting,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                              decoration: InputDecoration(
                                labelText: state.type == RemittanceType.pickup
                                    ? OpsTexts.amountToCollect
                                    : OpsTexts.amountToSend,
                                suffixText: NewRemittanceCubit.sourceCurrency,
                              ),
                              onChanged: (text) => cubit.amountChanged(double.tryParse(text.replaceAll(',', '.'))),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              // Pickups and deliveries offer their own currencies.
                              key: ValueKey(state.type),
                              initialValue: state.targetCurrency,
                              decoration: const InputDecoration(labelText: OpsTexts.targetCurrency),
                              items: [
                                for (final currency in state.targetCurrencies)
                                  DropdownMenuItem(value: currency, child: Text(currency)),
                              ],
                              onChanged: state.submitting ? null : cubit.targetCurrencyChanged,
                            ),
                          ),
                        ],
                      ),
                      if (state.targetCurrencies.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(OpsTexts.noRates, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      PickupRateField(state: state),
                      PickupFeeField(state: state),
                      OnTheHouseField(state: state),
                      _QuoteSummary(state: state),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notes,
                        enabled: !state.submitting,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: OpsTexts.notesOptional),
                      ),
                      if (state.error != null && state.quoteStatus != LoadStatus.failure) ...[
                        const SizedBox(height: 16),
                        Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: state.submitting ? null : () => context.go(Destinations.remittances.path),
                            child: const Text(CoreTexts.cancel),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            style: state.onTheHouse
                                ? FilledButton.styleFrom(backgroundColor: OttosColors.onTheHouse)
                                : null,
                            onPressed: state.canSubmit ? () => cubit.submit(notes: _notes.text) : null,
                            child: state.submitting
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(state.onTheHouse ? CoreTexts.registerOnTheHouse : OpsTexts.register),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
        decoration: const InputDecoration(labelText: OpsTexts.customer),
        child: Row(
          children: [
            Expanded(child: Text('${selected.fullName} · ${selected.contactLine}')),
            IconButton(
              tooltip: OpsTexts.changeCustomer,
              onPressed: enabled ? () => cubit.customerSelected(null) : null,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }
    final canCreate = context.canDo(Permissions.customersWrite);
    final search = Autocomplete<Customer>(
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
          labelText: OpsTexts.customer,
          hintText: OpsTexts.searchCustomer,
          prefixIcon: Icon(Icons.search),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 672),
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
    if (!canCreate) return search;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton.icon(
            onPressed: enabled
                ? () async {
                    final created = await showCustomerFormDialog(context);
                    if (created != null) await cubit.customerSelected(created);
                  }
                : null,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text(OpsTexts.newCustomer),
          ),
        ),
      ],
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
        decoration: InputDecoration(labelText: OpsTexts.beneficiary, enabled: false),
        child: Text(OpsTexts.chooseCustomerFirst),
      );
    }
    if (state.beneficiariesStatus == LoadStatus.loading) return const LinearProgressIndicator();
    final canCreate = context.canDo(Permissions.customersWrite);
    final field = state.beneficiariesStatus == LoadStatus.success && state.beneficiaries.isEmpty
        ? const InputDecorator(
            decoration: InputDecoration(labelText: OpsTexts.beneficiary),
            child: Text(OpsTexts.noBeneficiaries),
          )
        : _dropdown(context);
    final cubit = context.read<NewRemittanceCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
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
            if (canCreate)
              TextButton.icon(
                onPressed: state.submitting
                    ? null
                    : () async {
                        final created = await showBeneficiaryFormDialog(context, customerId: state.customer!.id);
                        if (created != null) cubit.beneficiaryCreated(created);
                      },
                icon: const Icon(Icons.add),
                label: const Text(OpsTexts.newBeneficiary),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dropdown(BuildContext context) {
    return DropdownButtonFormField<Beneficiary>(
      // Rebuilt when the list changes, so a new beneficiary shows as selected.
      key: ValueKey('${state.customer!.id}-${state.beneficiaries.length}'),
      initialValue: state.beneficiary,
      isExpanded: true,
      decoration: const InputDecoration(labelText: OpsTexts.beneficiary),
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
        LoadStatus.success when quote == null => Text(
          state.type == RemittanceType.pickup ? OpsTexts.pickupQuoteHint : OpsTexts.quoteHint,
        ),
        LoadStatus.success => Column(
          children: [
            // A pickup hands nothing over: the courier collects the amount and
            // the fee is the business's, so there is no total or amount to deliver.
            if (state.type == RemittanceType.pickup) ...[
              InfoRow(label: OpsTexts.cashToCollect, value: Formatters.money(quote!.amount, quote.sourceCurrency)),
              InfoRow(
                label: OpsTexts.fee,
                value: [
                  Formatters.money(quote.fee, quote.sourceCurrency),
                  if (quote.feeOverridden) CoreTexts.rateTypedByHand,
                ].join(' · '),
              ),
              InfoRow(
                label: OpsTexts.rate,
                value: [
                  Formatters.money(quote.rate, null),
                  if (quote.rateOverridden) CoreTexts.rateTypedByHand,
                  CoreTexts.rateInformative,
                ].join(' · '),
              ),
            ] else ...[
              InfoRow(
                label: OpsTexts.fee,
                value: [
                  Formatters.money(quote!.fee, quote.sourceCurrency),
                  if (quote.onTheHouse) CoreTexts.onTheHouse,
                ].join(' · '),
              ),
              if (quote.onTheHouse && quote.waivedFee != null)
                InfoRow(label: CoreTexts.waivedFee, value: Formatters.money(quote.waivedFee, quote.sourceCurrency)),
              InfoRow(label: OpsTexts.total, value: Formatters.money(quote.total, quote.sourceCurrency)),
              InfoRow(
                label: OpsTexts.rate,
                value: [
                  Formatters.money(quote.rate, null),
                  if (quote.rateOverridden) CoreTexts.rateTypedByHand,
                ].join(' · '),
              ),
              InfoRow(
                label: OpsTexts.amountToDeliver,
                value: Formatters.money(quote.amountToDeliver, quote.targetCurrency),
              ),
              if (state.onTheHouse && !quote.onTheHouse) ...[
                const SizedBox(height: 8),
                Text(CoreTexts.onTheHouseNotQuoted, style: TextStyle(color: colors.error)),
              ],
            ],
          ],
        ),
      },
    );
  }
}
