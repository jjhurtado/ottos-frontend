import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../utils/formatters.dart';

/// Confirms a delivery (or pickup) by the business, saying what it does to the
/// business's cash and the courier; the optional note, or null if cancelled.
Future<String?> askCompleteFromBusiness(BuildContext context, Remittance remittance) => showDialog<String>(
  context: context,
  builder: (_) => _CompleteFromBusinessDialog(remittance: remittance),
);

class _CompleteFromBusinessDialog extends StatefulWidget {
  const _CompleteFromBusinessDialog({required this.remittance});

  final Remittance remittance;

  @override
  State<_CompleteFromBusinessDialog> createState() => _CompleteFromBusinessDialogState();
}

class _CompleteFromBusinessDialogState extends State<_CompleteFromBusinessDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remittance = widget.remittance;
    return AlertDialog(
      title: Text(CoreTexts.byBusinessTitle(remittance.code, isPickup: remittance.isPickup)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CoreTexts.byBusinessHelp(
                Formatters.money(remittance.cashAmount, remittance.cashCurrency),
                isPickup: remittance.isPickup,
                hasCourier: remittance.courierId != null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              autofocus: true,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: CoreTexts.note),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: const Text(CoreTexts.confirm),
        ),
      ],
    );
  }
}
