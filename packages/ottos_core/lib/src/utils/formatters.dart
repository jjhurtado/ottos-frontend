import 'package:intl/intl.dart';

import 'business_time.dart';

/// Number and date formats for the Spanish interface (Cuba).
abstract final class Formatters {
  static const _locale = 'es';

  static String money(num? amount, String? currency) {
    if (amount == null) return '';
    final number = NumberFormat.decimalPatternDigits(locale: _locale, decimalDigits: 2).format(amount);
    return currency == null ? number : '$number $currency';
  }

  /// `5 nov 2026`. Instants (UTC, as the API sends them) are shown in the
  /// business time zone; a plain date or wall clock (a local [DateTime], e.g. a
  /// due date or a picked day) is shown as it is, never shifted.
  static String date(DateTime? value) => value == null ? '' : DateFormat.yMMMd(_locale).format(_wall(value));

  /// `5 nov 2026 14:05`, in business time as [date] says.
  static String dateTime(DateTime? value) =>
      value == null ? '' : DateFormat.yMMMd(_locale).add_Hm().format(_wall(value));

  /// `14:05`, in business time as [date] says.
  static String time(DateTime? value) => value == null ? '' : DateFormat.Hm(_locale).format(_wall(value));

  static DateTime _wall(DateTime value) => value.isUtc ? BusinessTime.of(value) : value;

  /// `yyyy-MM-dd`, as the API expects in query parameters.
  static String apiDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  /// Wall-clock date and time without a zone, as the API takes the business's local time.
  static String apiLocalDateTime(DateTime value) => DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(value);
}
