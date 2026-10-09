import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/courier_texts.dart';

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
      title: Text(widget.isPickup ? CourierTexts.confirmCollection : CourierTexts.confirmDelivery),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: CourierTexts.pin, helperText: CourierTexts.pinHint, helperMaxLines: 2),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: CourierTexts.note),
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
