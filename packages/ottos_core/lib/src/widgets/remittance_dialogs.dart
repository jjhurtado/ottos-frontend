import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/core_texts.dart';
import '../utils/formatters.dart';

typedef CompleteInput = ({String? pin, String? note});

/// Asks for the optional PIN and note before completing a remittance.
Future<CompleteInput?> showCompleteDialog(BuildContext context, {required bool isPickup}) {
  return showDialog<CompleteInput>(
    context: context,
    builder: (_) => _CompleteDialog(isPickup: isPickup),
  );
}

class _CompleteDialog extends StatefulWidget {
  const _CompleteDialog({required this.isPickup});

  final bool isPickup;

  @override
  State<_CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<_CompleteDialog> {
  final _pin = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isPickup ? CoreTexts.confirmCollection : CoreTexts.confirmDelivery),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: CoreTexts.pin,
              helperText: CoreTexts.pinHint,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: CoreTexts.note),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((pin: _pin.text.trim(), note: _emptyToNull(_note.text))),
          child: const Text(CoreTexts.confirm),
        ),
      ],
    );
  }

  static String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();
}

typedef PostponeInput = ({DateTime newDate, String reason});

/// Asks for the new date and the (required) reason to postpone.
Future<PostponeInput?> showPostponeDialog(BuildContext context, {DateTime? current}) {
  return showDialog<PostponeInput>(
    context: context,
    builder: (_) => _PostponeDialog(current: current),
  );
}

class _PostponeDialog extends StatefulWidget {
  const _PostponeDialog({this.current});

  final DateTime? current;

  @override
  State<_PostponeDialog> createState() => _PostponeDialogState();
}

class _PostponeDialogState extends State<_PostponeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late DateTime _date = _initialDate();

  DateTime _initialDate() {
    final tomorrow = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    final current = widget.current;
    if (current == null || !current.isAfter(tomorrow)) return tomorrow;
    return DateUtils.dateOnly(current).add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(CoreTexts.postponeTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text(CoreTexts.newDate),
              subtitle: Text(Formatters.date(_date)),
              onTap: _pickDate,
            ),
            TextFormField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(labelText: CoreTexts.reason),
              validator: (value) => (value ?? '').trim().isEmpty ? CoreTexts.reasonRequired : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop((newDate: _date, reason: _reason.text.trim()));
            }
          },
          child: const Text(CoreTexts.postpone),
        ),
      ],
    );
  }
}
