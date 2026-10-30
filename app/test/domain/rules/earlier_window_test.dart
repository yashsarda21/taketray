import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/earlier_window.dart';

import '../../support/fake_media_bridge.dart';

/// True when the test runs in Europe/London (`TZ=Europe/London`): its
/// clocks go back on 2026-10-25 and forward on 2027-03-28, both at 01:00 UTC.
bool get _inLondon {
  const hour = Duration(hours: 1);
  return DateTime(2026, 10, 24, 12).timeZoneOffset == hour &&
      DateTime(2026, 10, 26, 12).timeZoneOffset == Duration.zero &&
      DateTime(2027, 3, 27, 12).timeZoneOffset == Duration.zero &&
      DateTime(2027, 3, 29, 12).timeZoneOffset == hour &&
      DateTime.utc(2026, 10, 25, 0, 59).toLocal().hour == 1 &&
      DateTime.utc(2026, 10, 25, 1).toLocal().hour == 1 &&
      DateTime.utc(2027, 3, 28, 0, 59).toLocal().hour == 0 &&
      DateTime.utc(2027, 3, 28, 1).toLocal().hour == 2;
}

/// tool/check runs this file a second time with `TZ=Europe/London` and
/// `--run-skipped`, so on CI these tests always run, and fail in any other
/// zone.
final Object _londonOnly = _inLondon
    ? false
    : 'needs TZ=Europe/London; tool/check runs it so';

void main() {
  group('earlierWindowBounds: Today', () {
    test('starts at local midnight and ends at the next local midnight', () {
      final b = earlierWindowBounds(
        const EarlierToday(),
        DateTime(2026, 10, 28, 14, 30),
      );
      expect(b.startUtc, DateTime(2026, 10, 28).toUtc());
      expect(b.endUtc, DateTime(2026, 10, 29).toUtc());
      expect(b.startUtc.isUtc, isTrue);
      expect(b.endUtc.isUtc, isTrue);
      expect(b.startUtc.toLocal(), DateTime(2026, 10, 28));
      expect(b.endUtc.toLocal(), DateTime(2026, 10, 29));
    });

    test('at exactly local midnight it is that day', () {
      final b = earlierWindowBounds(
        const EarlierToday(),
        DateTime(2026, 10, 28),
      );
      expect(b.startUtc, DateTime(2026, 10, 28).toUtc());
      expect(b.endUtc, DateTime(2026, 10, 29).toUtc());
    });

    test('at 23:59:59.999 it is still that day', () {
      final b = earlierWindowBounds(
        const EarlierToday(),
        DateTime(2026, 10, 28, 23, 59, 59, 999),
      );
      expect(b.startUtc, DateTime(2026, 10, 28).toUtc());
      expect(b.endUtc, DateTime(2026, 10, 29).toUtc());
    });

    test('the last day of a month and of a year ends on the next one', () {
      expect(
        earlierWindowBounds(const EarlierToday(), DateTime(2026, 10, 31, 9)),
        (
          startUtc: DateTime(2026, 10, 31).toUtc(),
          endUtc: DateTime(2026, 11).toUtc(),
        ),
      );
      expect(
        earlierWindowBounds(const EarlierToday(), DateTime(2026, 12, 31, 9)),
        (
          startUtc: DateTime(2026, 12, 31).toUtc(),
          endUtc: DateTime(2027).toUtc(),
        ),
      );
    });

    test('a UTC now is read in local time', () {
      final local = DateTime(2026, 10, 28, 14, 30);
      expect(
        earlierWindowBounds(const EarlierToday(), local.toUtc()),
        earlierWindowBounds(const EarlierToday(), local),
      );
    });
  });

  group('earlierWindowBounds: a chosen date range', () {
    final now = DateTime(2026, 10, 28, 14, 30);

    test('one day (from == to) is that local day', () {
      final b = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 10, 20), DateTime(2026, 10, 20)),
        now,
      );
      expect(b.startUtc, DateTime(2026, 10, 20).toUtc());
      expect(b.endUtc, DateTime(2026, 10, 21).toUtc());
      expect(b.startUtc.isUtc && b.endUtc.isUtc, isTrue);
    });

    test('both days are counted: the end is midnight after "to"', () {
      final b = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 10, 20), DateTime(2026, 10, 24)),
        now,
      );
      expect(b.startUtc, DateTime(2026, 10, 20).toUtc());
      expect(b.endUtc, DateTime(2026, 10, 25).toUtc());
    });

    test('only the calendar day counts, not the time of day', () {
      final b = earlierWindowBounds(
        EarlierCustom(
          DateTime(2026, 10, 20, 17, 45),
          DateTime(2026, 10, 20, 3),
        ),
        now,
      );
      expect(b.startUtc, DateTime(2026, 10, 20).toUtc());
      expect(b.endUtc, DateTime(2026, 10, 21).toUtc());
    });

    test('across a month boundary', () {
      final b = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 9, 29), DateTime(2026, 10, 2)),
        now,
      );
      expect(b.startUtc, DateTime(2026, 9, 29).toUtc());
      expect(b.endUtc, DateTime(2026, 10, 3).toUtc());
    });

    test('ending on the last day of a month ends on the first of the next', () {
      final b = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 9, 30), DateTime(2026, 9, 30)),
        now,
      );
      expect(b.endUtc, DateTime(2026, 10).toUtc());
    });

    test('across a year boundary', () {
      final b = earlierWindowBounds(
        EarlierCustom(DateTime(2025, 12, 30), DateTime(2026, 1, 2)),
        now,
      );
      expect(b.startUtc, DateTime(2025, 12, 30).toUtc());
      expect(b.endUtc, DateTime(2026, 1, 3).toUtc());
    });

    test(
      'February: 28 then March in a normal year, the 29th in a leap year',
      () {
        expect(
          earlierWindowBounds(
            EarlierCustom(DateTime(2026, 2, 28), DateTime(2026, 2, 28)),
            now,
          ).endUtc,
          DateTime(2026, 3).toUtc(),
        );
        expect(
          earlierWindowBounds(
            EarlierCustom(DateTime(2024, 2, 28), DateTime(2024, 2, 29)),
            now,
          ).endUtc,
          DateTime(2024, 3).toUtc(),
        );
      },
    );

    test('from after to is rejected', () {
      expect(
        () => earlierWindowBounds(
          EarlierCustom(DateTime(2026, 10, 21), DateTime(2026, 10, 20)),
          now,
        ),
        throwsArgumentError,
      );
      // Even by the time of day alone, the day decides: the 21st at 00:00 is
      // after the 20th at 23:59.
      expect(
        () => earlierWindowBounds(
          EarlierCustom(DateTime(2026, 10, 21), DateTime(2026, 10, 20, 23, 59)),
          now,
        ),
        throwsArgumentError,
      );
    });

    test('a "to" in the future is clamped to today', () {
      final clamped = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 10, 26), DateTime(2026, 11, 15)),
        now,
      );
      expect(clamped.startUtc, DateTime(2026, 10, 26).toUtc());
      expect(clamped.endUtc, DateTime(2026, 10, 29).toUtc());
      expect(
        clamped,
        earlierWindowBounds(
          EarlierCustom(DateTime(2026, 10, 26), DateTime(2026, 10, 28)),
          now,
        ),
      );
    });

    test('"to" is today: no clamping, and today..today equals Today', () {
      final b = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 10, 28), DateTime(2026, 10, 28)),
        now,
      );
      expect(b, earlierWindowBounds(const EarlierToday(), now));
    });

    test('a "from" in the future is rejected', () {
      expect(
        () => earlierWindowBounds(
          EarlierCustom(DateTime(2026, 10, 29), DateTime(2026, 10, 30)),
          now,
        ),
        throwsArgumentError,
      );
    });

    test('a UTC now is read in local time', () {
      final range = EarlierCustom(
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 28),
      );
      expect(
        earlierWindowBounds(range, now.toUtc()),
        earlierWindowBounds(range, now),
      );
    });

    test(
      'the end is exclusive for a video, and the last millisecond is in',
      () {
        final b = earlierWindowBounds(
          EarlierCustom(DateTime(2026, 10, 20), DateTime(2026, 10, 22)),
          now,
        );
        MediaVideo at(DateTime when) =>
            fakeVideo(id: 1, dateTakenMs: when.millisecondsSinceEpoch);
        bool inside(DateTime when) =>
            shotInWindow(at(when), b.startUtc, b.endUtc, now: now.toUtc());

        expect(inside(DateTime(2026, 10, 22, 23, 59, 59, 999)), isTrue);
        expect(inside(DateTime(2026, 10, 23)), isFalse);
        expect(inside(DateTime(2026, 10, 23, 0, 0, 0, 1)), isFalse);
        expect(inside(DateTime(2026, 10, 20)), isTrue);
        expect(inside(DateTime(2026, 10, 19, 23, 59, 59, 999)), isFalse);
      },
    );
  });

  group('a daylight-saving day still starts and ends at midnight '
      '(Europe/London)', () {
    test('the zone is Europe/London', () {
      expect(_inLondon, isTrue, reason: 'run with TZ=Europe/London');
    }, skip: _londonOnly);

    test('a UTC now just after local midnight is read in local time', () {
      // 00:30 on the 20th in summer time (BST) is still the 19th in UTC.
      final utcNow = DateTime(2026, 10, 20, 0, 30).toUtc();
      expect(utcNow, DateTime.utc(2026, 10, 19, 23, 30));
      final b = earlierWindowBounds(const EarlierToday(), utcNow);
      expect(b.startUtc, DateTime.utc(2026, 10, 19, 23));
      expect(b.endUtc, DateTime.utc(2026, 10, 20, 23));
    }, skip: _londonOnly);

    test('clocks go back (2026-10-25, a 25-hour day)', () {
      // Midnight on the 25th is still summer time (BST, UTC+1); midnight on
      // the 26th is winter time (GMT).
      final now = DateTime(2026, 10, 31, 12);

      final one = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 10, 25), DateTime(2026, 10, 25)),
        now,
      );
      expect(one.startUtc, DateTime.utc(2026, 10, 24, 23));
      expect(one.endUtc, DateTime.utc(2026, 10, 26));
      expect(one.endUtc.difference(one.startUtc), const Duration(hours: 25));
      expect(one.endUtc.toLocal(), DateTime(2026, 10, 26));

      // A range across the change: the 24th to the 26th is 3 calendar days
      // and 73 hours.
      final across = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 10, 24), DateTime(2026, 10, 26)),
        now,
      );
      expect(across.startUtc, DateTime.utc(2026, 10, 23, 23));
      expect(across.endUtc, DateTime.utc(2026, 10, 27));
      expect(
        across.endUtc.difference(across.startUtc),
        const Duration(hours: 73),
      );

      // The 24th alone ends at the start of the 25-hour day.
      final before = earlierWindowBounds(
        EarlierCustom(DateTime(2026, 10, 24), DateTime(2026, 10, 24)),
        now,
      );
      expect(before.endUtc, DateTime.utc(2026, 10, 24, 23));

      // Today on the 25th ends at the same midnight.
      final today = earlierWindowBounds(
        const EarlierToday(),
        DateTime(2026, 10, 25, 23, 30),
      );
      expect(today.startUtc, DateTime.utc(2026, 10, 24, 23));
      expect(today.endUtc, DateTime.utc(2026, 10, 26));
    }, skip: _londonOnly);

    test(
      'a video at 23:30 on the 25-hour day is in, 00:00 next day is out',
      () {
        final now = DateTime(2026, 10, 31, 12).toUtc();
        final b = earlierWindowBounds(
          EarlierCustom(DateTime(2026, 10, 25), DateTime(2026, 10, 25)),
          now,
        );
        bool inside(DateTime utc) => shotInWindow(
          fakeVideo(id: 1, dateTakenMs: utc.millisecondsSinceEpoch),
          b.startUtc,
          b.endUtc,
          now: now,
        );
        expect(inside(DateTime.utc(2026, 10, 25, 23, 30)), isTrue);
        expect(inside(DateTime.utc(2026, 10, 25, 23, 59, 59, 999)), isTrue);
        expect(inside(DateTime.utc(2026, 10, 26)), isFalse);
        expect(inside(DateTime.utc(2026, 10, 24, 22, 59)), isFalse);
      },
      skip: _londonOnly,
    );

    test('clocks go forward (2027-03-28, a 23-hour day)', () {
      // Midnight on the 28th is still winter time (GMT, UTC+0); midnight on
      // the 29th is summer time (BST).
      final now = DateTime(2027, 4, 3, 12);

      final one = earlierWindowBounds(
        EarlierCustom(DateTime(2027, 3, 28), DateTime(2027, 3, 28)),
        now,
      );
      expect(one.startUtc, DateTime.utc(2027, 3, 28));
      expect(one.endUtc, DateTime.utc(2027, 3, 28, 23));
      expect(one.endUtc.difference(one.startUtc), const Duration(hours: 23));
      expect(one.endUtc.toLocal(), DateTime(2027, 3, 29));

      final across = earlierWindowBounds(
        EarlierCustom(DateTime(2027, 3, 27), DateTime(2027, 3, 29)),
        now,
      );
      expect(across.startUtc, DateTime.utc(2027, 3, 27));
      expect(across.endUtc, DateTime.utc(2027, 3, 29, 23));

      final today = earlierWindowBounds(
        const EarlierToday(),
        DateTime(2027, 3, 28, 23, 30),
      );
      expect(today.startUtc, DateTime.utc(2027, 3, 28));
      expect(today.endUtc, DateTime.utc(2027, 3, 28, 23));
    }, skip: _londonOnly);
  });

  group('shotInWindow', () {
    final now = DateTime.utc(2026, 10, 28, 12);
    final start = DateTime.utc(2026, 10, 27, 23);
    final startMs = start.millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 10, 28, 23);
    final endMs = end.millisecondsSinceEpoch;

    test('includes exactly the start', () {
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs),
          start,
          end,
          now: now,
        ),
        isTrue,
      );
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs + 1),
          start,
          end,
          now: now,
        ),
        isTrue,
      );
    });

    test('excludes 1 ms before', () {
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs - 1),
          start,
          end,
          now: now,
        ),
        isFalse,
      );
    });

    test(
      'the end is exclusive: 1 ms before it is in, the end itself is out',
      () {
        bool at(int ms) => shotInWindow(
          fakeVideo(id: 1, dateTakenMs: ms),
          start,
          end,
          now: now,
        );
        expect(at(endMs - 1), isTrue);
        expect(at(endMs), isFalse);
        expect(at(endMs + 1), isFalse);
      },
    );

    test('uses the fallback date when DATE_TAKEN is junk', () {
      // DATE_TAKEN in 1904 would be before the start; DATE_ADDED is inside.
      final inside = fakeVideo(
        id: 1,
        dateTakenMs: DateTime.utc(1904).millisecondsSinceEpoch,
        dateAddedSec: startMs ~/ 1000,
      );
      expect(shotInWindow(inside, start, end, now: now), isTrue);

      // DATE_TAKEN in the far future would be inside; DATE_ADDED is before.
      final outside = fakeVideo(
        id: 1,
        dateTakenMs: DateTime.utc(2099).millisecondsSinceEpoch,
        dateAddedSec: startMs ~/ 1000 - 1,
      );
      expect(shotInWindow(outside, start, end, now: now), isFalse);
    });

    test('excludes pending and zero-length', () {
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs, pending: true),
          start,
          end,
          now: now,
        ),
        isFalse,
      );
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs, durationMs: 0),
          start,
          end,
          now: now,
        ),
        isFalse,
      );
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs, durationMs: null),
          start,
          end,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
