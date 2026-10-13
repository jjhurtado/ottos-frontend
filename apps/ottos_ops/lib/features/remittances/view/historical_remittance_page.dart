import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/destinations.dart';
import '../../../app/ops_texts.dart';
import '../../../app/router.dart';
import '../cubit/historical_remittance_cubit.dart';

/// Types in an old remittance from its ticket (`remittances:historical`, admin):
/// completed on that date, with no courier, moving no cash. Opens it when done.
class HistoricalRemittancePage extends StatelessWidget {
  const HistoricalRemittancePage({super.key, this.now = DateTime.now});

  /// The clock that decides what is in the future; tests pass a fixed one.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HistoricalRemittanceCubit(
        remittances: context.read<RemittanceRepository>(),
        customers: context.read<CustomerRepository>(),
      ),
      child: BlocListener<HistoricalRemittanceCubit, HistoricalRemittanceState>(
        listenWhen: (previous, current) => previous.created == null && current.created != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(OpsTexts.historicalRegistered(state.created!.code))));
          context.go(Routes.remittance(state.created!.id));
        },
        child: _HistoricalForm(now: now),
      ),
    );
  }
}

class _HistoricalForm extends StatefulWidget {
  const _HistoricalForm({required this.now});

  final DateTime Function() now;

  @override
  State<_HistoricalForm> createState() => _HistoricalFormState();
}

class _HistoricalFormState extends State<_HistoricalForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _fee = TextEditingController(text: '0');
  final _rate = TextEditingController();
  final _toDeliver = TextEditingController();
  final _notes = TextEditingController();
  RemittanceType _type = RemittanceType.delivery;
  String _currency = 'USD';
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  bool _tried = false;

  @override
  void dispose() {
    for (final controller in [_amount, _fee, _rate, _toDeliver, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  static double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  bool get _inCup => _type == RemittanceType.delivery && _currency == 'CUP';

  DateTime? get _occurredAt {
    final date = _date;
    return date == null ? null : DateTime(date.year, date.month, date.day, _time.hour, _time.minute);
  }

  String? _dateError() {
    final occurredAt = _occurredAt;
    if (occurredAt == null) return CoreTexts.requiredField;
    return occurredAt.isAfter(widget.now()) ? OpsTexts.historicalFutureDate : null;
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(widget.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _submit(HistoricalRemittanceCubit cubit, HistoricalRemittanceState state) {
    setState(() => _tried = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || _dateError() != null || state.customer == null || state.beneficiary == null) return;
    cubit.submit(
      (customerId, beneficiaryId) => HistoricalRemittance(
        type: _type,
        customerId: customerId,
        beneficiaryId: beneficiaryId,
        occurredAt: _occurredAt!,
        amount: _parse(_amount.text)!,
        fee: _parse(_fee.text)!,
        targetCurrency: _inCup ? 'CUP' : 'USD',
        rate: _inCup ? _parse(_rate.text) : null,
        amountToDeliver: _inCup ? _parse(_toDeliver.text) : null,
        notes: _notes.text,
      ),
    );
  }

  String? Function(String?) _number({bool allowZero = false}) => (text) {
    final value = _parse(text ?? '');
    if ((text ?? '').trim().isEmpty) return CoreTexts.requiredField;
    if (value == null || value < 0 || (!allowZero && value == 0)) return OpsTexts.historicalInvalidNumber;
    return null;
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<HistoricalRemittanceCubit>();
    return BlocBuilder<HistoricalRemittanceCubit, HistoricalRemittanceState>(
      builder: (context, state) {
        final enabled = !state.submitting;
        final dateError = _tried ? _dateError() : null;
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
            Text(OpsTexts.historicalTitle, style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(OpsTexts.historicalHelp, style: textTheme.bodyMedium),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<RemittanceType>(
                            segments: const [
                              ButtonSegment(value: RemittanceType.delivery, label: Text(CoreTexts.delivery)),
                              ButtonSegment(value: RemittanceType.pickup, label: Text(CoreTexts.pickup)),
                            ],
                            selected: {_type},
                            onSelectionChanged: enabled ? (selected) => setState(() => _type = selected.first) : null,
                          ),
                          const SizedBox(height: 16),
                          _CustomerField(customer: state.customer, enabled: enabled),
                          const SizedBox(height: 16),
                          _BeneficiaryField(state: state, showError: _tried),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: enabled ? _pickDate : null,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: '${OpsTexts.historicalDate} *',
                                      errorText: dateError,
                                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                                    ),
                                    child: Text(_date == null ? OpsTexts.historicalPickDate : Formatters.date(_date)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 160,
                                child: InkWell(
                                  onTap: enabled ? _pickTime : null,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: OpsTexts.historicalTime,
                                      suffixIcon: Icon(Icons.schedule),
                                    ),
                                    child: Text(_time.format(context)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(OpsTexts.historicalCubaTime, style: textTheme.bodySmall),
                          const SizedBox(height: 16),
                          if (_type == RemittanceType.delivery)
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'USD', label: Text(OpsTexts.historicalDeliveredInUsd)),
                                ButtonSegment(value: 'CUP', label: Text(OpsTexts.historicalDeliveredInCup)),
                              ],
                              selected: {_currency},
                              onSelectionChanged: enabled
                                  ? (selected) => setState(() => _currency = selected.first)
                                  : null,
                            )
                          else
                            Text(OpsTexts.historicalPickupUsd, style: textTheme.bodySmall),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _amount,
                                  enabled: enabled,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText:
                                        '${_type == RemittanceType.pickup ? OpsTexts.historicalCollected : OpsTexts.historicalSent} *',
                                    suffixText: 'USD',
                                  ),
                                  validator: _number(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _fee,
                                  enabled: enabled,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: '${OpsTexts.historicalFee} *',
                                    suffixText: 'USD',
                                  ),
                                  validator: _number(allowZero: true),
                                ),
                              ),
                            ],
                          ),
                          if (_inCup) ...[
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _rate,
                                    enabled: enabled,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: '${OpsTexts.historicalRate} *',
                                      suffixText: 'CUP por USD',
                                    ),
                                    validator: _number(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _toDeliver,
                                    enabled: enabled,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: '${OpsTexts.historicalToDeliver} *',
                                      suffixText: 'CUP',
                                    ),
                                    validator: _number(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(OpsTexts.historicalCupHelp, style: textTheme.bodySmall),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notes,
                            enabled: enabled,
                            maxLines: 2,
                            maxLength: 1000,
                            decoration: const InputDecoration(labelText: OpsTexts.notesOptional),
                          ),
                          if (state.error case final error?) ...[
                            const SizedBox(height: 8),
                            Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: enabled ? () => context.go(Destinations.remittances.path) : null,
                                child: const Text(CoreTexts.cancel),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: enabled ? () => _submit(cubit, state) : null,
                                child: state.submitting
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text(OpsTexts.register),
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
      },
    );
  }
}

class _CustomerField extends StatelessWidget {
  const _CustomerField({required this.customer, required this.enabled});

  final Customer? customer;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HistoricalRemittanceCubit>();
    final selected = customer;
    if (selected != null) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: '${OpsTexts.customer} *'),
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
          labelText: '${OpsTexts.customer} *',
          hintText: OpsTexts.historicalCustomerHint,
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
  }
}

class _BeneficiaryField extends StatelessWidget {
  const _BeneficiaryField({required this.state, required this.showError});

  final HistoricalRemittanceState state;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HistoricalRemittanceCubit>();
    if (state.customer == null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: '${OpsTexts.beneficiary} *',
          enabled: false,
          errorText: showError ? CoreTexts.requiredField : null,
        ),
        child: const Text(OpsTexts.chooseCustomerFirst),
      );
    }
    if (state.beneficiariesStatus == LoadStatus.loading) return const LinearProgressIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.beneficiaries.isEmpty)
          InputDecorator(
            decoration: InputDecoration(
              labelText: '${OpsTexts.beneficiary} *',
              errorText: showError ? CoreTexts.requiredField : null,
            ),
            child: const Text(OpsTexts.noBeneficiaries),
          )
        else
          DropdownButtonFormField<Beneficiary>(
            key: ValueKey('${state.customer!.id}-${state.beneficiaries.length}-${state.beneficiary?.id}'),
            initialValue: state.beneficiary,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '${OpsTexts.beneficiary} *',
              errorText: showError && state.beneficiary == null ? CoreTexts.requiredField : null,
            ),
            items: [
              for (final beneficiary in state.beneficiaries)
                DropdownMenuItem(
                  value: beneficiary,
                  child: Text('${beneficiary.fullName} · ${beneficiary.address}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: state.submitting ? null : cubit.beneficiarySelected,
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: state.submitting
              ? null
              : () async {
                  final found = await showBeneficiarySearchDialog(context, search: cubit.searchBeneficiaries);
                  if (found != null) cubit.beneficiaryAdded(found);
                },
          icon: const Icon(Icons.person_search),
          label: const Text(CoreTexts.searchOtherBeneficiary),
        ),
      ],
    );
  }
}
