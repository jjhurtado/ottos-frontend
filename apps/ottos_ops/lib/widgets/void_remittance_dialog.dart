import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import '../app/ops_texts.dart';

/// Asks why a remittance is voided, warning what voiding does; null if cancelled.
Future<String?> askVoidReason(BuildContext context, Remittance remittance) => showDialog<String>(
  context: context,
  builder: (_) => _VoidRemittanceDialog(remittance: remittance),
);

class _VoidRemittanceDialog extends StatefulWidget {
  const _VoidRemittanceDialog({required this.remittance});

  final Remittance remittance;

  @override
  State<_VoidRemittanceDialog> createState() => _VoidRemittanceDialogState();
}

class _VoidRemittanceDialogState extends State<_VoidRemittanceDialog> {
  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(OpsTexts.voidTitle(widget.remittance.code)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(OpsTexts.voidHelp),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                autofocus: true,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: OpsTexts.voidReasonLabel),
                validator: (text) => (text ?? '').trim().isEmpty ? CoreTexts.requiredField : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: OttosColors.danger),
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.of(context).pop(_reason.text.trim());
          },
          child: const Text(OpsTexts.voidAction),
        ),
      ],
    );
  }
}
