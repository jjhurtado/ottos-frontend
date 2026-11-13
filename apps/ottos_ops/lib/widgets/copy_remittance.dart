import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ottos_core/ottos_core.dart';

/// Puts [remittance] on the clipboard as text and says so (REQ-025 AC-1.1).
/// Takes the messenger, not a context: it also runs from a SnackBar once the
/// page that showed it is gone.
Future<void> copyRemittance(ScaffoldMessengerState messenger, Remittance remittance) async {
  await Clipboard.setData(ClipboardData(text: remittanceShareText(remittance)));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text(CoreTexts.remittanceCopied)));
}
