import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/core_texts.dart';
import '../models/exchange.dart';
import '../utils/formatters.dart';

/// Asks for a currency exchange: direction, amount, the rate obtained (CUP per
/// 1 USD, as it is quoted in Cuba) and a note. Shows what will be received
/// before confirming. Null if cancelled.
Future<ExchangeInput?> showExchangeDialog(BuildContext context, {String? title}) => showDialog<ExchangeInput>(
  context: context,
  builder: (_) => _ExchangeDialog(title: title),
);

class _ExchangeDialog extends StatefulWidget {
  const _ExchangeDialog({this.title});

  final String? title;

  @override
  State<_ExchangeDialog> createState() => _ExchangeDialogState();
}

class _ExchangeDialogState extends State<_ExchangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _note = TextEditingController();
  var _fromUsd = true;

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  static double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  String get _from => _fromUsd ? 'USD' : 'CUP';
  String get _to => _fromUsd ? 'CUP' : 'USD';

  ExchangeInput? get _input {
    final amount = _parse(_amount.text);
    final rate = _parse(_rate.text);
    if (amount == null || amount <= 0 || rate == null || rate <= 0) return null;
    return ExchangeInput(fromCurrency: _from, fromAmount: amount, toCurrency: _to, rate: rate, note: _note.text);
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    return AlertDialog(
      title: Text(widget.title ?? CoreTexts.exchangeTitle),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('USD → CUP')),
                    ButtonSegment(value: false, label: Text('CUP → USD')),
                  ],
                  selected: {_fromUsd},
                  onSelectionChanged: (selected) => setState(() => _fromUsd = selected.single),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                  decoration: InputDecoration(labelText: CoreTexts.exchangeAmount, suffixText: _from),
                  onChanged: (_) => setState(() {}),
                  validator: (text) => (_parse(text ?? '') ?? 0) > 0 ? null : CoreTexts.amountRequired,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,6}'))],
                  decoration: const InputDecoration(labelText: CoreTexts.exchangeRate, suffixText: 'CUP / 1 USD'),
                  onChanged: (_) => setState(() {}),
                  validator: (text) => (_parse(text ?? '') ?? 0) > 0 ? null : CoreTexts.errorCodes['INVALID_RATE'],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: CoreTexts.noteOptional),
                ),
                const SizedBox(height: 16),
                Text(
                  input == null
                      ? CoreTexts.exchangeHint
                      : CoreTexts.exchangeResult(
                          Formatters.money(input.fromAmount, _from),
                          Formatters.money(input.toAmount, _to),
                        ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.of(context).pop(_input);
          },
          child: const Text(CoreTexts.exchangeConfirm),
        ),
      ],
    );
  }
}
