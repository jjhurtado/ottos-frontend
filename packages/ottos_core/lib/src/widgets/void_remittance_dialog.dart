import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';
import 'remittance_title.dart';

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
      title: Text(CoreTexts.voidTitle(remittanceLabel(widget.remittance.beneficiaryName, widget.remittance.code))),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(CoreTexts.voidHelp),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                autofocus: true,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: CoreTexts.voidReasonLabel),
                validator: (text) => (text ?? '').trim().isEmpty ? CoreTexts.requiredField : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: OttosColors.danger, foregroundColor: Colors.white),
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.of(context).pop(_reason.text.trim());
          },
          child: const Text(CoreTexts.voidAction),
        ),
      ],
    );
  }
}
