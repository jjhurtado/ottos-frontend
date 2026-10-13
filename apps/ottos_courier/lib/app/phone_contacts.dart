import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:ottos_core/ottos_core.dart';

/// Opens the phone's own contact picker on its phone numbers. The system
/// picker hands back only the chosen contact, so the app never asks for
/// permission to read the whole address book.
Future<PickedContact?> pickPhoneContact() async {
  final contact = await FlutterNativeContactPicker().selectPhoneNumber();
  if (contact == null) return null;
  return PickedContact(
    name: contact.fullName ?? '',
    phone: contact.selectedPhoneNumber ?? contact.phoneNumbers?.firstOrNull ?? '',
  );
}
