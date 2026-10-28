import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/baseline.dart';

import '../../support/fake_media_bridge.dart';

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
      expect(advanceBaseline(from: 3, captured: 12, seen: const []), 12);
    });

    test('rows beyond captured → max row', () {
      expect(
        advanceBaseline(
          from: 3,
          captured: 12,
          seen: [row(9), row(15), row(14)],
        ),
        15,
      );
    });

    test('rows below captured → captured', () {
      expect(
        advanceBaseline(from: 3, captured: 12, seen: [row(4), row(8)]),
        12,
      );
    });

    test('holds before the oldest pending row', () {
      expect(
        advanceBaseline(
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
          from: 5,
          captured: 20,
          seen: [row(2, pending: true), row(8)],
        ),
        5,
      );
    });

    test('a pending row at generation 0 or 1 never goes below from', () {
      expect(
        advanceBaseline(from: 0, captured: 9, seen: [row(0, pending: true)]),
        0,
      );
      expect(
        advanceBaseline(from: 0, captured: 9, seen: [row(1, pending: true)]),
        0,
      );
      expect(
        advanceBaseline(from: 4, captured: 9, seen: [row(1, pending: true)]),
        4,
      );
    });

    test('captured below from → from', () {
      expect(advanceBaseline(from: 10, captured: 7, seen: const []), 10);
      expect(advanceBaseline(from: 10, captured: 7, seen: [row(8)]), 10);
    });

    test('no rows and captured == from → from', () {
      expect(advanceBaseline(from: 10, captured: 10, seen: const []), 10);
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
          advanceBaseline(from: 10, captured: 30, seen: page, truncated: true),
          11,
        );
        // Not truncated, the same rows move the baseline as before.
        expect(advanceBaseline(from: 10, captured: 30, seen: page), 30);
      },
    );

    test(
      'a page all in one generation stalls the cursor and holds below it',
      () {
        final page = [at(1, 12), at(2, 12), at(3, 12)];
        expect(nextPageCursor(cursor: 10, page: page), isNull);
        expect(nextPageCursor(cursor: 11, page: page), isNull);
        expect(
          advanceBaseline(from: 10, captured: 30, seen: page, truncated: true),
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
          advanceBaseline(from: 10, captured: 40, seen: first, truncated: true),
          10,
        );
        expect(nextPageCursor(cursor: 10, page: first), 14);

        final second = [at(5, 15), at(6, 16), at(7, 17)];
        expect(nextPageCursor(cursor: 14, page: second), 16);
        // The whole scan, both pages, still holds before the pending row.
        expect(
          advanceBaseline(from: 10, captured: 40, seen: [...first, ...second]),
          10,
        );
      },
    );

    test('truncated with a pending row still holds before the pending row', () {
      // A pending row is never above the page's highest generation, so the
      // pending hold is always the lower of the two.
      final page = [at(1, 11), at(2, 12), at(3, 14, pending: true), at(4, 15)];
      expect(
        advanceBaseline(from: 10, captured: 30, seen: page, truncated: true),
        13,
      );
      // The pending row is earlier.
      final early = [at(1, 11, pending: true), at(2, 12), at(3, 15)];
      expect(
        advanceBaseline(from: 10, captured: 30, seen: early, truncated: true),
        10,
      );
    });

    test('truncated with no rows → from', () {
      expect(
        advanceBaseline(
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
}
