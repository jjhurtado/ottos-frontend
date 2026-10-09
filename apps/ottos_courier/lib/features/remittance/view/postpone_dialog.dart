import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';

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
      title: const Text(CourierTexts.postponeTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text(CourierTexts.newDate),
              subtitle: Text(Formatters.date(_date)),
              onTap: _pickDate,
            ),
            TextFormField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(labelText: CourierTexts.reason),
              validator: (value) => (value ?? '').trim().isEmpty ? CourierTexts.reasonRequired : null,
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
          child: const Text(CourierTexts.postpone),
        ),
      ],
    );
  }
}
