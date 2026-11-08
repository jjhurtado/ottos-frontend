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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                OpsTexts.remittanceRegistered(remittanceLabel(state.created!.beneficiaryName, state.created!.code)),
              ),
            ),
          );
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
                      NewRemittanceCustomerField(customer: state.customer, enabled: !state.submitting),
                      const SizedBox(height: 16),
                      NewRemittanceBeneficiaryField(state: state),
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
                      NewRemittanceQuoteSummary(state: state),
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
                                ? FilledButton.styleFrom(
                                    backgroundColor: OttosColors.onTheHouse,
                                    foregroundColor: Colors.white,
                                  )
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
