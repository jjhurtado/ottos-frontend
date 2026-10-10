import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';

/// Asks for amount, currency and note, then runs [submit]; returns the movement
/// registered, or null if cancelled. Errors from the API stay in the dialog.
Future<CashMovement?> showCashOperationDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required List<String> currencies,
  required Future<CashMovement> Function(CashInput input) submit,
  bool noteRequired = false,
  String? help,
}) {
  return showDialog<CashMovement>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CashOperationDialog(
      title: title,
      confirmLabel: confirmLabel,
      currencies: currencies,
      submit: submit,
      noteRequired: noteRequired,
      help: help,
    ),
  );
}

class _CashOperationDialog extends StatefulWidget {
  const _CashOperationDialog({
    required this.title,
    required this.confirmLabel,
    required this.currencies,
    required this.submit,
    required this.noteRequired,
    this.help,
  });

  final String title;
  final String confirmLabel;
  final List<String> currencies;
  final Future<CashMovement> Function(CashInput input) submit;
  final bool noteRequired;
  final String? help;

  @override
  State<_CashOperationDialog> createState() => _CashOperationDialogState();
}

class _CashOperationDialogState extends State<_CashOperationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _currency = widget.currencies.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  static double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final movement = await widget.submit(
        CashInput(amount: _parse(_amount.text)!, currency: _currency, note: _note.text),
      );
      if (mounted) Navigator.of(context).pop(movement);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
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
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.help != null) ...[Text(widget.help!), const SizedBox(height: 16)],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      enabled: !_saving,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                      decoration: const InputDecoration(labelText: '${OpsTexts.amount} *'),
                      validator: (text) => (_parse(text ?? '') ?? 0) > 0 ? null : OpsTexts.amountRequired,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: OpsTexts.currency),
                      items: [
                        for (final currency in widget.currencies)
                          DropdownMenuItem(value: currency, child: Text(currency)),
                      ],
                      onChanged: _saving ? null : (currency) => setState(() => _currency = currency!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                enabled: !_saving,
                maxLines: 2,
                decoration: InputDecoration(labelText: widget.noteRequired ? '${CoreTexts.reason} *' : CoreTexts.note),
                validator: (text) => widget.noteRequired && (text ?? '').trim().isEmpty ? OpsTexts.requiredField : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
