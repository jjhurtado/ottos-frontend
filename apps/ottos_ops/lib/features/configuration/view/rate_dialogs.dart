import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';

double? _parse(String? text) => double.tryParse((text ?? '').trim().replaceAll(',', '.'));

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,6}'));

/// Asks for a new exchange rate for [corridor] and saves it; returns it, or null if cancelled.
Future<ExchangeRate?> showNewRateDialog(BuildContext context, Corridor corridor) {
  final rates = context.read<RateRepository>();
  return showDialog<ExchangeRate>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SaveDialog<ExchangeRate>(
      title: OpsTexts.newRateTitle(corridor.code),
      help: OpsTexts.newRateHelp(corridor.sourceCurrency, corridor.targetCurrency),
      fieldsBuilder: (state) => [
        TextFormField(
          controller: state.controller('rate', corridor.currentRate == null ? '' : _plain(corridor.currentRate!)),
          enabled: !state.saving,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimal],
          decoration: InputDecoration(
            labelText: '${OpsTexts.rate} *',
            suffixText: '${corridor.targetCurrency} / 1 ${corridor.sourceCurrency}',
          ),
          validator: (text) => (_parse(text) ?? 0) > 0 ? null : OpsTexts.amountRequired,
        ),
      ],
      save: (state) => rates.setRate(corridor.code, _parse(state.text('rate'))!),
    ),
  );
}

/// Asks for a new fee rule for [corridor] and saves it; returns it, or null if cancelled.
Future<FeeRule?> showNewFeeRuleDialog(BuildContext context, Corridor corridor) {
  final rates = context.read<RateRepository>();
  final current = corridor.feeRule;
  var type = current?.type ?? FeeType.percentage;
  return showDialog<FeeRule>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SaveDialog<FeeRule>(
      title: OpsTexts.newFeeRuleTitle(corridor.code),
      help: OpsTexts.newFeeRuleHelp,
      fieldsBuilder: (state) => [
        SegmentedButton<FeeType>(
          segments: const [
            ButtonSegment(value: FeeType.percentage, label: Text(OpsTexts.feePercentage)),
            ButtonSegment(value: FeeType.fixed, label: Text(OpsTexts.feeFixed)),
          ],
          selected: {type},
          onSelectionChanged: state.saving ? null : (types) => state.update(() => type = types.single),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: state.controller('value', current == null ? '' : _plain(current.value)),
          enabled: !state.saving,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimal],
          decoration: InputDecoration(
            labelText: '${OpsTexts.feeValue} *',
            suffixText: type == FeeType.percentage ? '%' : corridor.sourceCurrency,
          ),
          validator: (text) {
            final value = _parse(text);
            if (value == null) return OpsTexts.requiredField;
            if (type == FeeType.percentage && value > 100) return CoreTexts.errorCodes['FEE_PERCENTAGE_TOO_HIGH'];
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: state.controller('min', current?.minFee == null ? '' : _plain(current!.minFee!)),
                enabled: !state.saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimal],
                decoration: InputDecoration(labelText: OpsTexts.minFee, suffixText: corridor.sourceCurrency),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: state.controller('max', current?.maxFee == null ? '' : _plain(current!.maxFee!)),
                enabled: !state.saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimal],
                decoration: InputDecoration(labelText: OpsTexts.maxFee, suffixText: corridor.sourceCurrency),
                validator: (text) {
                  final min = _parse(state.text('min'));
                  final max = _parse(text);
                  return min != null && max != null && min > max ? CoreTexts.errorCodes['INVALID_FEE_RANGE'] : null;
                },
              ),
            ),
          ],
        ),
      ],
      save: (state) => rates.setFeeRule(
        corridor.code,
        FeeRuleInput(
          type: type,
          value: _parse(state.text('value'))!,
          minFee: _parse(state.text('min')),
          maxFee: _parse(state.text('max')),
        ),
      ),
    ),
  );
}

/// Changes the business settings; returns them as saved, or null if cancelled.
Future<Settings?> showSettingsDialog(BuildContext context, Settings settings) {
  final rates = context.read<RateRepository>();
  return showDialog<Settings>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SaveDialog<Settings>(
      title: OpsTexts.generalSettings,
      fieldsBuilder: (state) => [
        TextFormField(
          controller: state.controller('minimum', _plain(settings.minimumAmount)),
          enabled: !state.saving,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
          decoration: InputDecoration(
            labelText: '${OpsTexts.minimumAmount} *',
            suffixText: settings.minimumAmountCurrency,
            helperText: OpsTexts.minimumAmountHint,
          ),
          validator: (text) => _parse(text) == null ? OpsTexts.requiredField : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: state.controller('days', '${settings.defaultDeliveryDays}'),
          enabled: !state.saving,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '${OpsTexts.deliveryDays} *',
            helperText: OpsTexts.deliveryDaysHint,
          ),
          validator: (text) {
            final days = int.tryParse(text ?? '');
            return days == null || days < 1 || days > 60 ? OpsTexts.deliveryDaysRange : null;
          },
        ),
      ],
      save: (state) => rates.updateSettings(
        minimumAmount: _parse(state.text('minimum')),
        defaultDeliveryDays: int.parse(state.text('days')),
      ),
    ),
  );
}

/// `410.0` → `410`, `0.1` → `0.1`: how a number is typed back into a field.
String _plain(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

/// A form dialog that saves through [save] and shows the API error inside it.
class _SaveDialog<T> extends StatefulWidget {
  const _SaveDialog({required this.title, required this.fieldsBuilder, required this.save, this.help});

  final String title;
  final String? help;
  final List<Widget> Function(_SaveDialogState<T> state) fieldsBuilder;
  final Future<T> Function(_SaveDialogState<T> state) save;

  @override
  State<_SaveDialog<T>> createState() => _SaveDialogState<T>();
}

class _SaveDialogState<T> extends State<_SaveDialog<T>> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  bool saving = false;
  String? _error;

  TextEditingController controller(String key, String initial) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  String text(String key) => _controllers[key]?.text ?? '';

  void update(VoidCallback change) => setState(change);

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      _error = null;
    });
    try {
      final saved = await widget.save(this);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.help != null) ...[Text(widget.help!), const SizedBox(height: 16)],
              ...widget.fieldsBuilder(this),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: saving ? null : _submit,
          child: saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(OpsTexts.save),
        ),
      ],
    );
  }
}
