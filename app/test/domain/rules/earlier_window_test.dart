import 'package:flutter_test/flutter_test.dart';
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
  group('earlierWindowStart', () {
    test('today starts at local midnight', () {
      final start = earlierWindowStart(
        EarlierRange.today,
        DateTime(2026, 10, 28, 14, 30),
      );
      expect(start, DateTime(2026, 10, 28).toUtc());
      expect(start.isUtc, isTrue);
      expect(start.toLocal(), DateTime(2026, 10, 28));
    });

    test('today at exactly local midnight is that midnight', () {
      expect(
        earlierWindowStart(EarlierRange.today, DateTime(2026, 10, 28)),
        DateTime(2026, 10, 28).toUtc(),
      );
    });

    test('today at 23:59:59.999 is still that day', () {
      expect(
        earlierWindowStart(
          EarlierRange.today,
          DateTime(2026, 10, 28, 23, 59, 59, 999),
        ),
        DateTime(2026, 10, 28).toUtc(),
      );
    });

    test("last 2 days starts at yesterday's midnight", () {
      expect(
        earlierWindowStart(
          EarlierRange.lastTwoDays,
          DateTime(2026, 10, 28, 0, 5),
        ),
        DateTime(2026, 10, 27).toUtc(),
      );
      expect(
        earlierWindowStart(
          EarlierRange.lastTwoDays,
          DateTime(2026, 10, 28, 23, 55),
        ),
        DateTime(2026, 10, 27).toUtc(),
      );
    });

    test('last 7 days starts at midnight six days ago', () {
      expect(
        earlierWindowStart(
          EarlierRange.lastSevenDays,
          DateTime(2026, 10, 28, 9),
        ),
        DateTime(2026, 10, 22).toUtc(),
      );
    });

    test('last 7 days spans a month and a year boundary', () {
      expect(
        earlierWindowStart(
          EarlierRange.lastSevenDays,
          DateTime(2027, 1, 3, 10),
        ),
        DateTime(2026, 12, 28).toUtc(),
      );
      expect(
        earlierWindowStart(EarlierRange.lastTwoDays, DateTime(2027, 3, 1, 8)),
        DateTime(2027, 2, 28).toUtc(),
      );
    });

    test('a UTC now is read in local time', () {
      // Here the UTC and local dates are the same in most zones; the London
      // group has the case where they differ.
      final local = DateTime(2026, 10, 28, 14, 30);
      expect(
        earlierWindowStart(EarlierRange.today, local.toUtc()),
        DateTime(2026, 10, 28).toUtc(),
      );
    });
  });

  group('a daylight-saving day still starts at midnight (Europe/London)', () {
    test('the zone is Europe/London', () {
      expect(_inLondon, isTrue, reason: 'run with TZ=Europe/London');
    }, skip: _londonOnly);

    test('a UTC now just after local midnight is read in local time', () {
      // 00:30 on the 20th in summer time (BST) is still the 19th in UTC.
      final utcNow = DateTime(2026, 10, 20, 0, 30).toUtc();
      expect(utcNow, DateTime.utc(2026, 10, 19, 23, 30));
      expect(
        earlierWindowStart(EarlierRange.today, utcNow),
        DateTime(2026, 10, 20).toUtc(),
      );
      expect(
        earlierWindowStart(EarlierRange.today, utcNow),
        DateTime.utc(2026, 10, 19, 23),
      );
      expect(
        earlierWindowStart(EarlierRange.lastTwoDays, utcNow),
        DateTime(2026, 10, 19).toUtc(),
      );
      expect(
        earlierWindowStart(EarlierRange.lastTwoDays, utcNow),
        DateTime.utc(2026, 10, 18, 23),
      );
    }, skip: _londonOnly);

    test('clocks go back (2026-10-25, a 25-hour day)', () {
      // Midnight on the 25th is still summer time (BST, UTC+1).
      final midnight25 = DateTime.utc(2026, 10, 24, 23);

      final lateOnTheDay = DateTime(2026, 10, 25, 23, 30);
      expect(lateOnTheDay.toUtc(), DateTime.utc(2026, 10, 25, 23, 30));
      expect(earlierWindowStart(EarlierRange.today, lateOnTheDay), midnight25);

      // Just after midnight on the 26th: "yesterday and today" reaches back
      // over the whole 25-hour day.
      final nextDay = DateTime(2026, 10, 26, 0, 5);
      final start = earlierWindowStart(EarlierRange.lastTwoDays, nextDay);
      expect(start, midnight25);
      expect(nextDay.difference(start), const Duration(hours: 25, minutes: 5));
      expect(start.toLocal(), DateTime(2026, 10, 25));

      // Six days back from the 31st crosses the change.
      expect(
        earlierWindowStart(
          EarlierRange.lastSevenDays,
          DateTime(2026, 10, 31, 12),
        ),
        midnight25,
      );
    }, skip: _londonOnly);

    test('clocks go forward (2027-03-28, a 23-hour day)', () {
      // Midnight on the 28th is still winter time (GMT, UTC+0).
      final midnight28 = DateTime.utc(2027, 3, 28);

      final lateOnTheDay = DateTime(2027, 3, 28, 23, 30);
      expect(lateOnTheDay.toUtc(), DateTime.utc(2027, 3, 28, 22, 30));
      expect(earlierWindowStart(EarlierRange.today, lateOnTheDay), midnight28);

      final nextDay = DateTime(2027, 3, 29, 0, 5);
      final start = earlierWindowStart(EarlierRange.lastTwoDays, nextDay);
      expect(start, midnight28);
      expect(nextDay.difference(start), const Duration(hours: 23, minutes: 5));
      expect(start.toLocal(), DateTime(2027, 3, 28));

      expect(
        earlierWindowStart(
          EarlierRange.lastSevenDays,
          DateTime(2027, 4, 3, 12),
        ),
        midnight28,
      );
    }, skip: _londonOnly);
  });

  group('shotInWindow', () {
    final now = DateTime.utc(2026, 10, 28, 12);
    final start = DateTime.utc(2026, 10, 27, 23);
    final startMs = start.millisecondsSinceEpoch;

    test('includes exactly the start', () {
      expect(
        shotInWindow(fakeVideo(id: 1, dateTakenMs: startMs), start, now: now),
        isTrue,
      );
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs + 1),
          start,
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
          now: now,
        ),
        isFalse,
      );
    });

    test('uses the fallback date when DATE_TAKEN is junk', () {
      // DATE_TAKEN in 1904 would be before the start; DATE_ADDED is inside.
      final inside = fakeVideo(
        id: 1,
        dateTakenMs: DateTime.utc(1904).millisecondsSinceEpoch,
        dateAddedSec: startMs ~/ 1000,
      );
      expect(shotInWindow(inside, start, now: now), isTrue);

      // DATE_TAKEN in the far future would be inside; DATE_ADDED is before.
      final outside = fakeVideo(
        id: 1,
        dateTakenMs: DateTime.utc(2099).millisecondsSinceEpoch,
        dateAddedSec: startMs ~/ 1000 - 1,
      );
      expect(shotInWindow(outside, start, now: now), isFalse);
    });

    test('excludes pending and zero-length', () {
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs, pending: true),
          start,
          now: now,
        ),
        isFalse,
      );
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs, durationMs: 0),
          start,
          now: now,
        ),
        isFalse,
      );
      expect(
        shotInWindow(
          fakeVideo(id: 1, dateTakenMs: startMs, durationMs: null),
          start,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
