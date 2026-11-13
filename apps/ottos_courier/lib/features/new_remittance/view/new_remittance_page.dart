import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';
import '../../../app/phone_contacts.dart';
import '../../../app/share_remittance.dart';

/// Registers a remittance from the phone; whoever can assign also picks the
/// courier. Closes with the remittance registered. New senders and
/// beneficiaries can take their name and phone from [pickContact].
class NewRemittancePage extends StatelessWidget {
  const NewRemittancePage({super.key, this.pickContact = pickPhoneContact});

  final ContactPicker pickContact;

  @override
  Widget build(BuildContext context) {
    final canAssign = context.canDo(Permissions.remittancesAssign);
    return RepositoryProvider<ContactPicker>.value(
      value: pickContact,
      child: BlocProvider(
        create: (context) => NewRemittanceCubit(
          remittances: context.read<RemittanceRepository>(),
          customers: context.read<CustomerRepository>(),
          rates: context.read<RateRepository>(),
        )..load(canAssign: canAssign),
        child: BlocConsumer<NewRemittanceCubit, NewRemittanceState>(
          listenWhen: (previous, current) => previous.created == null && current.created != null,
          listener: (context, state) {
            final created = state.created!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.error ?? CourierTexts.registered(remittanceLabel(created.beneficiaryName, created.code)),
                ),
                // It goes by itself, as before: the detail offers «Compartir» too.
                persist: false,
                duration: const Duration(seconds: 8),
                // read, not canDo: select only works while building.
                action: (context.read<AuthBloc>().state.user?.can(Permissions.remittancesShare) ?? false)
                    ? SnackBarAction(label: CoreTexts.share, onPressed: () => shareRemittance(created))
                    : null,
              ),
            );
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
    final pickContact = context.read<ContactPicker>();
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
            NewRemittanceCustomerField(
              customer: state.customer,
              enabled: enabled,
              forCourierApp: true,
              pickContact: pickContact,
            ),
            const SizedBox(height: 16),
            NewRemittanceBeneficiaryField(state: state, forCourierApp: true, pickContact: pickContact),
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
                    decoration: InputDecoration(
                      labelText: state.type == RemittanceType.pickup
                          ? CourierTexts.amountToCollect
                          : CourierTexts.amountToSend,
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
            PickupFeeField(state: state),
            OnTheHouseField(state: state),
            NewRemittanceQuoteSummary(state: state, forCourierApp: true),
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
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: state.onTheHouse ? OttosColors.onTheHouse : null,
                foregroundColor: state.onTheHouse ? Colors.white : null,
              ),
              onPressed: state.canSubmit ? () => cubit.submit(notes: _notes.text) : null,
              child: state.submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(state.onTheHouse ? CoreTexts.registerOnTheHouse : CourierTexts.register),
            ),
          ],
        );
      },
    );
  }
}
