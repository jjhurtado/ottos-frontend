import 'package:intl/intl.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../utils/business_time.dart';
import '../utils/formatters.dart';

/// A remittance as text to paste in WhatsApp or SMS (REQ-025 BR-2): what the
/// courier needs, never the PIN, the sender, the fee or the total (BR-3).
/// Empty fields are left out; a voided remittance starts with «ANULADA».
String remittanceShareText(Remittance remittance) {
  String? clean(String? text) => text == null || text.trim().isEmpty ? null : text.trim();
  String? line(String label, String? value) => value == null ? null : '$label: $value';
  String? joined(List<String?> parts, String separator) {
    final present = parts.map(clean).whereType<String>().toList();
    return present.isEmpty ? null : present.join(separator);
  }

  final expected = remittance.expectedDate;
  final amount = remittance.cashAmount;
  return [
    if (remittance.isVoided) CoreTexts.shareVoided,
    '${CoreTexts.shareRemittance} ${remittance.code} · '
        '${remittance.isPickup ? CoreTexts.pickup : CoreTexts.shareDelivery}',
    line(CoreTexts.shareBeneficiary, clean(remittance.beneficiaryName)),
    line(CoreTexts.sharePhone, joined([remittance.beneficiaryPhone, remittance.beneficiaryAlternatePhone], ' / ')),
    line(CoreTexts.shareAddress, joined([remittance.beneficiaryAddress, remittance.municipalityName], ', ')),
    line(CoreTexts.shareReference, clean(remittance.beneficiaryReference)),
    line(
      remittance.isPickup ? CoreTexts.shareToCollect : CoreTexts.shareToDeliver,
      amount == null ? null : Formatters.money(amount, remittance.cashCurrency),
    ),
    line(
      CoreTexts.shareExpectedDate,
      // A plain date as it came; an instant, on the business's calendar.
      expected == null ? null : DateFormat('dd/MM/yyyy').format(expected.isUtc ? BusinessTime.of(expected) : expected),
    ),
  ].whereType<String>().join('\n');
}
