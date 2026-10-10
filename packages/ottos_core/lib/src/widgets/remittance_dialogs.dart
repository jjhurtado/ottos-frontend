import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';
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
          style: FilledButton.styleFrom(backgroundColor: widget.isPickup ? OttosColors.pickup : OttosColors.delivery),
          onPressed: () => Navigator.of(context).pop((pin: _pin.text.trim(), note: _emptyToNull(_note.text))),
          child: const Text(CoreTexts.confirm),
        ),
      ],
    );
  }

  static String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();
}

typedef PostponeInput = ({DateTime newDate, String reason});

/// The first date a remittance expected on [current] can be postponed to: the
/// backend wants a later date than the expected one, and never today or before.
DateTime earliestPostponeDate(DateTime? current, {DateTime? now}) {
  final tomorrow = DateUtils.dateOnly(now ?? DateTime.now()).add(const Duration(days: 1));
  if (current == null) return tomorrow;
  final dayAfter = DateUtils.dateOnly(current).add(const Duration(days: 1));
  return dayAfter.isAfter(tomorrow) ? dayAfter : tomorrow;
}

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
  late final DateTime _earliest = earliestPostponeDate(widget.current);
  late DateTime _date = _earliest;

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
      firstDate: _earliest,
      lastDate: today.add(const Duration(days: 60)).isAfter(_earliest)
          ? today.add(const Duration(days: 60))
          : _earliest.add(const Duration(days: 60)),
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

typedef IncidentInput = ({IncidentReason reason, String? note});

/// Asks why a delivery or pickup could not be done. The note is required
/// for [IncidentReason.other], as the backend asks.
Future<IncidentInput?> showIncidentDialog(BuildContext context, {required bool isPickup}) {
  return showDialog<IncidentInput>(
    context: context,
    builder: (_) => _IncidentDialog(isPickup: isPickup),
  );
}

class _IncidentDialog extends StatefulWidget {
  const _IncidentDialog({required this.isPickup});

  final bool isPickup;

  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  IncidentReason? _reason;
  // After a failed attempt, revalidate on every change so the note error
  // goes away when another reason is chosen.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteRequired = _reason == IncidentReason.other;
    return AlertDialog(
      title: Text(widget.isPickup ? CoreTexts.reportIncidentPickup : CoreTexts.reportIncident),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(CoreTexts.incidentTitle, style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<IncidentReason>(
                groupValue: _reason,
                onChanged: (reason) => setState(() => _reason = reason),
                child: Column(
                  children: [
                    for (final reason in IncidentReason.values)
                      RadioListTile<IncidentReason>(
                        contentPadding: EdgeInsets.zero,
                        value: reason,
                        title: Text(CoreTexts.incidentReason(reason)),
                      ),
                  ],
                ),
              ),
              TextFormField(
                controller: _note,
                maxLines: 2,
                // On the field, not the form: the form would revalidate with
                // the validator of the previous reason.
                autovalidateMode: _autovalidate,
                decoration: InputDecoration(
                  labelText: noteRequired ? '${CoreTexts.incidentNote} *' : CoreTexts.incidentNoteOptional,
                ),
                validator: (value) =>
                    noteRequired && (value ?? '').trim().isEmpty ? CoreTexts.incidentNoteRequired : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: OttosColors.danger),
          onPressed: _reason == null
              ? null
              : () {
                  if (!_formKey.currentState!.validate()) {
                    setState(() => _autovalidate = AutovalidateMode.always);
                    return;
                  }
                  final note = _note.text.trim();
                  Navigator.of(context).pop((reason: _reason!, note: note.isEmpty ? null : note));
                },
          child: const Text(CoreTexts.report),
        ),
      ],
    );
  }
}
