import 'package:intl/intl.dart';

/// Wall-clock time in Cuba (`America/Havana`), whatever the device's zone:
/// reports count and show remittances in Cuba time.
///
/// Cuba is UTC−5, and UTC−4 from the second Sunday of March at 00:00 to the
/// first Sunday of November at 01:00 (both changes happen at 05:00 UTC).
/// The values returned are UTC [DateTime]s holding Cuba's wall clock, so
/// formatting them never shifts them to the device's zone.
abstract final class CubaTime {
  /// The wall clock in Cuba at [instant].
  static DateTime of(DateTime instant) {
    final utc = instant.toUtc();
    return utc.subtract(Duration(hours: isDaylightSaving(utc) ? 4 : 5));
  }

  /// Today's date in Cuba (time 00:00), as a plain date.
  static DateTime today([DateTime? now]) {
    final wall = of(now ?? DateTime.now());
    return DateTime(wall.year, wall.month, wall.day);
  }

  static bool isDaylightSaving(DateTime instant) {
    final utc = instant.toUtc();
    final start = DateTime.utc(utc.year, 3, _sunday(utc.year, 3, 2), 5);
    final end = DateTime.utc(utc.year, 11, _sunday(utc.year, 11, 1), 5);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  /// The day of the [n]th Sunday of [month].
  static int _sunday(int year, int month, int n) {
    final first = DateTime.utc(year, month);
    return 1 + (DateTime.sunday - first.weekday) % 7 + 7 * (n - 1);
  }

  /// "3 oct 2026, 14:05" in Cuba time.
  static String dateTime(DateTime? instant) =>
      instant == null ? '' : DateFormat.yMMMd('es').add_Hm().format(of(instant));

  /// "3 oct" in Cuba time.
  static String shortDate(DateTime? instant) => instant == null ? '' : DateFormat.MMMd('es').format(of(instant));

  /// "2026-10-03 14:05" in Cuba time, for spreadsheets.
  static String sortable(DateTime? instant) =>
      instant == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(of(instant));
}
