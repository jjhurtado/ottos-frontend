import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';

/// A name and phone chosen from the device's address book.
class PickedContact {
  const PickedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// Opens the device's own contact picker; null when cancelled. Only the mobile
/// app provides one, so the panel's forms show no contacts button.
typedef ContactPicker = Future<PickedContact?> Function();

/// Fills [name] and [phone] from a contact chosen with [pick].
class ContactPickerButton extends StatelessWidget {
  const ContactPickerButton({
    super.key,
    required this.pick,
    required this.name,
    required this.phone,
    this.enabled = true,
  });

  final ContactPicker pick;
  final TextEditingController name;
  final TextEditingController phone;
  final bool enabled;

  Future<void> _pick() async {
    final contact = await pick();
    if (contact == null) return;
    if (contact.name.trim().isNotEmpty) name.text = contact.name.trim();
    if (contact.phone.trim().isNotEmpty) phone.text = cleanContactPhone(contact.phone);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextButton.icon(
          onPressed: enabled ? _pick : null,
          icon: const Icon(Icons.contacts_outlined),
          label: const Text(CoreTexts.pickFromContacts),
        ),
      ),
    );
  }
}

/// Address books keep spaces, dashes, dots and brackets; the form keeps only digits and a leading `+`.
String cleanContactPhone(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}
