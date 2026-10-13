import 'package:intl/intl.dart';

/// Number and date formats for the Spanish interface (Cuba).
abstract final class Formatters {
  static const _locale = 'es';

  static String money(num? amount, String? currency) {
    if (amount == null) return '';
    final number = NumberFormat.decimalPatternDigits(locale: _locale, decimalDigits: 2).format(amount);
    return currency == null ? number : '$number $currency';
  }

  static String date(DateTime? value) => value == null ? '' : DateFormat.yMMMd(_locale).format(value.toLocal());

  static String dateTime(DateTime? value) =>
      value == null ? '' : DateFormat.yMMMd(_locale).add_Hm().format(value.toLocal());

  /// `14:05`.
  static String time(DateTime? value) => value == null ? '' : DateFormat.Hm(_locale).format(value.toLocal());

  /// `yyyy-MM-dd`, as the API expects in query parameters.
  static String apiDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  /// Wall-clock date and time without a zone, as the API takes Cuba's local time.
  static String apiLocalDateTime(DateTime value) => DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(value);
}
