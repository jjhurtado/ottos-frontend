/// A clock that keeps counting while the device sleeps, for [BusinessTime]
/// (REQ-006, CR-1). Dart's `Stopwatch` stops in deep sleep, so a courier's
/// phone that sleeps for hours offline would date its actions hours early.
///
/// Android and Linux: `clock_gettime(CLOCK_BOOTTIME)`; iOS and macOS:
/// `clock_gettime(CLOCK_MONOTONIC)`, which counts sleep on Darwin. Null where
/// there is none (the web panel, which gets the server's time on every answer).
library;

export 'boot_clock_stub.dart' if (dart.library.ffi) 'boot_clock_ffi.dart';
