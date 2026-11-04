import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/rules/skipped_days.dart';

import '../../support/clips.dart';

/// [utc] as seen in a zone [offset] ahead of UTC.
ClipLocalTime at(DateTime utc, Duration offset) => ClipLocalTime(
  wallClock: utc.add(offset),
  zoneId: 'X/Y',
  isPhoneZone: false,
);

Map<int, ClipLocalTime> utcTimes(List<Clip> clips) => {
  for (final c in clips) c.id: at(c.fingerprint.dateTakenUtc, Duration.zero),
};

/// The days as "date: clip ids".
List<String> shape(List<SkippedDay> days) => [
  for (final d in days) _describe(d),
];

String _describe(SkippedDay d) {
  final date = d.day.toIso8601String().substring(0, 10);
  return '$date: ${d.clips.map((c) => c.id).toList()}';
}

void main() {
  group('groupIntoDays', () {
    test('newest day first, newest clip first inside a day', () {
      final clips = [
        testClip(1, shot: DateTime.utc(2026, 10, 27, 10)),
        testClip(2, shot: DateTime.utc(2026, 10, 28, 9)),
        testClip(3, shot: DateTime.utc(2026, 10, 28, 15)),
        testClip(4, shot: DateTime.utc(2026, 10, 29, 12)),
      ];

      final days = groupIntoDays(clips, utcTimes(clips));

      expect(shape(days), [
        '2026-10-29: [4]',
        '2026-10-28: [3, 2]',
        '2026-10-27: [1]',
      ]);
    });

    test('the input order does not matter', () {
      final clips = [
        testClip(3, shot: DateTime.utc(2026, 10, 28, 15)),
        testClip(1, shot: DateTime.utc(2026, 10, 27, 10)),
        testClip(2, shot: DateTime.utc(2026, 10, 28, 9)),
      ];

      expect(
        [
          for (final d in groupIntoDays(clips, utcTimes(clips)))
            [for (final c in d.clips) c.id],
        ],
        [
          [3, 2],
          [1],
        ],
      );
    });

    test('equal times: the higher id comes first', () {
      final t = DateTime.utc(2026, 10, 28, 12);
      final clips = [testClip(1, shot: t), testClip(2, shot: t)];

      expect(
        groupIntoDays(clips, utcTimes(clips)).single.clips.map((c) => c.id),
        [2, 1],
      );
    });

    test('no clips are no days', () {
      expect(groupIntoDays(const [], const {}), isEmpty);
    });

    test('the day is the day where the clip was shot', () {
      // 23:30 UTC on the 28th is already the 29th in India (UTC+5:30), and
      // 00:30 UTC on the 29th is still the 28th in New York (UTC-4).
      final india = testClip(1, shot: DateTime.utc(2026, 10, 28, 23, 30));
      final newYork = testClip(2, shot: DateTime.utc(2026, 10, 29, 0, 30));
      final times = {
        1: at(
          india.fingerprint.dateTakenUtc,
          const Duration(hours: 5, minutes: 30),
        ),
        2: at(newYork.fingerprint.dateTakenUtc, const Duration(hours: -4)),
      };

      final days = groupIntoDays([india, newYork], times);

      expect(shape(days), ['2026-10-29: [1]', '2026-10-28: [2]']);
    });

    test('a date is one day, whatever the zones: no day twice', () {
      // Shot in India at 07:00 on the 29th (01:30 UTC), in New York at 21:00
      // on the 29th (01:00 UTC on the 30th), and in India at 18:00 on the
      // 29th (12:30 UTC). By instant they interleave with the 28th's clip.
      final a = testClip(1, shot: DateTime.utc(2026, 10, 29, 1, 30));
      final b = testClip(2, shot: DateTime.utc(2026, 10, 29, 12, 30));
      final c = testClip(3, shot: DateTime.utc(2026, 10, 30, 1));
      final other = testClip(4, shot: DateTime.utc(2026, 10, 29, 6));
      final times = {
        1: at(
          a.fingerprint.dateTakenUtc,
          const Duration(hours: 5, minutes: 30),
        ),
        2: at(
          b.fingerprint.dateTakenUtc,
          const Duration(hours: 5, minutes: 30),
        ),
        3: at(c.fingerprint.dateTakenUtc, const Duration(hours: -4)),
        // Shot on the 28th in Honolulu (UTC-10): 20:00.
        4: at(other.fingerprint.dateTakenUtc, const Duration(hours: -10)),
      };

      final days = groupIntoDays([a, b, c, other], times);

      expect(shape(days), ['2026-10-29: [3, 2, 1]', '2026-10-28: [4]']);
    });

    test("a clip with no time uses the phone's day, and is not dropped", () {
      final local = DateTime(2026, 10, 28, 12);
      final clip = testClip(1, shot: local);

      final days = groupIntoDays([clip], const {});

      expect(days.single.day, DateTime.utc(2026, 10, 28));
      expect(days.single.clips.single.id, 1);
    });

    test('the lists cannot be changed', () {
      final clips = [testClip(1)];
      final days = groupIntoDays(clips, utcTimes(clips));

      expect(() => days.add(days.first), throwsUnsupportedError);
      expect(() => days.first.clips.add(clips.first), throwsUnsupportedError);
    });
  });
}
