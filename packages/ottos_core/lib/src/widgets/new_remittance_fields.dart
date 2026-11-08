import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_exception.dart';
import '../auth/can_do.dart';
import '../auth/permissions.dart';
import '../l10n/core_texts.dart';
import '../models/customer.dart';
import '../models/remittance.dart';
import '../remittances/new_remittance_cubit.dart';
import '../utils/formatters.dart';
import 'beneficiary_form_dialog.dart';
import 'beneficiary_search_dialog.dart';
import 'contact_picker_button.dart';
import 'customer_form_dialog.dart';
import 'info_row.dart';

// The sender, beneficiary and quote of a new remittance, under a
// [NewRemittanceCubit]. [forCourierApp] selects the courier app's layout AND its
// wording: the button goes under the field, the options are as wide as the
// screen, and «Busca por nombre o teléfono», «Nuevo remitente», «Total a cobrar»
// and «Se entrega». It is not about screen size: the panel on a phone keeps it false;
// [pickContact] fills new senders and beneficiaries from the phone's contacts.

/// Searches customers as the user types; shows the chosen one with a way to change it.
class NewRemittanceCustomerField extends StatelessWidget {
  const NewRemittanceCustomerField({
    super.key,
    required this.customer,
    required this.enabled,
    this.forCourierApp = false,
    this.pickContact,
  });

  final Customer? customer;
  final bool enabled;
  final bool forCourierApp;
  final ContactPicker? pickContact;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewRemittanceCubit>();
    final selected = customer;
    if (selected != null) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: CoreTexts.customer),
        child: Row(
          children: [
            Expanded(child: Text('${selected.fullName} · ${selected.contactLine}')),
            IconButton(
              tooltip: CoreTexts.changeCustomer,
              onPressed: enabled ? () => cubit.customerSelected(null) : null,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }
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
        decoration: InputDecoration(
          labelText: CoreTexts.customer,
          hintText: forCourierApp ? CoreTexts.searchCustomerApp : CoreTexts.searchCustomer,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      // With the phone: two customers may share a name.
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 280,
              maxWidth: forCourierApp ? MediaQuery.sizeOf(context).width - 32 : 672,
            ),
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
    if (!context.canDo(Permissions.customersWrite)) return search;
    final create = TextButton.icon(
      onPressed: enabled
          ? () async {
              final created = await showCustomerFormDialog(
                context,
                title: forCourierApp ? CoreTexts.newSender : null,
                pickContact: pickContact,
              );
              if (created != null) await cubit.customerSelected(created);
            }
          : null,
      icon: const Icon(Icons.person_add_alt_1),
      label: Text(forCourierApp ? CoreTexts.newSender : CoreTexts.newCustomer),
    );
    if (forCourierApp) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [search, create]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        Padding(padding: const EdgeInsets.only(top: 8), child: create),
      ],
    );
  }
}

/// The customer's beneficiaries, with buttons to find another one or create one.
class NewRemittanceBeneficiaryField extends StatelessWidget {
  const NewRemittanceBeneficiaryField({super.key, required this.state, this.forCourierApp = false, this.pickContact});

  final NewRemittanceState state;
  final bool forCourierApp;
  final ContactPicker? pickContact;

  @override
  Widget build(BuildContext context) {
    if (state.customer == null) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: CoreTexts.beneficiary, enabled: false),
        child: Text(CoreTexts.chooseCustomerFirst),
      );
    }
    if (state.beneficiariesStatus == LoadStatus.loading) return const LinearProgressIndicator();
    final cubit = context.read<NewRemittanceCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.beneficiariesStatus == LoadStatus.success && state.beneficiaries.isEmpty)
          const InputDecorator(
            decoration: InputDecoration(labelText: CoreTexts.beneficiary),
            child: Text(CoreTexts.noBeneficiaries),
          )
        else
          _dropdown(cubit),
        if (!forCourierApp) const SizedBox(height: 4),
        Wrap(
          spacing: forCourierApp ? 0 : 8,
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
            if (context.canDo(Permissions.customersWrite))
              TextButton.icon(
                onPressed: state.submitting
                    ? null
                    : () async {
                        final created = await showBeneficiaryFormDialog(
                          context,
                          customerId: state.customer!.id,
                          pickContact: pickContact,
                        );
                        if (created != null) cubit.beneficiaryCreated(created);
                      },
                icon: const Icon(Icons.add),
                label: const Text(CoreTexts.newBeneficiary),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dropdown(NewRemittanceCubit cubit) {
    return DropdownButtonFormField<Beneficiary>(
      // Rebuilt when the list changes, so a new beneficiary shows as selected.
      key: ValueKey('${state.customer!.id}-${state.beneficiaries.length}'),
      initialValue: state.beneficiary,
      isExpanded: true,
      decoration: const InputDecoration(labelText: CoreTexts.beneficiary),
      items: [
        for (final beneficiary in state.beneficiaries)
          DropdownMenuItem(
            value: beneficiary,
            child: Text('${beneficiary.fullName} · ${beneficiary.address}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: state.submitting ? null : cubit.beneficiarySelected,
    );
  }
}

/// The server's quote: fee, total, rate and what is delivered, or what a pickup collects.
class NewRemittanceQuoteSummary extends StatelessWidget {
  const NewRemittanceQuoteSummary({super.key, required this.state, this.forCourierApp = false});

  final NewRemittanceState state;
  final bool forCourierApp;

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
          state.type == RemittanceType.pickup ? CoreTexts.pickupQuoteHint : CoreTexts.quoteHint,
        ),
        LoadStatus.success => Column(
          children: [
            // A pickup hands nothing over: the courier collects the amount and
            // the fee is the business's, so there is no total or amount to deliver.
            if (state.type == RemittanceType.pickup) ...[
              InfoRow(label: CoreTexts.cashToCollect, value: Formatters.money(quote!.amount, quote.sourceCurrency)),
              InfoRow(
                label: CoreTexts.fee,
                value: [
                  Formatters.money(quote.fee, quote.sourceCurrency),
                  if (quote.feeOverridden) CoreTexts.rateTypedByHand,
                ].join(' · '),
              ),
              InfoRow(
                label: CoreTexts.rate,
                value: [
                  Formatters.money(quote.rate, null),
                  if (quote.rateOverridden) CoreTexts.rateTypedByHand,
                  CoreTexts.rateInformative,
                ].join(' · '),
              ),
            ] else ...[
              InfoRow(
                label: CoreTexts.fee,
                value: [
                  Formatters.money(quote!.fee, quote.sourceCurrency),
                  if (quote.onTheHouse) CoreTexts.onTheHouse,
                ].join(' · '),
              ),
              if (quote.onTheHouse && quote.waivedFee != null)
                InfoRow(label: CoreTexts.waivedFee, value: Formatters.money(quote.waivedFee, quote.sourceCurrency)),
              InfoRow(
                label: forCourierApp ? CoreTexts.quoteTotalApp : CoreTexts.quoteTotal,
                value: Formatters.money(quote.total, quote.sourceCurrency),
              ),
              InfoRow(
                label: CoreTexts.rate,
                value: [
                  Formatters.money(quote.rate, null),
                  if (quote.rateOverridden) CoreTexts.rateTypedByHand,
                ].join(' · '),
              ),
              InfoRow(
                label: forCourierApp ? CoreTexts.quoteToDeliverApp : CoreTexts.quoteToDeliver,
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
