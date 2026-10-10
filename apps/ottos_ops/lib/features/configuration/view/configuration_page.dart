import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../cubit/configuration_cubit.dart';
import 'rate_dialogs.dart';

class ConfigurationPage extends StatelessWidget {
  const ConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ConfigurationCubit(rates: context.read<RateRepository>())..load(),
      child: BlocBuilder<ConfigurationCubit, ConfigurationState>(
        builder: (context, state) => switch (state.status) {
          ConfigurationStatus.loading => const LoadingView(),
          ConfigurationStatus.failure => ErrorView(
            message: state.error!,
            onRetry: context.read<ConfigurationCubit>().load,
          ),
          ConfigurationStatus.success => _ConfigurationView(state: state),
        },
      ),
    );
  }
}

class _ConfigurationView extends StatelessWidget {
  const _ConfigurationView({required this.state});

  final ConfigurationState state;

  @override
  Widget build(BuildContext context) {
    final canQuote = context.select((AuthBloc bloc) => bloc.state.user!.can(Permissions.ratesRead));
    final quotable = state.corridors.where((corridor) => corridor.canQuote).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(OpsTexts.configuration, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        _SettingsCard(settings: state.settings),
        if (canQuote && quotable.isNotEmpty) _Calculator(corridors: quotable),
        for (final corridor in state.corridors) _CorridorCard(corridor: corridor),
      ],
    );
  }
}

/// Business-wide settings: minimum amount and days to deliver.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final canWrite = context.select((AuthBloc bloc) => bloc.state.user!.can(Permissions.configurationWrite));
    final cubit = context.read<ConfigurationCubit>();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              OpsTexts.generalSettings,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            InfoRow(
              label: OpsTexts.minimumAmount,
              value: settings.minimumAmount <= 0
                  ? OpsTexts.noMinimum
                  : Formatters.money(settings.minimumAmount, settings.minimumAmountCurrency),
            ),
            InfoRow(label: OpsTexts.deliveryDays, value: OpsTexts.deliveryDaysValue(settings.defaultDeliveryDays)),
            if (canWrite) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  if (await showSettingsDialog(context, settings) == null || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(OpsTexts.settingsSaved)));
                  await cubit.load();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text(OpsTexts.edit),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quick quote, to answer a customer without starting a remittance.
class _Calculator extends StatefulWidget {
  const _Calculator({required this.corridors});

  final List<Corridor> corridors;

  @override
  State<_Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<_Calculator> {
  final _amount = TextEditingController();
  late Corridor _corridor = widget.corridors.firstWhere(
    (corridor) => corridor.targetCurrency == 'CUP',
    orElse: () => widget.corridors.first,
  );
  Future<Quote>? _quote;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    setState(() {
      _quote = amount == null || amount <= 0
          ? null
          : context.read<RateRepository>().quote(
              sourceCurrency: _corridor.sourceCurrency,
              targetCurrency: _corridor.targetCurrency,
              amount: amount,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              OpsTexts.calculator,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                    decoration: InputDecoration(labelText: OpsTexts.amountToSend, suffixText: _corridor.sourceCurrency),
                    onSubmitted: (_) => _calculate(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<Corridor>(
                    initialValue: _corridor,
                    decoration: const InputDecoration(labelText: OpsTexts.targetCurrency),
                    items: [
                      for (final corridor in widget.corridors)
                        DropdownMenuItem(value: corridor, child: Text(corridor.targetCurrency)),
                    ],
                    onChanged: (corridor) {
                      _corridor = corridor!;
                      _calculate();
                    },
                  ),
                ),
                FilledButton.tonal(onPressed: _calculate, child: const Text(OpsTexts.calculate)),
              ],
            ),
            if (_quote != null) ...[
              const SizedBox(height: 16),
              FutureBuilder<Quote>(
                future: _quote,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return Text(
                      error is ApiException ? error.message : CoreTexts.unexpectedError,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }
                  final quote = snapshot.data;
                  if (quote == null) return const LinearProgressIndicator();
                  return Wrap(
                    spacing: 32,
                    runSpacing: 8,
                    children: [
                      _Figure(label: OpsTexts.fee, value: Formatters.money(quote.fee, quote.sourceCurrency)),
                      _Figure(label: OpsTexts.total, value: Formatters.money(quote.total, quote.sourceCurrency)),
                      _Figure(
                        label: OpsTexts.amountToDeliver,
                        value: Formatters.money(quote.amountToDeliver, quote.targetCurrency),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        Text(value, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CorridorCard extends StatelessWidget {
  const _CorridorCard({required this.corridor});

  final Corridor corridor;

  @override
  Widget build(BuildContext context) {
    final canWrite = context.select((AuthBloc bloc) => bloc.state.user!.can(Permissions.configurationWrite));
    final cubit = context.read<ConfigurationCubit>();
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final rate = corridor.rate;
    final feeRule = corridor.feeRule;

    Future<void> change(Future<Object?> Function() dialog, String message) async {
      if (await dialog() == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await cubit.load();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${corridor.sourceCurrency} → ${corridor.targetCurrency}',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (!corridor.active) const Chip(label: Text(OpsTexts.inactive)),
              ],
            ),
            const SizedBox(height: 12),
            InfoRow(
              label: OpsTexts.rate,
              value: corridor.hasFixedRate
                  ? OpsTexts.fixedRate
                  : rate == null
                  ? OpsTexts.noRate
                  : OpsTexts.rateValue(rate.rate, corridor, rate.validFrom),
            ),
            InfoRow(
              label: OpsTexts.fee,
              value: feeRule == null ? OpsTexts.noFeeRule : OpsTexts.describeFee(feeRule, corridor.sourceCurrency),
            ),
            if (corridor.deliveryRounding != null && corridor.deliveryRounding! > 0.01)
              InfoRow(
                label: OpsTexts.rounding,
                value: OpsTexts.roundingValue(Formatters.money(corridor.deliveryRounding, corridor.targetCurrency)),
              ),
            if (rate == null && !corridor.hasFixedRate)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(OpsTexts.noRateWarning, style: TextStyle(color: colors.error)),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (canWrite && !corridor.hasFixedRate)
                  FilledButton.tonalIcon(
                    onPressed: () => change(() => showNewRateDialog(context, corridor), OpsTexts.rateSaved),
                    icon: const Icon(Icons.currency_exchange),
                    label: const Text(OpsTexts.newRate),
                  ),
                if (canWrite)
                  OutlinedButton.icon(
                    onPressed: () => change(() => showNewFeeRuleDialog(context, corridor), OpsTexts.feeRuleSaved),
                    icon: const Icon(Icons.percent),
                    label: const Text(OpsTexts.newFeeRule),
                  ),
              ],
            ),
            _History(
              // A new key reloads the history after a change.
              key: ValueKey('${corridor.code}-${rate?.id}-${feeRule?.id}'),
              corridor: corridor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Past rates and fee rules of a corridor, loaded when opened.
class _History extends StatefulWidget {
  const _History({super.key, required this.corridor});

  final Corridor corridor;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  Future<(List<ExchangeRate>, List<FeeRule>)>? _history;

  void _load() {
    final rates = context.read<RateRepository>();
    final code = widget.corridor.code;
    setState(() => _history = (rates.rateHistory(code), rates.feeRuleHistory(code)).wait);
  }

  @override
  Widget build(BuildContext context) {
    final corridor = widget.corridor;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(OpsTexts.history),
      onExpansionChanged: (open) {
        if (open && _history == null) _load();
      },
      children: [
        FutureBuilder<(List<ExchangeRate>, List<FeeRule>)>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text(CoreTexts.unexpectedError);
            final history = snapshot.data;
            if (history == null) return const LinearProgressIndicator();
            final (rates, feeRules) = history;
            return LayoutBuilder(
              builder: (context, constraints) {
                final rateList = _HistoryList(
                  title: OpsTexts.rateHistory,
                  lines: [
                    for (final rate in rates)
                      (Formatters.dateTime(rate.validFrom), OpsTexts.rateValue(rate.rate, corridor, null)),
                  ],
                );
                final feeList = _HistoryList(
                  title: OpsTexts.feeHistory,
                  lines: [
                    for (final rule in feeRules)
                      (Formatters.dateTime(rule.validFrom), OpsTexts.describeFee(rule, corridor.sourceCurrency)),
                  ],
                );
                if (constraints.maxWidth < 700) return Column(children: [rateList, feeList]);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: rateList),
                    const SizedBox(width: 24),
                    Expanded(child: feeList),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.title, required this.lines});

  final String title;
  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        if (lines.isEmpty) const Text(OpsTexts.noHistory),
        for (final (date, value) in lines) InfoRow(label: date, value: value, labelWidth: 160),
      ],
    );
  }
}
