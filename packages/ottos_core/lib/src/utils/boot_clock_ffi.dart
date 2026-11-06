import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class _Timespec extends Struct {
  @Int64()
  external int seconds;

  @Int64()
  external int nanoseconds;
}

typedef _ClockGettimeC = Int32 Function(Int32 clock, Pointer<_Timespec> time);
typedef _ClockGettime = int Function(int clock, Pointer<_Timespec> time);

/// `clock_gettime` with a clock that counts sleep; null when unavailable.
Duration Function()? bootClock() {
  final int clock;
  if (Platform.isAndroid || Platform.isLinux) {
    clock = 7; // CLOCK_BOOTTIME
  } else if (Platform.isIOS || Platform.isMacOS) {
    clock = 6; // CLOCK_MONOTONIC (counts sleep on Darwin)
  } else {
    return null;
  }
  try {
    final library = Platform.isAndroid ? DynamicLibrary.open('libc.so') : DynamicLibrary.process();
    final clockGettime = library.lookupFunction<_ClockGettimeC, _ClockGettime>('clock_gettime');
    // One buffer for the whole run: the clock is read on the UI isolate only.
    final time = calloc<_Timespec>();
    if (clockGettime(clock, time) != 0) return null;
    return () {
      clockGettime(clock, time);
      return Duration(microseconds: time.ref.seconds * Duration.microsecondsPerSecond + time.ref.nanoseconds ~/ 1000);
    };
  } on Object {
    return null;
  }
}
