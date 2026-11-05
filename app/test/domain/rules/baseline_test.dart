import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/baseline.dart';

import '../../support/fake_media_bridge.dart';

/// The scan's "now" in these tests; every row's DATE_ADDED is days before it
/// (`fakeVideo`), so only a pending row holds unless a test says otherwise.
final DateTime _now = DateTime.utc(2026, 6, 1, 9);

void main() {
  const baseline = VolumeBaseline(version: 'v1', generation: 40);

  group('planVolume', () {
    test('an unmounted volume is skipped', () {
      const unmounted = MediaVolume(name: 'sd', generation: 0);
      expect(planVolume(baseline, unmounted), isA<SkipVolume>());
      expect(planVolume(null, unmounted), isA<SkipVolume>());
    });

    test('skipping an unmounted volume wins over a changed version', () {
      // An unmounted volume has no version, so it differs from the
      // baseline's, and its generation is below the baseline's too.
      const unmounted = MediaVolume(name: 'sd', generation: 3);
      expect(planVolume(baseline, unmounted), isA<SkipVolume>());
    });

    test('no baseline starts from now', () {
      const mounted = MediaVolume(name: 'sd', generation: 7, version: 'v1');
      expect(planVolume(null, mounted), isA<StartFromNow>());
    });

    test('a changed version resyncs', () {
      const changed = MediaVolume(name: 'sd', generation: 90, version: 'v2');
      expect(planVolume(baseline, changed), isA<Resync>());
    });

    test('a generation below the baseline resyncs', () {
      const behind = MediaVolume(name: 'sd', generation: 39, version: 'v1');
      expect(planVolume(baseline, behind), isA<Resync>());
    });

    test('otherwise scans after the baseline generation', () {
      const ahead = MediaVolume(name: 'sd', generation: 55, version: 'v1');
      expect(planVolume(baseline, ahead), const ScanAfter(40));

      const same = MediaVolume(name: 'sd', generation: 40, version: 'v1');
      expect(planVolume(baseline, same), const ScanAfter(40));
    });

    test('version compared by equality only', () {
      const b = VolumeBaseline(version: 'abcd', generation: 1);
      const sameLength = MediaVolume(
        name: 'sd',
        generation: 2,
        version: 'abce',
      );
      expect(planVolume(b, sameLength), isA<Resync>());

      // An equal string built at run time is the same version.
      final built = StringBuffer('ab')..write('cd');
      final equal = MediaVolume(
        name: 'sd',
        generation: 2,
        version: built.toString(),
      );
      expect(planVolume(b, equal), const ScanAfter(1));
    });

    test('ScanAfter compares by generation', () {
      // ScanAfter's constructor is const; this checks == is by value.
      // ignore: prefer_const_constructors
      expect(ScanAfter(5), ScanAfter(5));
      expect(const ScanAfter(5), isNot(const ScanAfter(6)));
      expect(const ScanAfter(5).hashCode, const ScanAfter(5).hashCode);
    });
  });

  group('advanceBaseline', () {
    MediaVideo row(int generation, {bool pending = false}) =>
        fakeVideo(id: generation, generation: generation, pending: pending);

    test('no rows → captured', () {
      expect(
        advanceBaseline(now: _now, from: 3, captured: 12, seen: const []),
        12,
      );
    });

    test('rows beyond captured → max row', () {
      expect(
        advanceBaseline(
          now: _now,
          from: 3,
          captured: 12,
          seen: [row(9), row(15), row(14)],
        ),
        15,
      );
    });

    test('rows below captured → captured', () {
      expect(
        advanceBaseline(
          now: _now,
          from: 3,
          captured: 12,
          seen: [row(4), row(8)],
        ),
        12,
      );
    });

    test('holds before the oldest pending row', () {
      expect(
        advanceBaseline(
          now: _now,
          from: 3,
          captured: 20,
          seen: [row(5), row(9, pending: true), row(7, pending: true), row(15)],
        ),
        6,
      );
    });

    test('never moves backwards', () {
      expect(
        advanceBaseline(
          now: _now,
          from: 5,
          captured: 20,
          seen: [row(2, pending: true), row(8)],
        ),
        5,
      );
    });

    test('a pending row at generation 0 or 1 never goes below from', () {
      expect(
        advanceBaseline(
          now: _now,
          from: 0,
          captured: 9,
          seen: [row(0, pending: true)],
        ),
        0,
      );
      expect(
        advanceBaseline(
          now: _now,
          from: 0,
          captured: 9,
          seen: [row(1, pending: true)],
        ),
        0,
      );
      expect(
        advanceBaseline(
          now: _now,
          from: 4,
          captured: 9,
          seen: [row(1, pending: true)],
        ),
        4,
      );
    });

    test('captured below from → from', () {
      expect(
        advanceBaseline(now: _now, from: 10, captured: 7, seen: const []),
        10,
      );
      expect(
        advanceBaseline(now: _now, from: 10, captured: 7, seen: [row(8)]),
        10,
      );
    });

    test('no rows and captured == from → from', () {
      expect(
        advanceBaseline(now: _now, from: 10, captured: 10, seen: const []),
        10,
      );
    });
  });

  group('holdsBaseline (late metadata, D-72)', () {
    // DATE_ADDED is in whole seconds: this row was added at exactly t.
    final t = DateTime.utc(2026, 6, 1, 9);
    MediaVideo added(
      DateTime at, {
      int? durationMs = 0,
      bool pending = false,
      int? dateAddedSec,
      int sizeBytes = 1000000,
    }) => fakeVideo(
      id: 1,
      pending: pending,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
      dateAddedSec: dateAddedSec ?? at.millisecondsSinceEpoch ~/ 1000,
    );
    const threeHours = Duration(hours: 3);
    const ms = Duration(milliseconds: 1);

    test('a pending row always holds', () {
      expect(
        holdsBaseline(
          added(t, pending: true),
          now: t.add(const Duration(days: 30)),
        ),
        isTrue,
      );
      expect(
        holdsBaseline(added(t, pending: true, durationMs: 5000), now: t),
        isTrue,
      );
    });

    test('a finished row without a length holds for exactly three hours', () {
      expect(holdsBaseline(added(t), now: t), isTrue);
      expect(holdsBaseline(added(t), now: t.add(threeHours)), isTrue);
      expect(holdsBaseline(added(t), now: t.add(threeHours + ms)), isFalse);
      expect(
        holdsBaseline(added(t, durationMs: null), now: t.add(threeHours)),
        isTrue,
      );
      expect(
        holdsBaseline(added(t, durationMs: null), now: t.add(threeHours + ms)),
        isFalse,
      );
    });

    test('a long recording whose row has no length is still held after an '
        'hour (I-4)', () {
      expect(
        holdsBaseline(added(t), now: t.add(const Duration(hours: 1))),
        isTrue,
      );
    });

    test('a finished row with an unknown size holds exactly like one without '
        'a length (I-1)', () {
      for (final size in [0, -1]) {
        final row = added(t, durationMs: 5000, sizeBytes: size);
        expect(holdsBaseline(row, now: t), isTrue, reason: 'size $size');
        expect(holdsBaseline(row, now: t.add(threeHours)), isTrue);
        expect(holdsBaseline(row, now: t.add(threeHours + ms)), isFalse);
        expect(
          holdsBaseline(row, now: t.subtract(const Duration(days: 1))),
          isTrue,
        );
        expect(
          holdsBaseline(
            row,
            now: t.subtract(const Duration(days: 1, seconds: 1)),
          ),
          isFalse,
          reason: 'DATE_ADDED more than a day ahead is not plausible',
        );
      }
    });

    test('an unknown size with an unknown DATE_ADDED does not hold', () {
      final row = fakeVideo(id: 1, sizeBytes: 0, dateAddedSec: null);
      expect(holdsBaseline(row, now: t), isFalse);
    });

    test('a finished row with a length never holds', () {
      expect(holdsBaseline(added(t, durationMs: 1), now: t), isFalse);
    });

    test('a row added in the future holds up to the one-day bound', () {
      const day = Duration(days: 1);
      expect(holdsBaseline(added(t.add(day)), now: t), isTrue);
      expect(
        holdsBaseline(added(t.add(day + const Duration(seconds: 1))), now: t),
        isFalse,
      );
    });

    test('an unknown or absurd DATE_ADDED does not hold', () {
      final row = fakeVideo(id: 1, durationMs: 0, dateAddedSec: null);
      expect(holdsBaseline(row, now: t), isFalse);
      expect(holdsBaseline(added(t, dateAddedSec: -1), now: t), isFalse);
      // Far too big: compared in seconds, so it cannot overflow into "now"
      // (times 1000 it would wrap around).
      expect(
        // The app never runs as JavaScript.
        // ignore: avoid_js_rounded_ints
        holdsBaseline(added(t, dateAddedSec: 9223372036854775), now: t),
        isFalse,
      );
    });

    test('advanceBaseline holds before a recent row without a length', () {
      final late = fakeVideo(
        id: 2,
        generation: 9,
        durationMs: 0,
        dateAddedSec: t.millisecondsSinceEpoch ~/ 1000,
      );
      final old = fakeVideo(id: 3, generation: 7, durationMs: 0);
      expect(
        advanceBaseline(from: 3, captured: 20, seen: [old, late], now: t),
        8,
      );
      expect(
        advanceBaseline(
          from: 3,
          captured: 20,
          seen: [old, late],
          now: t.add(threeHours + ms),
        ),
        20,
      );
      // A truncated scan holds before it too.
      expect(
        advanceBaseline(
          from: 3,
          captured: 20,
          seen: [old, late, fakeVideo(id: 4, generation: 15)],
          now: t,
          truncated: true,
        ),
        8,
      );
    });

    test('advanceBaseline holds before a recent row of unknown size (I-1)', () {
      final unknown = fakeVideo(
        id: 2,
        generation: 9,
        sizeBytes: 0,
        dateAddedSec: t.millisecondsSinceEpoch ~/ 1000,
      );
      final ok = fakeVideo(id: 3, generation: 12);
      expect(
        advanceBaseline(from: 3, captured: 20, seen: [unknown, ok], now: t),
        8,
      );
      expect(
        advanceBaseline(
          from: 3,
          captured: 20,
          seen: [unknown, ok],
          now: t.add(threeHours + ms),
        ),
        20,
      );
    });
  });

  group('truncated scans and paging', () {
    // Rows written in one transaction share a generation, so ids and
    // generations are given separately.
    MediaVideo at(int id, int generation, {bool pending = false}) =>
        fakeVideo(id: id, generation: generation, pending: pending);

    test(
      'a page cut inside a shared generation keeps the baseline below it',
      () {
        // Generation 12 has rows 4, 5 and 6; the limit of 4 cut after row 4.
        final page = [at(1, 11), at(2, 11), at(3, 11), at(4, 12)];
        expect(
          advanceBaseline(
            now: _now,
            from: 10,
            captured: 30,
            seen: page,
            truncated: true,
          ),
          11,
        );
        // Not truncated, the same rows move the baseline as before.
        expect(
          advanceBaseline(now: _now, from: 10, captured: 30, seen: page),
          30,
        );
      },
    );

    test(
      'a page all in one generation stalls the cursor and holds below it',
      () {
        final page = [at(1, 12), at(2, 12), at(3, 12)];
        expect(nextPageCursor(cursor: 10, page: page), isNull);
        expect(nextPageCursor(cursor: 11, page: page), isNull);
        expect(
          advanceBaseline(
            now: _now,
            from: 10,
            captured: 30,
            seen: page,
            truncated: true,
          ),
          11,
        );
      },
    );

    test(
      'a stuck pending row holds the baseline while the cursor moves on',
      () {
        // A recording pending at 11, then more rows than the limit (5).
        final first = [
          at(1, 11, pending: true),
          at(2, 12),
          at(3, 13),
          at(4, 14),
          at(5, 15),
        ];
        expect(
          advanceBaseline(
            now: _now,
            from: 10,
            captured: 40,
            seen: first,
            truncated: true,
          ),
          10,
        );
        expect(nextPageCursor(cursor: 10, page: first), 14);

        final second = [at(5, 15), at(6, 16), at(7, 17)];
        expect(nextPageCursor(cursor: 14, page: second), 16);
        // The whole scan, both pages, still holds before the pending row.
        expect(
          advanceBaseline(
            now: _now,
            from: 10,
            captured: 40,
            seen: [...first, ...second],
          ),
          10,
        );
      },
    );

    test('truncated with a pending row still holds before the pending row', () {
      // A pending row is never above the page's highest generation, so the
      // pending hold is always the lower of the two.
      final page = [at(1, 11), at(2, 12), at(3, 14, pending: true), at(4, 15)];
      expect(
        advanceBaseline(
          now: _now,
          from: 10,
          captured: 30,
          seen: page,
          truncated: true,
        ),
        13,
      );
      // The pending row is earlier.
      final early = [at(1, 11, pending: true), at(2, 12), at(3, 15)];
      expect(
        advanceBaseline(
          now: _now,
          from: 10,
          captured: 30,
          seen: early,
          truncated: true,
        ),
        10,
      );
    });

    test('truncated with no rows → from', () {
      expect(
        advanceBaseline(
          now: _now,
          from: 10,
          captured: 30,
          seen: const [],
          truncated: true,
        ),
        10,
      );
    });

    test('truncated never goes below from', () {
      expect(
        advanceBaseline(
          now: _now,
          from: 10,
          captured: 30,
          seen: [at(1, 8), at(2, 9)],
          truncated: true,
        ),
        10,
      );
      // A page whose highest generation is from + 1 holds at from.
      expect(
        advanceBaseline(
          now: _now,
          from: 10,
          captured: 30,
          seen: [at(1, 11)],
          truncated: true,
        ),
        10,
      );
    });

    test('nextPageCursor moves to one below the highest generation', () {
      expect(
        nextPageCursor(cursor: 10, page: [at(1, 11), at(2, 13), at(3, 12)]),
        12,
      );
      // One generation above the cursor: a page of rows at cursor + 1 only
      // stalls.
      expect(nextPageCursor(cursor: 10, page: [at(1, 11)]), isNull);
      expect(nextPageCursor(cursor: 10, page: [at(1, 11), at(2, 12)]), 11);
    });

    test('nextPageCursor never stays at or goes below the cursor', () {
      // Rows at or below the cursor should not come back from the query; if
      // they do, the cursor must not stay put or move back.
      expect(nextPageCursor(cursor: 12, page: [at(1, 11), at(2, 13)]), isNull);
      expect(nextPageCursor(cursor: 20, page: [at(1, 11), at(2, 13)]), isNull);
    });

    test('nextPageCursor of an empty page is null', () {
      expect(nextPageCursor(cursor: 10, page: const []), isNull);
    });
  });

  group('shotSinceSession (a volume with no baseline, D-108)', () {
    final since = DateTime.utc(2026, 6, 1, 8);

    MediaVideo shot(int id, DateTime? at, {int generation = 5}) => fakeVideo(
      id: id,
      generation: generation,
      dateTakenMs: at?.millisecondsSinceEpoch,
      dateAddedSec: null,
      dateModifiedSec: null,
    );

    List<int> ids(
      List<MediaVideo> rows, {
      DateTime? from,
      int captured = 9,
      bool noSession = false,
    }) => [
      for (final v in shotSinceSession(
        rows,
        since: noSession ? null : (from ?? since),
        captured: captured,
        now: _now,
      ))
        v.mediaStoreId,
    ];

    test('keeps the rows shot at or after the session start', () {
      expect(
        ids([
          shot(1, since.subtract(const Duration(milliseconds: 1))),
          shot(2, since),
          shot(3, since.add(const Duration(milliseconds: 1))),
        ]),
        [2, 3],
      );
    });

    test('no session start means nothing is kept (start from now)', () {
      expect(ids([shot(1, since)], noSession: true), isEmpty);
    });

    test('drops rows added after the captured generation, keeps the equal', () {
      expect(
        ids([shot(1, since, generation: 9), shot(2, since, generation: 10)]),
        [1],
      );
    });

    test('the shooting date is shotAt: an unknown DATE_TAKEN falls back to '
        'DATE_ADDED', () {
      final fromAdded = fakeVideo(
        id: 1,
        dateTakenMs: null,
        dateAddedSec: since.millisecondsSinceEpoch ~/ 1000,
      );
      final tooOld = fakeVideo(
        id: 2,
        dateTakenMs: null,
        dateAddedSec: since.millisecondsSinceEpoch ~/ 1000 - 1,
        dateModifiedSec: null,
      );

      expect(ids([fromAdded, tooOld]), [1]);
    });

    test('rows that hold the baseline are kept, for the baseline to see', () {
      final pending = fakeVideo(
        id: 1,
        generation: 6,
        pending: true,
        dateTakenMs: since.millisecondsSinceEpoch,
      );
      final noLength = fakeVideo(
        id: 2,
        generation: 7,
        durationMs: 0,
        dateTakenMs: since.millisecondsSinceEpoch,
        dateAddedSec: _now.millisecondsSinceEpoch ~/ 1000,
      );

      expect(ids([pending, noLength]), [1, 2]);
    });
  });
}
