import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import '../app/ops_texts.dart';

/// Asks what sales checked before resolving a review; null if cancelled.
Future<String?> askResolveNote(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _ResolveReviewDialog());

class _ResolveReviewDialog extends StatefulWidget {
  const _ResolveReviewDialog();

  @override
  State<_ResolveReviewDialog> createState() => _ResolveReviewDialogState();
}

// Stateful so the note lives as long as the dialog, closing animation included.
class _ResolveReviewDialogState extends State<_ResolveReviewDialog> {
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(OpsTexts.resolveReviewTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(OpsTexts.resolveReviewHelp),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(labelText: OpsTexts.resolveNote),
                validator: (text) => (text ?? '').trim().isEmpty ? CoreTexts.requiredField : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.of(context).pop(_note.text.trim());
          },
          child: const Text(OpsTexts.resolve),
        ),
      ],
    );
  }
}
