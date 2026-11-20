import 'dart:io' show sleep;

/// How long a statement waits for the other engine's write before it fails
/// with "database is locked" (D-164).
const Duration busyWaitLimit = Duration(seconds: 5);

/// SQLite's own steps between tries, in ms: short at first, then 100 ms.
const List<int> _steps = [1, 2, 5, 10, 15, 20, 25, 25, 25, 50, 50, 100];

final Stopwatch _monotonic = Stopwatch()..start();

Duration _now() => _monotonic.elapsed;

/// A busy handler that waits up to [limit] of real time (D-164).
///
/// SQLite calls it each time the lock it needs is held by the other
/// connection, with the number of earlier calls for the same lock (0 for the
/// first). It sleeps a step and returns `true` to try again, or `false` once
/// [limit] has passed since that first call, and SQLite then fails with
/// `SQLITE_BUSY`.
///
/// It replaces `PRAGMA busy_timeout`, which adds up the sleeps it asked for
/// instead of reading a clock. On Linux and Android the Dart VM's profiler
/// signals every thread about 1000 times a second, SQLite's `nanosleep` ends
/// at the first signal and is not resumed, so its 5 s were over in about
/// 60 ms. Dart's [sleep] resumes after a signal, and the [clock] is real, so
/// this wait lasts [limit] whatever the sleeps do.
///
/// [clock] (a monotonic time) and [pause] are for tests.
bool Function(int count) busyWait({
  Duration limit = busyWaitLimit,
  Duration Function() clock = _now,
  void Function(Duration) pause = sleep,
}) {
  var start = Duration.zero;
  return (count) {
    final now = clock();
    if (count == 0) start = now;
    final left = limit - (now - start);
    if (left <= Duration.zero) return false;
    final step = Duration(
      milliseconds: _steps[count < _steps.length ? count : _steps.length - 1],
    );
    pause(step < left ? step : left);
    return true;
  };
}
