import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';

/// A clock that moves with the fake time of a `fakeAsync` zone, [behind]
/// behind it (a clock that runs a little slow).
class _FakeAsyncClock extends Clock {
  _FakeAsyncClock(this._start, this._async, {this.behind = Duration.zero});

  final DateTime _start;
  final FakeAsync _async;
  final Duration behind;

  @override
  DateTime now() => _start.add(_async.elapsed).subtract(behind).toUtc();
}

/// A clock the test sets, whatever the fake timers did: the phone slept
/// through midnight with its timer, and the clock is now past it.
class _SetClock extends Clock {
  _SetClock(this.local);

  DateTime local;

  @override
  DateTime now() => local.toUtc();
}

bool get _inLondon {
  const hour = Duration(hours: 1);
  return DateTime(2026, 10, 24, 12).timeZoneOffset == hour &&
      DateTime(2026, 10, 26, 12).timeZoneOffset == Duration.zero &&
      DateTime(2027, 3, 27, 12).timeZoneOffset == Duration.zero &&
      DateTime(2027, 3, 29, 12).timeZoneOffset == hour;
}

/// tool/check runs this file a second time with `TZ=Europe/London` and
/// `--run-skipped`: there the nights of 25 October 2026 and 28 March 2027 are
/// 25 and 23 hours long.
final Object _londonOnly = _inLondon
    ? false
    : 'needs TZ=Europe/London; tool/check runs it so';

/// Runs [body] in a fake-time zone, with a container whose clock starts at
/// the local time [start], and the days `localDayProvider` has emitted.
void inFakeTime(
  DateTime start,
  void Function(
    FakeAsync async,
    ProviderContainer container,
    List<DateTime> days,
  )
  body, {
  Duration behind = Duration.zero,
}) {
  fakeAsync((async) {
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(
          _FakeAsyncClock(start, async, behind: behind),
        ),
      ],
    );
    final days = <DateTime>[];
    container.listen<AsyncValue<DateTime>>(localDayProvider, (_, next) {
      final value = next.value;
      if (value != null) days.add(value);
    }, fireImmediately: true);
    async.flushMicrotasks();
    try {
      body(async, container, days);
    } finally {
      container.dispose();
    }
  });
}

void main() {
  group('localDayProvider', () {
    test('emits the local day now, at local midnight', () {
      inFakeTime(DateTime(2026, 10, 28, 15, 30), (async, container, days) {
        expect(days, [DateTime(2026, 10, 28)]);
      });
    });

    test('emits at the next local midnight', () {
      inFakeTime(DateTime(2026, 10, 28, 15, 30), (async, container, days) {
        async.elapse(const Duration(hours: 8, minutes: 29, seconds: 59));
        expect(days, [DateTime(2026, 10, 28)], reason: 'a second early');

        async.elapse(const Duration(seconds: 1));
        expect(days, [DateTime(2026, 10, 28), DateTime(2026, 10, 29)]);
      });
    });

    test('and again at each midnight after that', () {
      inFakeTime(DateTime(2026, 10, 28, 23, 59), (async, container, days) {
        async
          ..elapse(const Duration(minutes: 1))
          ..elapse(const Duration(days: 1))
          ..elapse(const Duration(days: 1));

        expect(days, [
          DateTime(2026, 10, 28),
          DateTime(2026, 10, 29),
          DateTime(2026, 10, 30),
          DateTime(2026, 10, 31),
        ]);
      });
    });

    test('started exactly at midnight, the next one is a day away', () {
      inFakeTime(DateTime(2026, 10, 28), (async, container, days) {
        async.elapse(const Duration(hours: 23, minutes: 59));
        expect(days, [DateTime(2026, 10, 28)]);

        async.elapse(const Duration(minutes: 1));
        expect(days, [DateTime(2026, 10, 28), DateTime(2026, 10, 29)]);
      });
    });

    test('across the clock changes of any zone: the next local midnight', () {
      // Whatever the zone, the next midnight is where DateTime says it is.
      final start = DateTime(2026, 10, 24, 23);
      final midnights = [
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26),
        DateTime(2026, 10, 27),
      ];
      inFakeTime(start, (async, container, days) {
        for (final midnight in midnights) {
          final wait = midnight.difference(start);
          async.elapse(wait - async.elapsed - const Duration(seconds: 1));
          expect(days.last, isNot(midnight), reason: 'a second early');
          async.elapse(const Duration(seconds: 1));
          expect(days.last, midnight);
        }
        expect(days, [DateTime(2026, 10, 24), ...midnights]);
      });
    });

    test('the London night in October is 25 hours long', () {
      inFakeTime(DateTime(2026, 10, 24, 23), (async, container, days) {
        async.elapse(const Duration(hours: 1));
        expect(days.last, DateTime(2026, 10, 25));

        // 25 October has 25 hours: its midnight is not 24 hours away.
        async.elapse(const Duration(hours: 24));
        expect(days.last, DateTime(2026, 10, 25), reason: 'still the 25th');
        async.elapse(const Duration(hours: 1));
        expect(days.last, DateTime(2026, 10, 26));
        expect(days, hasLength(3));
      });
    }, skip: _londonOnly);

    test('the London night in March is 23 hours long', () {
      inFakeTime(DateTime(2027, 3, 27, 23), (async, container, days) {
        async.elapse(const Duration(hours: 1));
        expect(days.last, DateTime(2027, 3, 28));

        // 28 March has 23 hours: its midnight is an hour sooner.
        async.elapse(const Duration(hours: 22, minutes: 59));
        expect(days.last, DateTime(2027, 3, 28), reason: 'a minute early');
        async.elapse(const Duration(minutes: 1));
        expect(days.last, DateTime(2027, 3, 29));
        expect(days, hasLength(3));
      });
    }, skip: _londonOnly);

    test('a timer that fires early waits again and does not repeat a day', () {
      // The clock is 2 s behind the timers.
      inFakeTime(DateTime(2026, 10, 28, 23, 59), (async, container, days) {
        async.elapse(const Duration(minutes: 1));
        expect(days, [DateTime(2026, 10, 28)], reason: 'clock says 23:59:58');

        async.elapse(const Duration(seconds: 2));
        expect(days, [DateTime(2026, 10, 28), DateTime(2026, 10, 29)]);
      }, behind: const Duration(seconds: 2));
    });

    test('cancels its timer on dispose', () {
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(
              _FakeAsyncClock(DateTime(2026, 10, 28, 15, 30), async),
            ),
          ],
        )..listen(localDayProvider, (_, _) {});
        async.flushMicrotasks();
        expect(async.pendingTimers, hasLength(1));

        container.dispose();
        async.flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
      });
    });

    test('nobody listening any more: the timer is cancelled', () {
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(
              _FakeAsyncClock(DateTime(2026, 10, 28, 15, 30), async),
            ),
          ],
        );
        final sub = container.listen(localDayProvider, (_, _) {});
        async.flushMicrotasks();

        sub.close();
        async
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
        container.dispose();
      });
    });
  });

  group('localDayProvider after the app was asleep', () {
    /// Runs [body] with a clock the test sets and a tick that never fired.
    void whileAsleep(
      DateTime start,
      void Function(
        FakeAsync async,
        _SetClock clock,
        ProviderContainer container,
        List<DateTime> days,
      )
      body,
    ) {
      fakeAsync((async) {
        final clock = _SetClock(start);
        final container = ProviderContainer(
          overrides: [clockProvider.overrideWithValue(clock)],
        );
        final days = <DateTime>[];
        container.listen<AsyncValue<DateTime>>(localDayProvider, (_, next) {
          final value = next.value;
          if (value != null) days.add(value);
        }, fireImmediately: true);
        async.flushMicrotasks();
        try {
          body(async, clock, container, days);
        } finally {
          container.dispose();
        }
      });
    }

    void resume(FakeAsync async) {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      async.flushMicrotasks();
    }

    test('resumed after midnight, with no timer fired, gives the new day', () {
      whileAsleep(DateTime(2026, 10, 28, 23, 50), (async, clock, _, days) {
        expect(days, [DateTime(2026, 10, 28)]);

        // Midnight passed while the phone slept: no timer ran.
        clock.local = DateTime(2026, 10, 29, 6, 30);
        resume(async);

        expect(days, [DateTime(2026, 10, 28), DateTime(2026, 10, 29)]);
      });
    });

    test('resumed on the same day emits nothing', () {
      whileAsleep(DateTime(2026, 10, 28, 9), (async, clock, _, days) {
        clock.local = DateTime(2026, 10, 28, 21);
        resume(async);

        expect(days, [DateTime(2026, 10, 28)]);
      });
    });

    test('a resume sets the timer again: one new day at the next midnight, '
        'not two', () {
      whileAsleep(DateTime(2026, 10, 28, 23, 50), (async, clock, _, days) {
        final timers = async.pendingTimers.length;
        clock.local = DateTime(2026, 10, 29, 6, 30);
        resume(async);
        expect(async.pendingTimers, hasLength(timers));

        // The old timer (set for the 28th's midnight) is gone: the clock
        // still reads the 29th when it would have fired.
        async.elapse(const Duration(minutes: 11));
        expect(days, [DateTime(2026, 10, 28), DateTime(2026, 10, 29)]);

        clock.local = DateTime(2026, 10, 30, 0, 1);
        async.elapse(const Duration(hours: 18));
        expect(days.last, DateTime(2026, 10, 30));
        expect(days, hasLength(3));
      });
    });

    test('the other states do not re-check', () {
      whileAsleep(DateTime(2026, 10, 28, 23, 50), (async, clock, _, days) {
        clock.local = DateTime(2026, 10, 29, 6, 30);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
            state,
          );
          async.flushMicrotasks();
        }

        expect(days, [DateTime(2026, 10, 28)]);
      });
    });

    test('after dispose a resume does nothing and does not throw', () {
      whileAsleep(DateTime(2026, 10, 28, 23, 50), (async, clock, container, _) {
        container.dispose();
        clock.local = DateTime(2026, 10, 29, 6, 30);

        expect(() => resume(async), returnsNormally);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
