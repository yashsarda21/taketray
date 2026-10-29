import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/domain/rules/earlier_window.dart';

import '../../support/fake_media_bridge.dart';
import 'media_harness.dart';

/// True when the test runs in Europe/London (`TZ=Europe/London`); see
/// `test/domain/rules/earlier_window_test.dart`.
bool get _inLondon {
  const hour = Duration(hours: 1);
  return DateTime(2026, 10, 24, 12).timeZoneOffset == hour &&
      DateTime(2026, 10, 26, 12).timeZoneOffset == Duration.zero &&
      DateTime(2027, 3, 27, 12).timeZoneOffset == Duration.zero &&
      DateTime(2027, 3, 29, 12).timeZoneOffset == hour;
}

/// tool/check runs this file a second time with `TZ=Europe/London` and
/// `--run-skipped` (D-69), so on CI these tests always run.
final Object _londonOnly = _inLondon
    ? false
    : 'needs TZ=Europe/London; tool/check runs it so';

/// A finished video shot at [when] (every MediaStore date set to it), with
/// MediaStore id [id] and generation [id].
MediaVideo shot(
  int id,
  DateTime when, {
  String volume = phone,
  String folder = 'DCIM/Camera/',
  bool pending = false,
  int? durationMs = 5000,
  int? sizeBytes,
}) => fakeVideo(
  id: id,
  generation: id,
  volume: volume,
  folder: folder,
  pending: pending,
  durationMs: durationMs,
  sizeBytes: sizeBytes ?? 1000000 + id,
  dateTakenMs: when.millisecondsSinceEpoch,
  dateAddedSec: when.millisecondsSinceEpoch ~/ 1000,
  dateModifiedSec: when.millisecondsSinceEpoch ~/ 1000,
);

const EarlierRange today = EarlierToday();

/// The days [from] to [to] of June 2026 (day numbers), both included.
EarlierRange june(int from, int to) =>
    EarlierCustom(DateTime(2026, 6, from), DateTime(2026, 6, to));

// 15:00 local time on 2026-06-10.
final DateTime _nowLocal = DateTime(2026, 6, 10, 15);

// Today twice, yesterday, five days ago, eight days ago.
final MediaVideo today1 = shot(1, DateTime(2026, 6, 10, 10));
final MediaVideo today2 = shot(2, DateTime(2026, 6, 10, 12));
final MediaVideo yesterday = shot(3, DateTime(2026, 6, 9, 10));
final MediaVideo fiveDaysAgo = shot(4, DateTime(2026, 6, 5, 10));
final MediaVideo eightDaysAgo = shot(5, DateTime(2026, 6, 2, 10));

MediaHarness? _built;

/// The test's harness at 15:00 on 2026-06-10, with the five videos above on
/// the phone. Built on first use, so a test that makes its own harness (at
/// another time) never has two databases open.
MediaHarness get h =>
    _built ??= MediaHarness(now: _nowLocal.toUtc())
      ..bridge.put([today1, today2, yesterday, fiveDaysAgo, eightDaysAgo]);

RecordingBridge get bridge => h.bridge;

ReelsRepository get reels => ReelsRepository(h.db, h.clock);

void main() {
  setUp(() => _built = null);

  Future<List<int?>> toTagIds() async => [
    for (final c in await h.toTag()) c.mediaStoreId,
  ];

  Future<int> clipIdOf(MediaVideo v) async => (await h.allClips())
      .singleWhere((c) => c.mediaStoreId == v.mediaStoreId)
      .id;

  group('Today', () {
    test('counts only the videos shot today, and writes nothing', () async {
      expect(await h.scanner.countEarlier(), 2);
      expect(
        bridge.count('videosShotSince'),
        1,
        reason: 'one query per volume',
      );
      expect(await h.allClips(), isEmpty, reason: 'counting writes nothing');
    });

    test('the count excludes known clips', () async {
      await h.store([today1, yesterday, fiveDaysAgo]);
      // today1 waits in To tag, yesterday is skipped, fiveDaysAgo is tagged.
      await h.clips.skip([await clipIdOf(yesterday)]);
      final reel = await reels.create('Goa');
      await h.clips.tagClip(await clipIdOf(fiveDaysAgo), {reel.id});

      expect(await h.scanner.countEarlier(), 1);
    });

    test(
      "addEarlier(today) adds only today's new videos and returns their ids",
      () async {
        bridge.currentZone = 'Asia/Kolkata';

        final ids = await h.scanner.addEarlier(today);

        expect(ids, hasLength(2));
        final added = await h.toTag();
        expect({for (final c in added) c.id}, ids.toSet());
        expect({for (final c in added) c.mediaStoreId}, {1, 2});
        expect({for (final c in added) c.timeZoneId}, {'Asia/Kolkata'});
        expect(await h.scanner.countEarlier(), 0);
      },
    );

    test('countEarlierIn(today) is the same as countEarlier', () async {
      expect(await h.scanner.countEarlierIn(today), 2);
    });

    test("at 00:05, today does not include yesterday's 23:59", () async {
      final h = MediaHarness(now: DateTime(2026, 6, 10, 0, 5).toUtc());
      h.bridge.put([
        shot(1, DateTime(2026, 6, 9, 23, 59)),
        shot(2, DateTime(2026, 6, 10, 0, 1)),
      ]);

      expect(await h.scanner.countEarlier(), 1);
      await h.scanner.addEarlier(today);
      expect([for (final c in await h.toTag()) c.mediaStoreId], [2]);
    });
  });

  group('a chosen date range', () {
    test('counts the videos shot on those days, both days included', () async {
      // yesterday (9th) only; today and the older videos are outside.
      expect(await h.scanner.countEarlierIn(june(9, 9)), 1);
      // the 5th to the 9th: yesterday and five days ago.
      expect(await h.scanner.countEarlierIn(june(5, 9)), 2);
      // the 5th to today.
      expect(await h.scanner.countEarlierIn(june(5, 10)), 4);
      // the 2nd to the 5th: the oldest two.
      expect(await h.scanner.countEarlierIn(june(2, 5)), 2);
      // nothing was shot on the 3rd or 4th.
      expect(await h.scanner.countEarlierIn(june(3, 4)), 0);
      expect(await h.allClips(), isEmpty, reason: 'counting writes nothing');
    });

    test('a video after the last day is not counted or added', () async {
      expect(await h.scanner.countEarlierIn(june(5, 9)), 2);
      final ids = await h.scanner.addEarlier(june(5, 9));

      expect(ids, hasLength(2));
      expect(await toTagIds(), unorderedEquals([3, 4]), reason: 'not today');
    });

    test(
      'the last day ends at its midnight: 23:59:59.999 in, 00:00 out',
      () async {
        bridge.put([
          shot(6, DateTime(2026, 6, 9, 23, 59, 59, 999)),
          shot(7, DateTime(2026, 6, 10)),
          shot(8, DateTime(2026, 6, 8, 23, 59, 59, 999)),
        ]);

        // The 9th only: yesterday, plus 6 (23:59:59.999 on the 9th); not 7
        // (00:00 on the 10th) and not 8 (the 8th).
        expect(await h.scanner.countEarlierIn(june(9, 9)), 2);
        await h.scanner.addEarlier(june(9, 9));
        expect(await toTagIds(), unorderedEquals([3, 6]));
      },
    );

    test('the first day starts at its midnight: 00:00 in, the second before is '
        'out', () async {
      bridge.put([
        shot(6, DateTime(2026, 6, 9)),
        shot(7, DateTime(2026, 6, 8, 23, 59, 59, 999)),
      ]);

      await h.scanner.addEarlier(june(9, 9));

      expect(await toTagIds(), unorderedEquals([3, 6]));
    });

    test('the count is what addEarlier adds, for every range', () async {
      for (final range in [june(9, 9), june(5, 9), june(2, 10), june(3, 4)]) {
        final count = await h.scanner.countEarlierIn(range);
        final ids = await h.scanner.addEarlier(range);
        expect(ids, hasLength(count), reason: '$range');
        // The same range now finds nothing: those are known.
        expect(await h.scanner.countEarlierIn(range), 0, reason: '$range');
      }
    });

    test('known clips (to tag, skipped, tagged) are not counted', () async {
      await h.store([yesterday, fiveDaysAgo, eightDaysAgo]);
      // yesterday waits in To tag, fiveDaysAgo is skipped, eightDaysAgo is
      // tagged.
      await h.clips.skip([await clipIdOf(fiveDaysAgo)]);
      final reel = await reels.create('Goa');
      await h.clips.tagClip(await clipIdOf(eightDaysAgo), {reel.id});

      expect(await h.scanner.countEarlierIn(june(2, 10)), 2, reason: 'today');
      final ids = await h.scanner.addEarlier(june(2, 10));

      expect(ids, hasLength(2));
      expect({for (final c in await h.skipped()) c.mediaStoreId}, {4});
      expect(await toTagIds(), unorderedEquals([3, 1, 2]));
    });

    test('a pending video in the range is not counted', () async {
      bridge.put([shot(6, DateTime(2026, 6, 9, 11), pending: true)]);

      expect(await h.scanner.countEarlierIn(june(9, 9)), 1);
      await h.scanner.addEarlier(june(9, 9));
      expect(await toTagIds(), [3]);
    });

    test('a zero-length video in the range is not counted', () async {
      bridge.put([
        shot(7, DateTime(2026, 6, 9, 11), durationMs: 0),
        shot(8, DateTime(2026, 6, 9, 12), durationMs: null),
      ]);

      expect(await h.scanner.countEarlierIn(june(9, 9)), 1);
      await h.scanner.addEarlier(june(9, 9));
      expect(await toTagIds(), [3]);
    });

    test('a video of unknown size in the range is not counted or added '
        '(I-1)', () async {
      bridge.put([
        shot(7, DateTime(2026, 6, 9, 11), sizeBytes: 0),
        shot(8, DateTime(2026, 6, 9, 12), sizeBytes: -1),
      ]);

      expect(await h.scanner.countEarlierIn(june(9, 9)), 1);
      await h.scanner.addEarlier(june(9, 9));
      expect(await toTagIds(), [3]);
    });

    test('videos outside the watched folders are not counted', () async {
      bridge.put([shot(6, DateTime(2026, 6, 9, 11), folder: 'Download/')]);

      expect(await h.scanner.countEarlierIn(june(9, 9)), 1);
    });

    test('a stored clip holding the number of a different video: counted, '
        'added, and the old clip detached (Ruling U)', () async {
      final [oldClip] = await h.store([yesterday.copyWith(sizeBytes: 5)]);
      final reel = await reels.create('Goa');
      await h.clips.tagClip(oldClip, {reel.id});

      expect(await h.scanner.countEarlierIn(june(9, 9)), 1);
      final ids = await h.scanner.addEarlier(june(9, 9));

      expect(ids, hasLength(1));
      expect(ids, isNot(contains(oldClip)));
      expect(await toTagIds(), [3]);
      final old = await h.clip(oldClip);
      expect((old.mediaStoreId, old.missing), (-oldClip, true));
      expect(await h.clips.watchReelIdsOf(oldClip).first, {reel.id});
      expect(await h.scanner.countEarlierIn(june(9, 9)), 0);
    });

    test('an inbox-only stored clip that is another video leaves To tag when '
        'the earlier video is added (Ruling Y)', () async {
      final [oldClip] = await h.store([yesterday.copyWith(sizeBytes: 5)]);

      final ids = await h.scanner.addEarlier(june(9, 9));

      expect(ids, hasLength(1));
      expect((await h.allClips()).map((c) => c.id), isNot(contains(oldClip)));
      expect(await toTagIds(), [3]);
    });

    test('a tagged clip in the range does not return to To tag', () async {
      await h.store([yesterday]);
      final clipId = await clipIdOf(yesterday);
      final reel = await reels.create('Goa');
      await h.clips.tagClip(clipId, {reel.id});

      final ids = await h.scanner.addEarlier(june(5, 10));

      expect(ids, hasLength(3));
      expect(await toTagIds(), unorderedEquals([1, 2, 4]));
      expect(
        [for (final c in await h.clips.watchReelClips(reel.id).first) c.id],
        [clipId],
      );
    });

    test('a skipped clip stays skipped', () async {
      await h.store([today1]);
      final clipId = await clipIdOf(today1);
      await h.clips.skip([clipId]);

      await h.scanner.addEarlier(june(9, 10));

      expect([for (final c in await h.skipped()) c.id], [clipId]);
      expect(await toTagIds(), [3, 2]);
    });

    test(
      'nothing in the range: 0, and add returns [] without writing',
      () async {
        await h.turnOnNow();

        expect(await h.scanner.countEarlierIn(june(3, 4)), 0);
        expect(await h.scanner.addEarlier(june(3, 4)), isEmpty);

        expect(await h.allClips(), isEmpty);
        expect((await h.phoneState.loadShooting()).earlierAdded, isFalse);
      },
    );

    test(
      'a range with from after to is rejected before anything is read',
      () async {
        await expectLater(
          h.scanner.countEarlierIn(june(9, 5)),
          throwsArgumentError,
        );
        await expectLater(
          h.scanner.addEarlier(june(9, 5)),
          throwsArgumentError,
        );

        expect(bridge.calls, isNot(contains('videosShotSince')));
        expect(await h.allClips(), isEmpty);
      },
    );

    test('a "to" in the future is clamped to today', () async {
      final future = EarlierCustom(DateTime(2026, 6, 9), DateTime(2026, 7));

      expect(await h.scanner.countEarlierIn(future), 3);
    });

    test('a range 10 years long still queries once per volume', () async {
      final wide = EarlierCustom(DateTime(2016, 6, 10), DateTime(2026, 6, 10));

      expect(await h.scanner.countEarlierIn(wide), 5);
      expect(bridge.count('videosShotSince'), 1);
    });
  });

  group('shared rules', () {
    test('addEarlier does not move any baseline', () async {
      final session = await h.turnOn({
        phone: const VolumeBaseline(version: 'v1', generation: 3),
      });

      await h.scanner.addEarlier(june(2, 10));
      await h.scanner.addEarlier(today);

      expect((await h.phoneState.loadShooting()).baselines, session.baselines);
      expect(bridge.calls, isNot(contains('videosAddedAfter')));
    });

    test(
      'addEarlier while a scan runs waits for it, and the video is added once',
      () async {
        await h.turnOn({
          phone: const VolumeBaseline(version: 'v1', generation: 1),
        });
        final gate = bridge.gate('videosAddedAfter');
        final scan = h.scanner.scan();
        await until(() => bridge.calls.contains('videosAddedAfter'));

        final add = h.scanner.addEarlier(today);
        await settle();
        expect(bridge.calls, isNot(contains('videosShotSince')));
        gate.complete();
        await scan;
        final ids = await add;

        // The scan found 2 to 5; today1 (generation 1) was before its
        // baseline.
        expect(ids, [await clipIdOf(today1)]);
        final inToTag = await toTagIds();
        expect(inToTag, hasLength(5));
        expect(inToTag.toSet(), hasLength(5));
      },
    );

    test('countEarlierIn runs on the media queue too', () async {
      await h.turnOn({
        phone: const VolumeBaseline(version: 'v1', generation: 1),
      });
      final gate = bridge.gate('videosAddedAfter');
      final scan = h.scanner.scan();
      await until(() => bridge.calls.contains('videosAddedAfter'));

      var counted = false;
      final count = h.scanner.countEarlierIn(june(5, 10)).then((n) {
        counted = true;
        return n;
      });
      await settle();
      expect(counted, isFalse, reason: 'the scan holds the queue');
      expect(bridge.calls, isNot(contains('videosShotSince')));
      gate.complete();
      await scan;

      // The scan added 2 to 5; only today1 is still new.
      expect(await count, 1);
    });

    test('without full access: counts are 0, add throws StateError', () async {
      for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
        bridge.access = MediaAccess(
          level: level,
          canAskAgain: true,
          sdkInt: 34,
        );

        expect(await h.scanner.countEarlier(), 0);
        expect(await h.scanner.countEarlierIn(june(2, 10)), 0);
        await expectLater(h.scanner.addEarlier(today), throwsStateError);
        await expectLater(h.scanner.addEarlier(june(2, 10)), throwsStateError);
      }

      expect(bridge.calls.toSet(), {'accessReport'});
      expect(await h.allClips(), isEmpty);
    });

    test(
      'works with Shooting mode off and leaves earlierAdded false',
      () async {
        expect(await h.scanner.addEarlier(today), hasLength(2));

        final state = await h.phoneState.loadShooting();
        expect(state.on, isFalse);
        expect(state.earlierAdded, isFalse);
      },
    );

    test('with Shooting mode on, adding marks earlierAdded', () async {
      await h.turnOnNow();

      await h.scanner.addEarlier(june(9, 9));

      expect((await h.phoneState.loadShooting()).earlierAdded, isTrue);
    });

    test('an empty result returns [] and does not set earlierAdded', () async {
      await h.turnOnNow();
      await h.store([today1, today2]);

      expect(await h.scanner.addEarlier(today), isEmpty);

      expect((await h.phoneState.loadShooting()).earlierAdded, isFalse);
    });

    test('a volume whose query fails is left out; the others count', () async {
      bridge
        ..put(
          [shot(9, DateTime(2026, 6, 10, 9), volume: card)],
          volume: card,
          version: 'c1',
        )
        ..failNext('videosShotSince');

      expect(await h.scanner.countEarlier(), 1);
    });

    test('an unmounted volume is not asked', () async {
      bridge
        ..put(
          [shot(9, DateTime(2026, 6, 10, 9), volume: card)],
          volume: card,
          version: 'c1',
        )
        ..setVolume(card, version: null);

      expect(await h.scanner.countEarlier(), 2);
      expect(bridge.count('videosShotSince'), 1);
    });

    test('videos on a second volume are counted in the range', () async {
      bridge.put(
        [shot(9, DateTime(2026, 6, 9, 9), volume: card)],
        volume: card,
        version: 'c1',
      );

      expect(await h.scanner.countEarlierIn(june(9, 9)), 2);
      expect(bridge.count('videosShotSince'), 2);
    });
  });

  group('zone sync before the timeline is read (I-2)', () {
    // The timeline knows UTC; the phone changed to Paris before yesterday's
    // video was shot, and only the native side knows.
    Future<void> setUpTravel() async {
      await h.zones.recordAll([
        ZoneEntry(at: DateTime.utc(2026, 6), zoneId: 'UTC'),
      ]);
      bridge
        ..zoneChanges = [
          ZoneEntry(at: DateTime.utc(2026, 6, 9), zoneId: 'Europe/Paris'),
        ]
        ..currentZone = 'Europe/Paris';
    }

    test(
      'addEarlier waits for the sync, and the clip gets the new zone',
      () async {
        await setUpTravel();
        final gate = bridge.gate('pendingZoneChanges');

        final add = h.scanner.addEarlier(june(9, 9));
        await until(() => bridge.calls.contains('pendingZoneChanges'));
        await settle();
        expect(await h.allClips(), isEmpty, reason: 'waiting for the sync');
        gate.complete();

        expect(await add, hasLength(1));
        expect((await h.toTag()).single.timeZoneId, 'Europe/Paris');
      },
    );

    test('a sync that throws still lets addEarlier run', () async {
      await setUpTravel();
      bridge.failNext('pendingZoneChanges');

      expect(await h.scanner.addEarlier(june(9, 9)), hasLength(1));

      // The old timeline answers.
      expect((await h.toTag()).single.timeZoneId, 'UTC');
    });

    test('counting does not sync', () async {
      await setUpTravel();

      await h.scanner.countEarlierIn(june(9, 9));

      expect(bridge.calls, isNot(contains('pendingZoneChanges')));
    });
  });

  group("the volume's library version is recorded (M-3)", () {
    // Android renumbers every video and changes the volume's version.
    void rebuild() {
      bridge.videosByVolume[phone] = [
        for (final v in bridge.videosByVolume[phone]!)
          v.copyWith(
            mediaStoreId: v.mediaStoreId + 100,
            generationAdded: v.generationAdded + 100,
          ),
      ];
      bridge.setVolume(phone, version: 'v2', generation: 200);
    }

    test('Add earlier on a fresh install records the version', () async {
      expect(await h.phoneState.volumeVersions(), isEmpty);

      await h.scanner.addEarlier(today);

      expect(await h.phoneState.volumeVersions(), {phone: 'v1'});
    });

    test('Add earlier, then a rebuild, then verify: the clips are found '
        'again, not marked missing', () async {
      final ids = await h.scanner.addEarlier(today);
      expect(ids, hasLength(2));
      rebuild();

      final outcome = await h.verifier.verifyAll();

      expect(outcome.found, ids.toSet());
      expect(outcome.missing, isEmpty);
      expect(await toTagIds(), unorderedEquals([101, 102]));
      expect((await h.allClips()).every((c) => !c.missing), isTrue);
    });

    test('a rebuild before the next Add earlier: the stored clips are '
        'matched first, so nothing is added twice', () async {
      await h.scanner.addEarlier(today);
      rebuild();

      expect(await h.scanner.addEarlier(today), isEmpty);

      expect(await h.allClips(), hasLength(2));
      expect(await toTagIds(), unorderedEquals([101, 102]));
      expect(await h.phoneState.volumeVersions(), {phone: 'v2'});
    });
  });

  group('across a daylight-saving change (Europe/London)', () {
    test('the zone is Europe/London', () {
      expect(_inLondon, isTrue, reason: 'run with TZ=Europe/London');
    }, skip: _londonOnly);

    test(
      'the day the clocks went back (2026-10-25, 25 hours) is one day',
      () async {
        // 12:00 on the 31st. The 25th is 23:00 UTC on the 24th to 00:00 UTC on
        // the 26th.
        final h = MediaHarness(now: DateTime.utc(2026, 10, 31, 12));
        h.bridge.put([
          shot(1, DateTime.utc(2026, 10, 24, 22, 59)), // 23:59 BST on the 24th
          shot(2, DateTime.utc(2026, 10, 24, 23, 1)), // 00:01 BST on the 25th
          shot(3, DateTime.utc(2026, 10, 25, 23, 30)), // 23:30 GMT on the 25th
          shot(4, DateTime.utc(2026, 10, 26)), // 00:00 GMT on the 26th
          shot(5, DateTime.utc(2026, 10, 26, 0, 1)), // 00:01 GMT on the 26th
        ]);
        final day = EarlierCustom(
          DateTime(2026, 10, 25),
          DateTime(2026, 10, 25),
        );

        expect(await h.scanner.countEarlierIn(day), 2);
        await h.scanner.addEarlier(day);
        expect([
          for (final c in await h.toTag()) c.mediaStoreId,
        ], unorderedEquals([3, 2]));
      },
      skip: _londonOnly,
    );

    test('a range across the change takes in the whole 25-hour day', () async {
      final h = MediaHarness(now: DateTime.utc(2026, 10, 31, 12));
      h.bridge.put([
        shot(1, DateTime.utc(2026, 10, 23, 22, 59)), // 23:59 BST on the 23rd
        shot(2, DateTime.utc(2026, 10, 23, 23, 1)), // 00:01 BST on the 24th
        shot(3, DateTime.utc(2026, 10, 25, 23, 30)), // 23:30 GMT on the 25th
        shot(4, DateTime.utc(2026, 10, 26, 23, 59)), // 23:59 GMT on the 26th
        shot(5, DateTime.utc(2026, 10, 27)), // 00:00 GMT on the 27th
      ]);
      final range = EarlierCustom(
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 26),
      );

      expect(await h.scanner.countEarlierIn(range), 3);
    }, skip: _londonOnly);

    test('the day the clocks went forward (2027-03-28, 23 hours)', () async {
      final h = MediaHarness(now: DateTime.utc(2027, 4, 3, 12));
      h.bridge.put([
        shot(1, DateTime.utc(2027, 3, 27, 23, 59)), // 23:59 GMT on the 27th
        shot(2, DateTime.utc(2027, 3, 28, 0, 1)), // 00:01 GMT on the 28th
        shot(3, DateTime.utc(2027, 3, 28, 22, 59)), // 22:59 GMT on the 28th
        shot(4, DateTime.utc(2027, 3, 28, 23, 10)), // 00:10 BST on the 29th
      ]);
      final day = EarlierCustom(DateTime(2027, 3, 28), DateTime(2027, 3, 28));

      expect(await h.scanner.countEarlierIn(day), 2);
    }, skip: _londonOnly);

    test('Today after the change: yesterday started at 00:00 BST', () async {
      // 00:30 on the 26th (GMT).
      final h = MediaHarness(now: DateTime.utc(2026, 10, 26, 0, 30));
      h.bridge.put([
        shot(1, DateTime.utc(2026, 10, 25, 23, 59)),
        shot(2, DateTime.utc(2026, 10, 26, 0, 10)),
      ]);

      expect(await h.scanner.countEarlier(), 1);
    }, skip: _londonOnly);
  });
}
