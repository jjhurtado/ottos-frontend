import 'package:ottos_core/ottos_core.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the phone's share sheet with [remittance] as text; the sheet offers
/// copying too. Works offline: it only uses the data on the phone (REQ-025).
Future<void> shareRemittance(Remittance remittance) =>
    SharePlus.instance.share(ShareParams(text: remittanceShareText(remittance)));
