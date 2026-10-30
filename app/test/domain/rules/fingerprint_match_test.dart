import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/clip_date.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';
import 'package:taketray/domain/rules/media_clip.dart';

import '../../support/fake_media_bridge.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);
  const primary = 'external_primary';
  const sd = '1a2b-3c4d';
  const takenMs = 1780000000000;
  final taken = DateTime.fromMillisecondsSinceEpoch(takenMs, isUtc: true);

  ClipFingerprint fp({
    int sizeBytes = 1000000,
    int durationMs = 5000,
    DateTime? date,
    String name = 'VID_1.mp4',
  }) => ClipFingerprint(
    sizeBytes: sizeBytes,
    durationMs: durationMs,
    dateTakenUtc: date ?? taken,
    displayName: name,
  );

  /// A stored clip that used to be MediaStore id [oldId] on [volume].
  Clip clip(
    int id,
    ClipFingerprint fingerprint, {
    int oldId = 1,
    String volume = primary,
  }) => Clip(
    id: id,
    source: ClipSource.mediaStore,
    fingerprint: fingerprint,
    width: 1920,
    height: 1080,
    mimeType: 'video/mp4',
    firstSeenAt: DateTime.utc(2026, 6),
    missing: false,
    mediaStoreId: oldId,
    volumeName: volume,
  );

  group('sameVideo', () {
    final v = fakeVideo(id: 7, name: 'VID_1.mp4');

    test('matches size, duration and shooting date', () {
      expect(sameVideo(fp(), v, now: now), isTrue);
    });

    test('sameVideo ignores display name', () {
      expect(sameVideo(fp(name: 'renamed.mp4'), v, now: now), isTrue);
    });

    test('sameVideo rejects one byte off / one ms off', () {
      expect(sameVideo(fp(sizeBytes: 1000001), v, now: now), isFalse);
      expect(sameVideo(fp(sizeBytes: 999999), v, now: now), isFalse);
      expect(sameVideo(fp(durationMs: 5001), v, now: now), isFalse);
      expect(sameVideo(fp(durationMs: 4999), v, now: now), isFalse);
      expect(
        sameVideo(
          fp(date: taken.add(const Duration(milliseconds: 1))),
          v,
          now: now,
        ),
        isFalse,
      );
      expect(
        sameVideo(
          fp(date: taken.subtract(const Duration(milliseconds: 1))),
          v,
          now: now,
        ),
        isFalse,
      );
    });

    test('compares the date with the fallback shooting date', () {
      final noTaken = fakeVideo(
        id: 7,
        dateTakenMs: null,
        dateAddedSec: 1780000123,
      );
      expect(
        sameVideo(
          fp(date: shotAt(noTaken, now: now)),
          noTaken,
          now: now,
        ),
        isTrue,
      );
      // The usual date (what DATE_TAKEN would have said) is not the date
      // this row is shot at, so it does not match.
      expect(sameVideo(fp(), noTaken, now: now), isFalse);
    });

    test('compares instants, not the UTC flag', () {
      expect(sameVideo(fp(date: taken.toLocal()), v, now: now), isTrue);
    });

    test('an unknown duration counts as 0', () {
      final noDuration = fakeVideo(id: 7, durationMs: null);
      expect(sameVideo(fp(durationMs: 0), noDuration, now: now), isTrue);
      expect(sameVideo(fp(), noDuration, now: now), isFalse);
    });

    test('a zero size never matches (Android did not know the size)', () {
      final noSize = fakeVideo(id: 7, sizeBytes: 0);
      expect(sameVideo(fp(sizeBytes: 0), noSize, now: now), isFalse);
    });
  });

  group('matchAfterRebuild', () {
    test('single candidate remaps', () {
      final result = matchAfterRebuild(
        [clip(10, fp(), oldId: 5)],
        [fakeVideo(id: 77, name: 'VID_1.mp4'), fakeVideo(id: 78, sizeBytes: 9)],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, {10: 77});
      expect(result.lost, isEmpty);
    });

    test('a renamed video still remaps', () {
      final result = matchAfterRebuild(
        [clip(10, fp(name: 'old.mp4'))],
        [fakeVideo(id: 77, name: 'new.mp4')],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, {10: 77});
      expect(result.lost, isEmpty);
    });

    test('two candidates, one same name → remap to that one', () {
      final result = matchAfterRebuild(
        [clip(10, fp(name: 'b.mp4'))],
        [fakeVideo(id: 77, name: 'a.mp4'), fakeVideo(id: 78, name: 'b.mp4')],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, {10: 78});
      expect(result.lost, isEmpty);
    });

    test('two candidates, both same name → lost', () {
      final result = matchAfterRebuild(
        [clip(10, fp(name: 'b.mp4'))],
        [fakeVideo(id: 77, name: 'b.mp4'), fakeVideo(id: 78, name: 'b.mp4')],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10});
    });

    test('two candidates, neither same name → lost', () {
      final result = matchAfterRebuild(
        [clip(10, fp(name: 'c.mp4'))],
        [fakeVideo(id: 77, name: 'a.mp4'), fakeVideo(id: 78, name: 'b.mp4')],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10});
    });

    test('three candidates, two with the same name → lost', () {
      final result = matchAfterRebuild(
        [clip(10, fp(name: 'b.mp4'))],
        [
          fakeVideo(id: 77, name: 'a.mp4'),
          fakeVideo(id: 78, name: 'b.mp4'),
          fakeVideo(id: 79, name: 'b.mp4'),
        ],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10});
    });

    test('two clips claim one video → both lost', () {
      final result = matchAfterRebuild(
        [clip(10, fp(), oldId: 3), clip(11, fp(), oldId: 4)],
        [fakeVideo(id: 77, name: 'VID_1.mp4')],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10, 11});
    });

    test('two clips claim one video through the name → both lost', () {
      final result = matchAfterRebuild(
        [clip(10, fp(name: 'b.mp4')), clip(11, fp(name: 'b.mp4'))],
        [fakeVideo(id: 77, name: 'a.mp4'), fakeVideo(id: 78, name: 'b.mp4')],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10, 11});
    });

    test("another clip's ambiguity does not take a sole candidate away", () {
      // Clip 10 has one candidate (77). Clip 11 has two equally good ones
      // (77 and 78), so it claims nothing and is lost; 77 is claimed once.
      final result = matchAfterRebuild(
        [
          clip(10, fp(sizeBytes: 500, name: 'x.mp4')),
          clip(11, fp(name: 'z.mp4')),
        ],
        [
          fakeVideo(id: 77, sizeBytes: 500, name: 'x.mp4'),
          fakeVideo(id: 78, name: 'p.mp4'),
          fakeVideo(id: 79, name: 'q.mp4'),
        ],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, {10: 77});
      expect(result.lost, {11});
    });

    test('pending or zero-duration candidates ignored', () {
      // The only candidate is pending, or has no length: lost.
      expect(
        matchAfterRebuild(
          [clip(10, fp())],
          [fakeVideo(id: 77, name: 'VID_1.mp4', pending: true)],
          volumeName: primary,
          now: now,
        ).lost,
        {10},
      );
      expect(
        matchAfterRebuild(
          [clip(10, fp(durationMs: 0))],
          [fakeVideo(id: 77, name: 'VID_1.mp4', durationMs: 0)],
          volumeName: primary,
          now: now,
        ).lost,
        {10},
      );

      // They do not make a real candidate ambiguous either.
      final result = matchAfterRebuild(
        [clip(10, fp())],
        [
          fakeVideo(id: 76, name: 'VID_1.mp4', pending: true),
          fakeVideo(id: 77, name: 'VID_1.mp4'),
        ],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, {10: 77});
      expect(result.lost, isEmpty);
    });

    test('a zero-duration clip against an unknown duration is lost', () {
      // sameVideo treats the unknown duration as 0, but a row without a
      // length is not usable, so it is never a candidate.
      final result = matchAfterRebuild(
        [clip(10, fp(durationMs: 0))],
        [fakeVideo(id: 77, name: 'VID_1.mp4', durationMs: null)],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10});
    });

    test('no candidate → lost', () {
      final result = matchAfterRebuild(
        [clip(10, fp(sizeBytes: 1))],
        [fakeVideo(id: 77)],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10});
    });

    test('a row on another volume is never a candidate', () {
      final result = matchAfterRebuild(
        [clip(10, fp())],
        [fakeVideo(id: 77, volume: sd, name: 'VID_1.mp4')],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10});
    });

    test('the same id on another volume does not make a match ambiguous', () {
      final result = matchAfterRebuild(
        [clip(10, fp())],
        [
          fakeVideo(id: 77, volume: sd, name: 'VID_1.mp4'),
          fakeVideo(id: 77, name: 'VID_1.mp4'),
        ],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, {10: 77});
      expect(result.lost, isEmpty);
    });

    test('a clip from another volume throws', () {
      // A silent "lost" would mark a good clip on another volume missing.
      expect(
        () => matchAfterRebuild(
          [clip(10, fp()), clip(11, fp(), volume: sd)],
          [fakeVideo(id: 77, name: 'VID_1.mp4')],
          volumeName: primary,
          now: now,
        ),
        throwsArgumentError,
      );
      // A picked clip has no volume at all.
      final picked = clip(12, fp()).copyWith(
        source: ClipSource.picker,
        volumeName: null,
        mediaStoreId: null,
        pickerUri: 'content://picked/12',
      );
      expect(picked.volumeName, isNull);
      expect(
        () => matchAfterRebuild(
          [picked],
          const [],
          volumeName: primary,
          now: now,
        ),
        throwsArgumentError,
      );
    });

    test('an empty stored list gives an empty result', () {
      final result = matchAfterRebuild(
        const [],
        [fakeVideo(id: 77)],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, isEmpty);
    });

    test('an empty current list loses every clip', () {
      final result = matchAfterRebuild(
        [clip(10, fp()), clip(11, fp(sizeBytes: 3))],
        const [],
        volumeName: primary,
        now: now,
      );
      expect(result.remap, isEmpty);
      expect(result.lost, {10, 11});
    });

    test('every stored clip is in exactly one set', () {
      const names = ['a.mp4', 'b.mp4', 'c.mp4'];
      final rng = Random(20261028);
      var remapped = 0;
      var lost = 0;

      for (var round = 0; round < 200; round++) {
        // A small pool of values, so that equal fingerprints and equal names
        // happen often. Every row has its own id; some rows are on the SD
        // card and must be ignored.
        int size() => 1 + rng.nextInt(2);
        int? duration() => [null, 0, 1000, 2000][rng.nextInt(4)];
        int date() => takenMs + rng.nextInt(2);

        final videoCount = rng.nextInt(12);
        final clipCount = rng.nextInt(8);
        final current = [
          for (var i = 0; i < videoCount; i++)
            fakeVideo(
              id: 100 + i,
              volume: rng.nextInt(4) == 0 ? sd : primary,
              sizeBytes: size(),
              durationMs: duration(),
              dateTakenMs: date(),
              name: names[rng.nextInt(3)],
              pending: rng.nextInt(5) == 0,
            ),
        ];
        final stored = [
          for (var id = 1; id <= clipCount; id++)
            clip(
              id,
              fp(
                sizeBytes: size(),
                durationMs: duration() ?? 0,
                date: DateTime.fromMillisecondsSinceEpoch(date(), isUtc: true),
                name: names[rng.nextInt(3)],
              ),
            ),
        ];

        final result = matchAfterRebuild(
          stored,
          current,
          volumeName: primary,
          now: now,
        );
        final ids = {for (final c in stored) c.id};
        final reason = 'round $round';

        expect(
          result.remap.keys.toSet().intersection(result.lost),
          isEmpty,
          reason: reason,
        );
        expect(
          result.remap.keys.toSet().union(result.lost),
          ids,
          reason: reason,
        );

        // An independent oracle: a clip's candidates, and the ones of them
        // that keep its name.
        List<MediaVideo> candidatesOf(Clip c) => [
          for (final v in current)
            if (v.volumeName == primary &&
                isUsable(v) &&
                sameVideo(c.fingerprint, v, now: now))
              v,
        ];
        List<MediaVideo> namedOf(Clip c) => [
          for (final v in candidatesOf(c))
            if (v.displayName == c.fingerprint.displayName) v,
        ];
        int? pickOf(Clip c) {
          final all = candidatesOf(c);
          if (all.length == 1) return all.single.mediaStoreId;
          final named = namedOf(c);
          if (all.length > 1 && named.length == 1) {
            return named.single.mediaStoreId;
          }
          return null;
        }

        final claims = <int, int>{};
        for (final c in stored) {
          final pick = pickOf(c);
          if (pick != null) claims[pick] = (claims[pick] ?? 0) + 1;
        }

        final given = <int>{};
        for (final c in stored) {
          final all = candidatesOf(c);
          final named = namedOf(c);
          final newId = result.remap[c.id];
          if (newId != null) {
            // No row is given to two clips.
            expect(given.add(newId), isTrue, reason: reason);
            // It was the clip's only candidate, or its only one by name.
            final sole = all.length == 1 && all.single.mediaStoreId == newId;
            final soleByName =
                all.length > 1 &&
                named.length == 1 &&
                named.single.mediaStoreId == newId;
            expect(sole || soleByName, isTrue, reason: reason);
            expect(claims[newId], 1, reason: reason);
          } else {
            // Lost only when ambiguous, without a candidate, or when its one
            // pick was claimed by another clip too.
            final pick = pickOf(c);
            expect(
              pick == null || claims[pick]! >= 2,
              isTrue,
              reason: '$reason: clip ${c.id} lost without a reason',
            );
          }
        }
        remapped += result.remap.length;
        lost += result.lost.length;
      }

      // The cases must exercise both outcomes, or the loop proves nothing.
      expect(remapped, greaterThan(20));
      expect(lost, greaterThan(20));
    });
  });
}
