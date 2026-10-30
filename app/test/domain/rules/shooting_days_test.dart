import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/shooting_days.dart';

/// True when the test runs in Europe/London (`TZ=Europe/London`): its
/// clocks go back on 2026-10-25 and forward on 2027-03-28, both at 01:00 UTC.
bool get _inLondon {
  const hour = Duration(hours: 1);
  return DateTime(2026, 10, 24, 12).timeZoneOffset == hour &&
      DateTime(2026, 10, 26, 12).timeZoneOffset == Duration.zero &&
      DateTime(2027, 3, 27, 12).timeZoneOffset == Duration.zero &&
      DateTime(2027, 3, 29, 12).timeZoneOffset == hour;
}

/// tool/check runs this file a second time with `TZ=Europe/London` and
/// `--run-skipped`; there the local `DateTime`s around a clock change are
/// 23 or 25 hours apart, which a day count built on them gets wrong.
final Object _londonOnly = _inLondon
    ? false
    : 'needs TZ=Europe/London; tool/check runs it so';

/// A clip [id] shot at [utc]; its zone is whatever the times map says.
Clip clip(int id, DateTime utc) => Clip(
  id: id,
  source: ClipSource.mediaStore,
  fingerprint: ClipFingerprint(
    sizeBytes: 1000 + id,
    durationMs: 5000,
    dateTakenUtc: utc,
    displayName: 'VID_$id.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  firstSeenAt: DateTime.utc(2026, 10),
  missing: false,
  mediaStoreId: id,
  volumeName: 'external_primary',
);

/// [utc] seen in a zone [offset] ahead of UTC.
ClipLocalTime at(DateTime utc, Duration offset, {String zone = 'X/Y'}) =>
    ClipLocalTime(wallClock: utc.add(offset), zoneId: zone, isPhoneZone: false);

const Duration bst = Duration(hours: 1);
const Duration gmt = Duration.zero;
const Duration ist = Duration(hours: 5, minutes: 30);
const Duration est = Duration(hours: -5);

/// Groups [clips] with [times], by plain clips.
List<ShootingDay<Clip>> group(
  List<Clip> clips,
  Map<int, ClipLocalTime> times,
) => groupByShootingDay(clips, (c) => c, times);

/// Each day as `(date, number, clip ids)`, the ids joined with commas
/// (records holding lists do not compare by content).
List<(DateTime, int, String)> summary(List<ShootingDay<Clip>> days) => [
  for (final d in days) (d.date, d.number, d.clips.map((c) => c.id).join(',')),
];

void main() {
  test('the zone is Europe/London', () {
    expect(_inLondon, isTrue, reason: 'run with TZ=Europe/London');
  }, skip: _londonOnly);

  test('same local date groups together', () {
    final a = clip(1, DateTime.utc(2026, 7, 1, 6));
    final b = clip(2, DateTime.utc(2026, 7, 1, 12));
    final c = clip(3, DateTime.utc(2026, 7, 1, 22, 30)); // 23:30 BST

    final days = group(
      [a, b, c],
      {
        1: at(a.fingerprint.dateTakenUtc, bst),
        2: at(b.fingerprint.dateTakenUtc, bst),
        3: at(c.fingerprint.dateTakenUtc, bst),
      },
    );

    expect(summary(days), [(DateTime.utc(2026, 7), 1, '1,2,3')]);
    expect(days.single.date.isUtc, isTrue);
  });

  test('23:30 London and 00:30 London next day are two days', () {
    // 22:30 and 23:30 UTC: one UTC day, two London (BST) days.
    final late = clip(1, DateTime.utc(2026, 7, 1, 22, 30));
    final early = clip(2, DateTime.utc(2026, 7, 1, 23, 30));

    final days = group(
      [late, early],
      {
        1: at(late.fingerprint.dateTakenUtc, bst),
        2: at(early.fingerprint.dateTakenUtc, bst),
      },
    );

    expect(summary(days), [
      (DateTime.utc(2026, 7), 1, '1'),
      (DateTime.utc(2026, 7, 2), 2, '2'),
    ]);
  });

  test('day numbers across the London DST change', () {
    // Clocks go back at 01:00 UTC on 25 Oct 2026: that day is 25 hours long.
    final d24 = clip(1, DateTime.utc(2026, 10, 24, 22)); // 23:00 BST, 24 Oct
    final d25 = clip(2, DateTime.utc(2026, 10, 25, 23, 30)); // 23:30 GMT
    final d26 = clip(3, DateTime.utc(2026, 10, 26, 0, 30)); // 00:30 GMT

    final days = group(
      [d24, d25, d26],
      {
        1: at(d24.fingerprint.dateTakenUtc, bst),
        2: at(d25.fingerprint.dateTakenUtc, gmt),
        3: at(d26.fingerprint.dateTakenUtc, gmt),
      },
    );

    expect(summary(days), [
      (DateTime.utc(2026, 10, 24), 1, '1'),
      (DateTime.utc(2026, 10, 25), 2, '2'),
      (DateTime.utc(2026, 10, 26), 3, '3'),
    ]);
    expect(dayNumber(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 3);
  });

  test('day numbers across the London spring change (a 23-hour day)', () {
    // Clocks go forward at 01:00 UTC on 28 Mar 2027.
    final d27 = clip(1, DateTime.utc(2027, 3, 27, 12)); // 12:00 GMT
    final d28 = clip(2, DateTime.utc(2027, 3, 28, 12)); // 13:00 BST
    final d29 = clip(3, DateTime.utc(2027, 3, 29)); // 01:00 BST

    final days = group(
      [d27, d28, d29],
      {
        1: at(d27.fingerprint.dateTakenUtc, gmt),
        2: at(d28.fingerprint.dateTakenUtc, bst),
        3: at(d29.fingerprint.dateTakenUtc, bst),
      },
    );

    expect(summary(days), [
      (DateTime.utc(2027, 3, 27), 1, '1'),
      (DateTime.utc(2027, 3, 28), 2, '2'),
      (DateTime.utc(2027, 3, 29), 3, '3'),
    ]);
    // Local (non-UTC) dates give the same count in any zone.
    expect(dayNumber(DateTime(2027, 3, 28), DateTime(2027, 3, 29)), 2);
    expect(dayNumber(DateTime(2027, 3, 27), DateTime(2027, 3, 29)), 3);
    expect(dayNumber(DateTime(2026, 10, 25), DateTime(2026, 10, 26)), 2);
  });

  test('a gap of 3 empty days gives Day 1 then Day 5', () {
    final first = clip(1, DateTime.utc(2026, 10, 1, 10));
    final later = clip(2, DateTime.utc(2026, 10, 5, 10));

    final days = group(
      [first, later],
      {
        1: at(first.fingerprint.dateTakenUtc, bst),
        2: at(later.fingerprint.dateTakenUtc, bst),
      },
    );

    expect([for (final d in days) d.number], [1, 5]);
    expect(dayNumber(DateTime.utc(2026, 10), DateTime.utc(2026, 10)), 1);
    // Times of day do not matter, only the dates.
    expect(
      dayNumber(DateTime.utc(2026, 10, 1, 23, 59), DateTime.utc(2026, 10, 2)),
      2,
    );
  });

  test('clips shot in two zones group by their own local date', () {
    // 20:00 UTC on 1 Oct: 1 Oct in London, 2 Oct (01:30) in Kolkata.
    final london = clip(1, DateTime.utc(2026, 10, 1, 20));
    final kolkata = clip(2, DateTime.utc(2026, 10, 1, 20, 30));
    final londonNext = clip(3, DateTime.utc(2026, 10, 2, 9));

    final days = group(
      [london, kolkata, londonNext],
      {
        1: at(london.fingerprint.dateTakenUtc, bst, zone: 'Europe/London'),
        2: at(kolkata.fingerprint.dateTakenUtc, ist, zone: 'Asia/Kolkata'),
        3: at(londonNext.fingerprint.dateTakenUtc, bst, zone: 'Europe/London'),
      },
    );

    expect(summary(days), [
      (DateTime.utc(2026, 10), 1, '1'),
      (DateTime.utc(2026, 10, 2), 2, '2,3'),
    ]);
  });

  test('out-of-order local dates still sort the groups by date', () {
    // In shooting order (UTC): London on 2 Oct at 01:00 BST, then New York
    // on 1 Oct at 22:00 EDT-ish (-5 here), which is an earlier date.
    final london = clip(1, DateTime.utc(2026, 10, 2));
    final newYork = clip(2, DateTime.utc(2026, 10, 2, 2));
    final londonAgain = clip(3, DateTime.utc(2026, 10, 2, 8));

    final days = group(
      [london, newYork, londonAgain],
      {
        1: at(london.fingerprint.dateTakenUtc, bst),
        2: at(newYork.fingerprint.dateTakenUtc, est),
        3: at(londonAgain.fingerprint.dateTakenUtc, bst),
      },
    );

    // The earliest date is Day 1, and each group keeps the order given.
    expect(summary(days), [
      (DateTime.utc(2026, 10), 1, '2'),
      (DateTime.utc(2026, 10, 2), 2, '1,3'),
    ]);
  });

  test('a clip with no time uses its phone-local date', () {
    final known = clip(1, DateTime.utc(2026, 10, 1, 12));
    final unknown = clip(2, DateTime.utc(2026, 10, 3, 12));
    final local = unknown.fingerprint.dateTakenUtc.toLocal();

    final days = group(
      [known, unknown],
      {1: at(known.fingerprint.dateTakenUtc, gmt)},
    );

    expect(days.last.date, DateTime.utc(local.year, local.month, local.day));
    expect(days.last.clips.single.id, 2);
  });

  test('none gives none; the selector maps any item to its clip', () {
    expect(group(const [], const {}), isEmpty);

    final c = clip(7, DateTime.utc(2026, 10, 1, 12));
    final days = groupByShootingDay<(String, Clip)>(
      [('seven', c)],
      (item) => item.$2,
      {7: at(c.fingerprint.dateTakenUtc, gmt)},
    );
    expect(days.single.clips.single.$1, 'seven');
    expect(days.single.number, 1);
  });
}
