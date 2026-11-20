import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/busy_wait.dart';

// SQLite's own busy wait (`PRAGMA busy_timeout`) counts the time it meant to
// sleep, not the time that passed. On Linux and Android the Dart VM's
// profiler interrupts every thread about 1000 times a second, and SQLite's
// sleep ends at the first interrupt, so its 5 s were over in about 60 ms
// (D-164). These tests drive `busyWait` with a fake clock to pin the rule:
// the wait is measured on a real clock, whatever the sleeps do.

/// A fake monotonic clock and a sleep that moves it.
class _Time {
  Duration now = Duration.zero;
  final List<Duration> pauses = [];

  Duration clock() => now;

  /// A sleep that lasts as long as asked.
  void fullPause(Duration d) {
    pauses.add(d);
    now += d;
  }

  /// A sleep cut short by a signal: it lasts at most 1 ms, whatever was asked.
  void interruptedPause(Duration d) {
    pauses.add(d);
    now += d < const Duration(milliseconds: 1)
        ? d
        : const Duration(milliseconds: 1);
  }
}

/// Calls [handler] as SQLite does for one lock event (count 0, 1, 2, ...)
/// until it gives up, and returns how many times it said "try again".
int _retriesUntilGivingUp(bool Function(int) handler) {
  var count = 0;
  while (handler(count)) {
    count++;
    if (count > 100000) fail('the handler never gave up');
  }
  return count;
}

/// SQLite's own sleeps between tries, in ms (`sqliteDefaultBusyCallback`).
const _sqliteSteps = [1, 2, 5, 10, 15, 20, 25, 25, 25, 50, 50, 100, 100];

void main() {
  test('the limit is 5 s', () {
    expect(busyWaitLimit, const Duration(seconds: 5));
  });

  test('sleeps cut short by signals still wait 5 s of real time', () {
    final time = _Time();
    final handler = busyWait(clock: time.clock, pause: time.interruptedPause);

    final retries = _retriesUntilGivingUp(handler);

    // SQLite's own wait would give up after about 60 tries here (60 ms).
    expect(time.now, busyWaitLimit);
    expect(retries, greaterThan(1000));
  });

  test('full sleeps give up at exactly 5 s, the last sleep cut to what is '
      'left', () {
    final time = _Time();
    final handler = busyWait(clock: time.clock, pause: time.fullPause);

    _retriesUntilGivingUp(handler);

    expect(time.now, busyWaitLimit);
    expect(time.pauses.fold(Duration.zero, (a, b) => a + b), busyWaitLimit);
  });

  test("the sleeps follow SQLite's own steps: short at first, never over "
      '100 ms', () {
    final time = _Time();
    final handler = busyWait(clock: time.clock, pause: time.fullPause);

    _retriesUntilGivingUp(handler);

    expect(time.pauses.take(13).map((d) => d.inMilliseconds), _sqliteSteps);
    expect(
      time.pauses.every((d) => d <= const Duration(milliseconds: 100)),
      isTrue,
    );
  });

  test('a lock freed during the wait ends it: the handler is not called '
      'again, and the next lock event gets its own 5 s', () {
    final time = _Time();
    final handler = busyWait(clock: time.clock, pause: time.fullPause);

    // The first event: SQLite gets the lock after 3 tries.
    expect(handler(0), isTrue);
    expect(handler(1), isTrue);
    expect(handler(2), isTrue);
    time.now += const Duration(seconds: 4);

    // A new event starts at count 0: 4 s later it still waits the full 5 s.
    final start = time.now;
    _retriesUntilGivingUp(handler);
    expect(time.now - start, busyWaitLimit);
  });

  test('an event right after one that gave up still waits 5 s', () {
    final time = _Time();
    final handler = busyWait(clock: time.clock, pause: time.fullPause);
    _retriesUntilGivingUp(handler);

    final start = time.now;
    _retriesUntilGivingUp(handler);

    expect(time.now - start, busyWaitLimit);
  });

  test('a sleep that overshoots (a busy phone) gives up at the next call, '
      'with no negative sleep', () {
    final time = _Time();
    final handler = busyWait(
      clock: time.clock,
      pause: (d) {
        time.pauses.add(d);
        time.now += const Duration(seconds: 3);
      },
    );

    expect(handler(0), isTrue);
    expect(handler(1), isTrue);
    expect(time.now, const Duration(seconds: 6));
    expect(handler(2), isFalse);
    expect(time.pauses, hasLength(2));
    expect(time.pauses.every((d) => d > Duration.zero), isTrue);
  });

  test('a limit of zero never sleeps', () {
    final time = _Time();
    final handler = busyWait(
      limit: Duration.zero,
      clock: time.clock,
      pause: time.fullPause,
    );

    expect(handler(0), isFalse);
    expect(time.pauses, isEmpty);
  });

  test('the default clock and sleep are real: a 30 ms limit takes about '
      '30 ms', () {
    final handler = busyWait(limit: const Duration(milliseconds: 30));
    final watch = Stopwatch()..start();

    final retries = _retriesUntilGivingUp(handler);

    expect(watch.elapsedMilliseconds, inInclusiveRange(30, 1000));
    // 1 + 2 + 5 + 10 + 12 ms (fewer if a sleep overshoots): it sleeps, it
    // does not spin.
    expect(retries, inInclusiveRange(1, 5));
  });
}
