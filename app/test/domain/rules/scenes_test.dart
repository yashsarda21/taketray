import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/rules/scenes.dart';

import '../../support/clips.dart';

/// A clip [id] shot at [utc], [seconds] long.
Clip clip(int id, DateTime utc, {int seconds = 5}) =>
    testClip(id, shot: utc, durationMs: seconds * 1000);

/// [utc] as seen in a zone [offset] ahead of UTC.
ClipLocalTime at(DateTime utc, Duration offset) => ClipLocalTime(
  wallClock: utc.add(offset),
  zoneId: 'X/Y',
  isPhoneZone: false,
);

/// Every clip's wall clock is its UTC time (a zone at UTC+0).
Map<int, ClipLocalTime> utcTimes(List<Clip> clips) => {
  for (final c in clips) c.id: at(c.fingerprint.dateTakenUtc, Duration.zero),
};

/// The scenes as lists of clip ids.
List<List<int>> ids(List<Scene> scenes) => [
  for (final s in scenes) [for (final c in s.clips) c.id],
];

final DateTime t0 = DateTime.utc(2026, 10, 28, 10);

void main() {
  group('groupIntoScenes', () {
    test('one clip is one scene', () {
      final c = clip(1, t0);

      final scenes = groupIntoScenes([c], utcTimes([c]));

      expect(ids(scenes), [
        [1],
      ]);
      expect(scenes.single.start, t0);
      expect(scenes.single.end, t0);
      expect(scenes.single.day, DateTime.utc(2026, 10, 28));
    });

    test('no clips are no scenes', () {
      expect(groupIntoScenes(const [], const {}), isEmpty);
    });

    test("gap is measured from the previous clip's end", () {
      // 1 starts 10:00:00 and runs 5 min, so it ends 10:05:00. 2 starts at
      // 10:12: 12 min after 1's start (start-to-start would split) but only
      // 7 min after its end, so they stay together.
      final a = clip(1, t0, seconds: 300);
      final b = clip(2, t0.add(const Duration(minutes: 12)));

      expect(ids(groupIntoScenes([a, b], utcTimes([a, b]))), [
        [1, 2],
      ]);
    });

    test('exactly 10 minutes starts a new scene', () {
      final a = clip(1, t0, seconds: 60);
      final b = clip(2, t0.add(const Duration(minutes: 11)));

      expect(ids(groupIntoScenes([a, b], utcTimes([a, b]))), [
        [1],
        [2],
      ]);
    });

    test('9 minutes 59 seconds stays', () {
      final a = clip(1, t0, seconds: 60);
      final b = clip(2, t0.add(const Duration(minutes: 10, seconds: 59)));

      expect(ids(groupIntoScenes([a, b], utcTimes([a, b]))), [
        [1, 2],
      ]);
    });

    test('the gap can be changed', () {
      final a = clip(1, t0);
      final b = clip(2, t0.add(const Duration(minutes: 3)));

      expect(
        ids(
          groupIntoScenes(
            [a, b],
            utcTimes([a, b]),
            gap: const Duration(minutes: 2),
          ),
        ),
        [
          [1],
          [2],
        ],
      );
    });

    test('overlapping clips stay together', () {
      // 1 runs 20 min; 2 starts 5 min in, so the gap is negative.
      final a = clip(1, t0, seconds: 1200);
      final b = clip(2, t0.add(const Duration(minutes: 5)));

      expect(ids(groupIntoScenes([a, b], utcTimes([a, b]))), [
        [1, 2],
      ]);
    });

    test('midnight splits a scene', () {
      // 23:55 and 00:02 are 7 minutes apart: the gap alone would join them.
      final a = clip(1, DateTime.utc(2026, 10, 28, 23, 55));
      final b = clip(2, DateTime.utc(2026, 10, 29, 0, 2));

      final scenes = groupIntoScenes([a, b], utcTimes([a, b]));

      expect(ids(scenes), [
        [1],
        [2],
      ]);
      expect(scenes[0].day, DateTime.utc(2026, 10, 28));
      expect(scenes[1].day, DateTime.utc(2026, 10, 29));
    });

    test("zones use the shot zone's day", () {
      // 22:55 UTC in London (day 28) then 23:03 UTC in India (04:33 on the
      // 29th): 8 minutes apart on UTC, a different day where each was shot.
      final a = clip(1, DateTime.utc(2026, 10, 28, 22, 55));
      final b = clip(2, DateTime.utc(2026, 10, 28, 23, 3));
      final split = groupIntoScenes(
        [a, b],
        {
          1: at(a.fingerprint.dateTakenUtc, Duration.zero),
          2: at(
            b.fingerprint.dateTakenUtc,
            const Duration(hours: 5, minutes: 30),
          ),
        },
      );
      expect(ids(split), [
        [1],
        [2],
      ]);
      expect(split[1].day, DateTime.utc(2026, 10, 29));
      expect(split[1].start, DateTime.utc(2026, 10, 29, 4, 33));

      // 23:55 UTC in London (day 28) then 00:02 UTC on the 29th in New York
      // (19:02 on the 28th): different UTC days, the same day where shot.
      final c = clip(3, DateTime.utc(2026, 10, 28, 23, 55));
      final d = clip(4, DateTime.utc(2026, 10, 29, 0, 2));
      final joined = groupIntoScenes(
        [c, d],
        {
          3: at(c.fingerprint.dateTakenUtc, Duration.zero),
          4: at(d.fingerprint.dateTakenUtc, const Duration(hours: -5)),
        },
      );
      expect(ids(joined), [
        [3, 4],
      ]);
      expect(joined.single.day, DateTime.utc(2026, 10, 28));
    });

    test("unknown time uses the phone's local day", () {
      // Built from local times, so the answer does not depend on the zone
      // the test runs in: 23:55 and 00:02 on the phone's clock. July, so that
      // under TZ=Europe/London (BST, UTC+1) the local fields differ from the
      // UTC ones; a copy of the UTC fields would join the two clips (22:55 and
      // 23:02 UTC, one UTC day) and fail there.
      final a = clip(1, DateTime(2026, 7, 15, 23, 55).toUtc());
      final b = clip(2, DateTime(2026, 7, 16, 0, 2).toUtc());

      final scenes = groupIntoScenes([a, b], const {});

      expect(ids(scenes), [
        [1],
        [2],
      ]);
      // Wall-clock values: UTC-flagged, holding the phone's local fields.
      expect(scenes[0].start, DateTime.utc(2026, 7, 15, 23, 55));
      expect(scenes[0].start.isUtc, isTrue);
      expect(scenes[0].day, DateTime.utc(2026, 7, 15));
      expect(scenes[1].start, DateTime.utc(2026, 7, 16, 0, 2));
      expect(scenes[1].day, DateTime.utc(2026, 7, 16));
    });

    test('equal times keep id order', () {
      final a = clip(3, t0);
      final b = clip(1, t0);
      final c = clip(2, t0);

      expect(ids(groupIntoScenes([a, b, c], utcTimes([a, b, c]))), [
        [1, 2, 3],
      ]);
    });

    test('clips are put in shooting order first', () {
      final late = clip(1, t0.add(const Duration(minutes: 30)));
      final early = clip(2, t0);

      final scenes = groupIntoScenes([late, early], utcTimes([late, early]));

      expect(ids(scenes), [
        [2],
        [1],
      ]);
    });

    test('range is first start to last start', () {
      final a = clip(1, t0, seconds: 600);
      final b = clip(2, t0.add(const Duration(minutes: 3)), seconds: 900);
      final c = clip(3, t0.add(const Duration(minutes: 9)), seconds: 600);

      final scene = groupIntoScenes([a, b, c], utcTimes([a, b, c])).single;

      expect(scene.start, t0);
      expect(scene.end, t0.add(const Duration(minutes: 9)));
    });

    test('does not change the lists it is given', () {
      final late = clip(1, t0.add(const Duration(hours: 1)));
      final early = clip(2, t0);
      final given = [late, early];

      groupIntoScenes(given, utcTimes(given));

      expect([for (final c in given) c.id], [1, 2]);
    });
  });
}
