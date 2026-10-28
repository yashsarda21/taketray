import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
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
}) => fakeVideo(
  id: id,
  generation: id,
  volume: volume,
  folder: folder,
  pending: pending,
  durationMs: durationMs,
  sizeBytes: 1000000 + id,
  dateTakenMs: when.millisecondsSinceEpoch,
  dateAddedSec: when.millisecondsSinceEpoch ~/ 1000,
  dateModifiedSec: when.millisecondsSinceEpoch ~/ 1000,
);

Map<EarlierRange, int> counts(int today, int lastTwo, int lastSeven) => {
  EarlierRange.today: today,
  EarlierRange.lastTwoDays: lastTwo,
  EarlierRange.lastSevenDays: lastSeven,
};

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

  test('counts every range', () async {
    expect(await h.scanner.countEarlier(), counts(2, 3, 4));
    expect(bridge.count('videosShotSince'), 1, reason: 'one query per volume');
    expect(await h.allClips(), isEmpty, reason: 'counting writes nothing');
  });

  test('counts per range exclude known clips', () async {
    await h.store([today1, yesterday, fiveDaysAgo]);
    // today1 waits in To tag, yesterday is skipped, fiveDaysAgo is tagged.
    await h.clips.skip([await clipIdOf(yesterday)]);
    final reel = await reels.create('Goa');
    await h.clips.tagClip(await clipIdOf(fiveDaysAgo), {reel.id});

    expect(await h.scanner.countEarlier(), counts(1, 1, 1));
  });

  test(
    "addEarlier(today) adds only today's new videos and returns their ids",
    () async {
      bridge.currentZone = 'Asia/Kolkata';

      final ids = await h.scanner.addEarlier(EarlierRange.today);

      expect(ids, hasLength(2));
      final added = await h.toTag();
      expect({for (final c in added) c.id}, ids.toSet());
      expect({for (final c in added) c.mediaStoreId}, {1, 2});
      expect({for (final c in added) c.timeZoneId}, {'Asia/Kolkata'});
      expect(await h.scanner.countEarlier(), counts(0, 1, 2));
    },
  );

  test('a tagged clip in the window does not return to To tag', () async {
    await h.store([today1]);
    final clipId = await clipIdOf(today1);
    final reel = await reels.create('Goa');
    await h.clips.tagClip(clipId, {reel.id});

    final ids = await h.scanner.addEarlier(EarlierRange.today);

    expect(ids, hasLength(1));
    expect(await toTagIds(), [2]);
    expect(
      [for (final c in await h.clips.watchReelClips(reel.id).first) c.id],
      [clipId],
    );
  });

  test('a skipped clip stays skipped', () async {
    await h.store([today1]);
    final clipId = await clipIdOf(today1);
    await h.clips.skip([clipId]);

    await h.scanner.addEarlier(EarlierRange.lastTwoDays);

    expect([for (final c in await h.skipped()) c.id], [clipId]);
    expect(await toTagIds(), [3, 2]);
  });

  test('addEarlier does not move any baseline', () async {
    final session = await h.turnOn({
      phone: const VolumeBaseline(version: 'v1', generation: 3),
    });

    await h.scanner.addEarlier(EarlierRange.lastSevenDays);

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

      final add = h.scanner.addEarlier(EarlierRange.today);
      await settle();
      expect(bridge.calls, isNot(contains('videosShotSince')));
      gate.complete();
      await scan;
      final ids = await add;

      // The scan found 2 to 5; today1 (generation 1) was before its baseline.
      expect(ids, [await clipIdOf(today1)]);
      final inToTag = await toTagIds();
      expect(inToTag, hasLength(5));
      expect(inToTag.toSet(), hasLength(5));
    },
  );

  test('without full access: count is zeros, add throws StateError', () async {
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      bridge.access = MediaAccess(level: level, canAskAgain: true, sdkInt: 34);

      expect(await h.scanner.countEarlier(), counts(0, 0, 0));
      await expectLater(
        h.scanner.addEarlier(EarlierRange.today),
        throwsStateError,
      );
    }

    expect(bridge.calls.toSet(), {'accessReport'});
    expect(await h.allClips(), isEmpty);
  });

  test(
    'pending and zero-length videos in the window are not counted',
    () async {
      bridge.put([
        shot(6, DateTime(2026, 6, 10, 11), pending: true),
        shot(7, DateTime(2026, 6, 10, 11), durationMs: 0),
        shot(8, DateTime(2026, 6, 10, 11), durationMs: null),
      ]);

      expect(await h.scanner.countEarlier(), counts(2, 3, 4));
      await h.scanner.addEarlier(EarlierRange.today);
      expect(await toTagIds(), [1, 2]);
    },
  );

  test('videos outside the watched folders are not counted', () async {
    bridge.put([shot(6, DateTime(2026, 6, 10, 11), folder: 'Download/')]);

    expect(await h.scanner.countEarlier(), counts(2, 3, 4));
  });

  test('works with Shooting mode off and leaves earlierAdded false', () async {
    expect(await h.scanner.addEarlier(EarlierRange.today), hasLength(2));

    final state = await h.phoneState.loadShooting();
    expect(state.on, isFalse);
    expect(state.earlierAdded, isFalse);
  });

  test('with Shooting mode on, adding marks earlierAdded', () async {
    await h.turnOnNow();

    await h.scanner.addEarlier(EarlierRange.today);

    expect((await h.phoneState.loadShooting()).earlierAdded, isTrue);
  });

  test('an empty result returns [] and does not set earlierAdded', () async {
    await h.turnOnNow();
    await h.store([today1, today2]);

    expect(await h.scanner.addEarlier(EarlierRange.today), isEmpty);

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

    expect(await h.scanner.countEarlier(), counts(1, 1, 1));
  });

  test('an unmounted volume is not asked', () async {
    bridge
      ..put(
        [shot(9, DateTime(2026, 6, 10, 9), volume: card)],
        volume: card,
        version: 'c1',
      )
      ..setVolume(card, version: null);

    expect(await h.scanner.countEarlier(), counts(2, 3, 4));
    expect(bridge.count('videosShotSince'), 1);
  });

  test("at 00:05, today does not include yesterday's 23:59", () async {
    final h = MediaHarness(now: DateTime(2026, 6, 10, 0, 5).toUtc());
    h.bridge.put([
      shot(1, DateTime(2026, 6, 9, 23, 59)),
      shot(2, DateTime(2026, 6, 10, 0, 1)),
    ]);

    expect(await h.scanner.countEarlier(), counts(1, 2, 2));
    await h.scanner.addEarlier(EarlierRange.today);
    expect([for (final c in await h.toTag()) c.mediaStoreId], [2]);
  });

  group('across a daylight-saving change (Europe/London)', () {
    test('the zone is Europe/London', () {
      expect(_inLondon, isTrue, reason: 'run with TZ=Europe/London');
    }, skip: _londonOnly);

    test('clocks went back yesterday (2026-10-25, 25 hours)', () async {
      // 00:30 on the 26th (GMT); yesterday started at 00:00 BST, 23:00 UTC.
      final h = MediaHarness(now: DateTime.utc(2026, 10, 26, 0, 30));
      h.bridge.put([
        shot(1, DateTime.utc(2026, 10, 24, 22, 59)), // 23:59 BST on the 24th
        shot(2, DateTime.utc(2026, 10, 24, 23, 1)), // 00:01 BST on the 25th
        shot(3, DateTime.utc(2026, 10, 26, 0, 10)), // 00:10 GMT on the 26th
      ]);

      expect(await h.scanner.countEarlier(), counts(1, 2, 3));
      await h.scanner.addEarlier(EarlierRange.lastTwoDays);
      expect([for (final c in await h.toTag()) c.mediaStoreId], [2, 3]);
    }, skip: _londonOnly);

    test('clocks went forward yesterday (2027-03-28, 23 hours)', () async {
      // 00:30 BST on the 29th; yesterday started at 00:00 GMT.
      final h = MediaHarness(now: DateTime.utc(2027, 3, 28, 23, 30));
      h.bridge.put([
        shot(1, DateTime.utc(2027, 3, 27, 23, 59)), // 23:59 GMT on the 27th
        shot(2, DateTime.utc(2027, 3, 28, 0, 1)), // 00:01 GMT on the 28th
        shot(3, DateTime.utc(2027, 3, 28, 23, 10)), // 00:10 BST on the 29th
      ]);

      expect(await h.scanner.countEarlier(), counts(1, 2, 3));
    }, skip: _londonOnly);
  });
}
