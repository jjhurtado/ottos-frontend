import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'boot_clock.dart';

/// The business time zone: a fixed offset from UTC, with no summer time
/// (`businessTime` in the API: `{"timeZone": "UTC-04:00", "offsetMinutes": -240}`).
class BusinessTimeZone extends Equatable {
  const BusinessTimeZone({required this.timeZone, required this.offsetMinutes});

  /// The zone with [offsetMinutes], written as the API writes it.
  factory BusinessTimeZone.ofMinutes(int offsetMinutes) {
    final sign = offsetMinutes < 0 ? '-' : '+';
    final minutes = offsetMinutes.abs();
    String two(int value) => value.toString().padLeft(2, '0');
    return BusinessTimeZone(
      timeZone: 'UTC$sign${two(minutes ~/ 60)}:${two(minutes % 60)}',
      offsetMinutes: offsetMinutes,
    );
  }

  /// Null when [json] is not a business time zone (e.g. an older server).
  static BusinessTimeZone? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final minutes = json['offsetMinutes'];
    if (minutes is! num) return parse(json['timeZone']);
    return BusinessTimeZone(
      timeZone: json['timeZone'] as String? ?? BusinessTimeZone.ofMinutes(minutes.toInt()).timeZone,
      offsetMinutes: minutes.toInt(),
    );
  }

  /// `UTC-04:00` → UTC−4; null when [text] is not `UTC±HH:MM`.
  static BusinessTimeZone? parse(Object? text) {
    if (text is! String) return null;
    final match = RegExp(r'^UTC([+-])(\d{2}):(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final minutes = int.parse(match[2]!) * 60 + int.parse(match[3]!);
    return BusinessTimeZone(timeZone: text, offsetMinutes: match[1] == '-' ? -minutes : minutes);
  }

  /// UTC−4, when the server never said otherwise (AC-2.5).
  static const fallback = BusinessTimeZone(timeZone: 'UTC-04:00', offsetMinutes: -240);

  /// The whole-hour offsets offered in Configuration, UTC−12 … UTC+14.
  static final wholeHours = [for (var hours = -12; hours <= 14; hours++) BusinessTimeZone.ofMinutes(hours * 60)];

  /// As the API writes it: `UTC-04:00`.
  final String timeZone;
  final int offsetMinutes;

  Duration get offset => Duration(minutes: offsetMinutes);

  /// «UTC−5», «UTC+5:30», «UTC»: Unicode minus, no «:00».
  String get label {
    if (offsetMinutes == 0) return 'UTC';
    final minutes = offsetMinutes.abs();
    final sign = offsetMinutes < 0 ? '−' : '+';
    final rest = minutes % 60;
    return 'UTC$sign${minutes ~/ 60}${rest == 0 ? '' : ':${rest.toString().padLeft(2, '0')}'}';
  }

  Map<String, dynamic> toJson() => {'timeZone': timeZone, 'offsetMinutes': offsetMinutes};

  @override
  List<Object?> get props => [offsetMinutes];
}

/// The business's time, whatever the zone or the clock of the device.
///
/// It holds two things the server sends: the business time zone (a fixed
/// offset) and the server's clock. While the app runs, [now] is the last
/// server time plus the time passed since that answer on a monotonic clock,
/// so changing the device's clock does not move it (AC-3.5). Before any
/// answer in this run it is the device clock plus the difference saved in
/// the previous run ([restore], AC-3.2), or just the device clock.
///
/// Static, so formatting needs no context; tests use [setForTest] and [reset].
abstract final class BusinessTime {
  static BusinessTimeZone _zone = BusinessTimeZone.fallback;
  static final ValueNotifier<BusinessTimeZone> _changes = ValueNotifier(BusinessTimeZone.fallback);

  static DateTime Function() _deviceClock = DateTime.now;
  static final Stopwatch _stopwatch = Stopwatch()..start();
  static final Duration Function()? _bootClock = bootClock();
  static Duration Function() _elapsed = _monotonic;

  /// A clock that counts while the device sleeps where there is one (CR-1),
  /// else Dart's `Stopwatch` (the web panel samples the server on every answer).
  static Duration _monotonic() => _bootClock?.call() ?? _stopwatch.elapsed;

  /// The last server time received in this run and [_elapsed] at that moment.
  static DateTime? _serverTime;
  static Duration _elapsedAtServerTime = Duration.zero;

  /// Server minus device, from the last answer of this run or the previous one.
  static Duration? _clockOffset;

  /// The device time when [_clockOffset] was measured.
  static DateTime? _clockOffsetSampledAt;

  /// The business time zone in use.
  static BusinessTimeZone get zone => _zone;

  /// Notifies when the zone changes, so the screens can show it.
  static ValueListenable<BusinessTimeZone> get changes => _changes;

  /// «UTC−4».
  static String get label => _zone.label;

  /// The zone the server sent; null (an older server) keeps the current one.
  static void setZone(BusinessTimeZone? zone) {
    if (zone == null || zone == _zone) return;
    _zone = zone;
    _changes.value = zone;
  }

  /// How far behind the estimate an answer may be and still be ignored: the
  /// `Date` header is cut to the second and arrives after the transit time, and
  /// answers can finish out of order. Anything more is a real correction.
  static const sampleJitter = Duration(seconds: 2);

  /// A server answer came with its time ([serverTime], an instant). One that is
  /// only a little behind the estimate is ignored, so [now] never steps back.
  static void serverTimeReceived(DateTime serverTime) {
    final utc = serverTime.toUtc();
    if (_serverTime != null) {
      final behind = now().difference(utc);
      if (behind > Duration.zero && behind < sampleJitter) return;
    }
    _serverTime = utc;
    _elapsedAtServerTime = _elapsed();
    final device = _deviceClock().toUtc();
    _clockOffset = utc.difference(device);
    _clockOffsetSampledAt = device;
  }

  /// The device time when [clockOffset] was measured, to save with it.
  static DateTime? get clockOffsetSampledAt => _clockOffsetSampledAt;

  /// How long a saved difference is trusted after it was measured.
  static const savedOffsetLifetime = Duration(hours: 24);

  /// Server time minus device time at the last answer (AC-3.1); null if none
  /// was ever received. The courier app saves it for the next start.
  static Duration? get clockOffset => _clockOffset;

  /// What the courier app saved in its previous run (AC-2.4, AC-3.2). An answer
  /// received in this run already wins over the saved difference, and the
  /// difference is dropped when the device clock went back since it was
  /// measured ([sampledAt]) or it is older than [savedOffsetLifetime]: the
  /// clock may have been corrected meanwhile.
  static void restore({BusinessTimeZone? zone, Duration? clockOffset, DateTime? sampledAt}) {
    setZone(zone);
    if (_serverTime != null || clockOffset == null || sampledAt == null) return;
    final age = _deviceClock().toUtc().difference(sampledAt.toUtc());
    if (age.isNegative || age > savedOffsetLifetime) return;
    _clockOffset = clockOffset;
    _clockOffsetSampledAt = sampledAt.toUtc();
  }

  /// The current instant, in UTC, by the server's clock as far as it is known.
  static DateTime now() {
    final serverTime = _serverTime;
    if (serverTime != null) return serverTime.add(_elapsed() - _elapsedAtServerTime);
    final device = _deviceClock().toUtc();
    return _clockOffset == null ? device : device.add(_clockOffset!);
  }

  /// The business wall clock at [instant], as a UTC [DateTime] holding it, so
  /// formatting never shifts it to the device's zone.
  static DateTime of(DateTime instant) => instant.toUtc().add(_zone.offset);

  /// The business wall clock at [instant] (default [now]) as a plain local
  /// [DateTime], to compare with what a user picks in a date or time picker.
  static DateTime wallClock([DateTime? instant]) {
    final wall = of(instant ?? now());
    return DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second);
  }

  /// The business date (time 00:00) at [instant] (default [now]), as a plain date.
  static DateTime today([DateTime? instant]) {
    final wall = of(instant ?? now());
    return DateTime(wall.year, wall.month, wall.day);
  }

  /// «3 oct 2026, 14:05» in business time.
  static String dateTime(DateTime? instant) =>
      instant == null ? '' : DateFormat.yMMMd('es').add_Hm().format(of(instant));

  /// «3 oct» in business time.
  static String shortDate(DateTime? instant) => instant == null ? '' : DateFormat.MMMd('es').format(of(instant));

  /// «2026-10-03 14:05» in business time, for spreadsheets.
  static String sortable(DateTime? instant) =>
      instant == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(of(instant));

  /// «14:32 del 5 nov 2026»: the business time at [instant] with [zone]
  /// (default the current one), for Configuration and its preview.
  static String clockText(DateTime instant, [BusinessTimeZone? zone]) {
    final wall = instant.toUtc().add((zone ?? _zone).offset);
    return '${DateFormat.Hm('es').format(wall)} del ${DateFormat.yMMMd('es').format(wall)}';
  }

  /// Sets the zone and, optionally, the device clock and the monotonic clock.
  @visibleForTesting
  static void setForTest({BusinessTimeZone? zone, DateTime Function()? deviceClock, Duration Function()? elapsed}) {
    if (zone != null) setZone(zone);
    if (deviceClock != null) _deviceClock = deviceClock;
    if (elapsed != null) _elapsed = elapsed;
  }

  /// As at the start of the app: UTC−4, device clock, no server time.
  @visibleForTesting
  static void reset() {
    setZone(BusinessTimeZone.fallback);
    _deviceClock = DateTime.now;
    _elapsed = _monotonic;
    _serverTime = null;
    _clockOffset = null;
    _clockOffsetSampledAt = null;
    _elapsedAtServerTime = Duration.zero;
  }
}
