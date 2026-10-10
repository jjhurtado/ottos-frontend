/// Links to reach a phone number from the device.
abstract final class Phones {
  /// Cuba's country code. Beneficiaries' numbers are often stored without it.
  static const defaultCountryCode = '53';

  /// The number in international form, digits only: a leading + is dropped,
  /// and a local 8-digit Cuban number gets the country code.
  static String international(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.trim().startsWith('+')) return digits;
    return digits.length == 8 ? '$defaultCountryCode$digits' : digits;
  }

  static Uri call(String phone) => Uri(scheme: 'tel', path: phone);

  /// Opens a WhatsApp chat with the number (app or web).
  static Uri whatsApp(String phone) => Uri.https('wa.me', '/${international(phone)}');
}
