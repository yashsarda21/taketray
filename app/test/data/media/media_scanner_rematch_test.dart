import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/background_bridge.dart';

import '../../support/clip_setup.dart';
import '../../support/fake_media_bridge.dart';
import 'media_harness.dart';

// I-3 (D-108): clips Android's rebuild left detached (`-id`, missing) are
// matched again, once per scan and volume, while the volume's index is
// stable (a `ScanAfter` plan), against everything now on the volume.

/// [count] videos from [firstId], one generation each from [firstGeneration].
List<MediaVideo> many(
  int count, {
  required int firstId,
  required int firstGeneration,
}) => [for (var i = 0; i < count; i++) vid(firstId + i, firstGeneration + i)];

/// The video [like] under the number [id], added at [generation]. Two videos
/// with one [like] are the same video under two numbers (same size, length,
/// date and name).
MediaVideo vid(
  int id,
  int generation, {
  int? like,
  String volume = phone,
  String? name,
  int? durationMs = 5000,
  int? dateAddedSec = 1780000000,
}) => fakeVideo(
  id: id,
  generation: generation,
  volume: volume,
  sizeBytes: 1000000 + (like ?? id),
  name: name ?? 'VID_${like ?? id}.mp4',
  durationMs: durationMs,
  dateAddedSec: dateAddedSec,
);

VolumeBaseline at(int generation, [String version = 'v1']) =>
    VolumeBaseline(version: version, generation: generation);

Matcher scanDone({
  required int added,
  Set<String> resynced = const {},
  Set<String> failed = const {},
}) => isA<ScanDone>()
    .having((d) => d.added, 'added', added)
    .having((d) => d.resynced, 'resynced', resynced)
    .having((d) => d.failedVolumes, 'failedVolumes', failed);

MediaHarness? _built;
MediaHarness get h => _built ??= MediaHarness();
RecordingBridge get bridge => h.bridge;

void main() {
  setUp(() => _built = null);

  late ReelsRepository reels;
  setUp(() => reels = ReelsRepository(h.db, h.clock));

  /// Stores [original] as a clip in reel [reelId] and detaches it, as a
  /// rebuild that could not see the video leaves it.
  Future<int> detachedIn(int reelId, MediaVideo original) async {
    final id = (await h.store([original])).single;
    await h.clips.addClipsToReel(reelId, [id]);
    await detachClips(h.db, {id}, at: h.clock.now());
    return id;
  }

  Future<Clip> clip(int id) => h.clip(id);

  Future<Set<int>> toTagIds() async => {for (final c in await h.toTag()) c.id};

  group('a half-built index, then the videos appear', () {
    test('detached clip re-attaches when the video appears', () async {
      final reel = await reels.create('Goa');
      final original = vid(10, 1);
      bridge.put([original], generation: 5);
      final d = (await h.store([original])).single;
      await h.clips.addClipsToReel(reel.id, [d]);
      await h.turnOnNow();
      // Android rebuilds, and the media scanner has indexed nothing yet.
      bridge
        ..videosByVolume[phone] = []
        ..put([], version: 'v2');
      expect(await h.scanner.scan(), scanDone(added: 0, resynced: {phone}));
      expect((await clip(d)).mediaStoreId, -d);
      expect((await clip(d)).missing, isTrue);

      // A minute later the same video is indexed again, under a new number.
      bridge.put([vid(110, 1, like: 10)], version: 'v2');
      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 0));
      final after = await clip(d);
      expect((after.mediaStoreId, after.missing), (110, false));
      expect(await toTagIds(), isEmpty, reason: 'no duplicate in To tag');
      expect(await h.allClips(), hasLength(1));
      expect(
        [
          for (final c in await h.clips.watchReelClips(reel.id).first)
            c.clip.id,
        ],
        [d],
      );
      expect(await h.baselineOf(phone), at(1, 'v2'));
    });

    test(
      'duplicate in To tag is removed and the reel clip un-missed',
      () async {
        final reel = await reels.create('Goa');
        final d = await detachedIn(reel.id, vid(10, 1));
        // An earlier scan already took the re-indexed video for a new one.
        bridge.put([vid(110, 3, like: 10)], generation: 3);
        final n = (await h.store([vid(110, 3, like: 10)])).single;
        await h.turnOn({phone: at(3)});
        expect(await toTagIds(), {n});

        final outcome = await h.scanner.scan();

        expect(outcome, scanDone(added: 0));
        expect(await toTagIds(), isEmpty);
        expect(await h.allClips(), hasLength(1));
        final after = await clip(d);
        expect((after.mediaStoreId, after.missing), (110, false));
        expect(
          [
            for (final c in await h.clips.watchReelClips(reel.id).first)
              c.clip.id,
          ],
          [d],
        );
      },
    );

    test('duplicate in a reel merges links', () async {
      final goa = await reels.create('Goa');
      final cafe = await reels.create('Cafe');
      final d = await detachedIn(goa.id, vid(10, 1));
      bridge.put([vid(110, 3, like: 10)], generation: 3);
      final n = (await h.store([vid(110, 3, like: 10)])).single;
      await h.clips.addClipsToReel(cafe.id, [n]);
      await h.turnOn({phone: at(3)});

      await h.scanner.scan();

      expect(await h.allClips(), hasLength(1));
      for (final reel in [goa, cafe]) {
        expect(
          [
            for (final c in await h.clips.watchReelClips(reel.id).first)
              c.clip.id,
          ],
          [d],
          reason: reel.name,
        );
      }
      expect((await clip(d)).missing, isFalse);
    });

    test('ambiguous fingerprint leaves both', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(reel.id, vid(10, 1, name: 'same.mp4'));
      // Two videos match it, and carry the same name: nothing says which.
      bridge.put([
        vid(110, 3, like: 10, name: 'same.mp4'),
        vid(111, 4, like: 10, name: 'same.mp4'),
      ]);
      final n = (await h.store([vid(110, 3, like: 10, name: 'same.mp4')]))
          .single;
      await h.turnOn({phone: at(4)});

      expect(await h.scanner.scan(), scanDone(added: 0));

      final after = await clip(d);
      expect((after.mediaStoreId, after.missing), (-d, true));
      expect(await toTagIds(), {n});
      expect((await clip(n)).mediaStoreId, 110);
    });

    test('two detached clips matching two videos', () async {
      final reel = await reels.create('Goa');
      final d1 = await detachedIn(reel.id, vid(10, 1));
      final d2 = await detachedIn(reel.id, vid(11, 2));
      bridge.put([vid(110, 3, like: 10), vid(111, 4, like: 11)]);
      final n2 = (await h.store([vid(111, 4, like: 11)])).single;
      await h.turnOn({phone: at(4)});

      await h.scanner.scan();

      expect((await clip(d1)).mediaStoreId, 110);
      expect((await clip(d2)).mediaStoreId, 111);
      expect((await clip(d1)).missing, isFalse);
      expect((await clip(d2)).missing, isFalse);
      expect(await h.allClips(), hasLength(2));
      expect(await toTagIds(), isNot(contains(n2)));
    });

    test('the page of new videos sees the re-attached clip as known', () async {
      // The re-indexed video is still ahead of the baseline: the same scan
      // that re-attaches the clip pages over it and must not add it again.
      final reel = await reels.create('Goa');
      final d = await detachedIn(reel.id, vid(10, 1));
      bridge.put([vid(110, 6, like: 10), vid(120, 7)], generation: 7);
      await h.turnOn({phone: at(5)});

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 1));
      expect({for (final c in await h.toTag()) c.mediaStoreId}, {120});
      expect((await clip(d)).mediaStoreId, 110);
      expect(await h.allClips(), hasLength(2));
    });

    test('a clip holding the number with another video is left, not '
        'merged', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(reel.id, vid(10, 1));
      // Clip 110 is a different video that was once given that number.
      final stale = (await h.store([vid(110, 3, like: 77)])).single;
      bridge.put([vid(110, 3, like: 10)], generation: 3);
      await h.turnOn({phone: at(3)});

      await h.scanner.scan();

      expect((await clip(d)).missing, isTrue);
      expect((await clip(stale)).mediaStoreId, 110);
    });
  });

  group('reading the whole volume', () {
    test('no detached clips does not read all videos', () async {
      bridge.put([vid(1, 1), vid(2, 2)], generation: 2);
      await h.store([vid(1, 1)]);
      await h.turnOn({phone: at(2)});
      bridge.put([vid(3, 3)]);

      expect(await h.scanner.scan(), scanDone(added: 1));

      expect(bridge.count('allVideos'), 0);
    });

    test('re-match runs once per scan', () async {
      final reel = await reels.create('Goa');
      // The video is not on the phone: the clip stays detached.
      await detachedIn(reel.id, vid(10, 1));
      bridge.put([vid(1, 1)], generation: 1);
      await h.turnOn({phone: at(1)});
      bridge.put(many(1200, firstId: 2000, firstGeneration: 2));

      expect(await h.scanner.scan(), scanDone(added: 1200));
      expect(bridge.addedAfter.length, greaterThan(1), reason: 'many pages');
      expect(bridge.count('allVideos'), 1);

      expect(await h.scanner.scan(), scanDone(added: 0));
      expect(bridge.count('allVideos'), 2);
    });

    test('each volume with detached clips is read once per scan', () async {
      final reel = await reels.create('Goa');
      bridge
        ..put([vid(1, 1)], generation: 1)
        ..put(
          [vid(2, 1, volume: card)],
          volume: card,
          version: 'c1',
        );
      await detachedIn(reel.id, vid(10, 1));
      await detachedIn(reel.id, vid(11, 1, volume: card));
      await h.turnOnNow();

      await h.scanner.scan();

      expect(bridge.count('allVideos'), 2);
    });

    test('a resynced volume is matched by the resync alone', () async {
      final reel = await reels.create('Goa');
      bridge.put([vid(1, 1)], generation: 1);
      await detachedIn(reel.id, vid(10, 1));
      await h.turnOnNow();
      bridge
        ..videosByVolume[phone] = []
        ..put([vid(1, 1)], version: 'v2');

      expect(await h.scanner.scan(), scanDone(added: 0, resynced: {phone}));

      expect(bridge.count('allVideos'), 1, reason: "the resync's own read");
    });

    test('a volume with no baseline is not re-matched', () async {
      final reel = await reels.create('Goa');
      bridge.put([vid(1, 1)], generation: 1);
      await detachedIn(reel.id, vid(10, 1));
      await h.turnOn({});

      await h.scanner.scan();

      expect(bridge.count('allVideos'), 0);
    });

    test('a re-match on a volume that is unmounted does nothing', () async {
      final reel = await reels.create('Goa');
      bridge
        ..put([vid(1, 1)])
        ..put(
          [vid(2, 1, volume: card)],
          volume: card,
          version: 'c1',
        );
      final d = await detachedIn(reel.id, vid(10, 1, volume: card));
      await h.turnOnNow();
      // The card is listed without a version, then not listed at all.
      bridge.setVolume(card, version: null);
      await h.scanner.scan();
      bridge.removeVolume(card);
      await h.scanner.scan();

      expect(bridge.count('allVideos'), 0);
      final after = await clip(d);
      expect((after.mediaStoreId, after.missing), (-d, true));
    });

    test('a failing allVideos does not fail the volume or stop the new '
        'clips; the next scan tries again', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(reel.id, vid(10, 1));
      bridge.put([vid(110, 3, like: 10)], generation: 3);
      await h.turnOn({phone: at(2)});
      bridge
        ..put([vid(130, 4)])
        ..failNext('allVideos');
      final records = captureLogs();

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 2), reason: 'both are new for now');
      expect((await clip(d)).missing, isTrue);
      expect(await h.baselineOf(phone), at(4));
      final text = logText(records);
      expect(text, contains('PlatformException'));
      expect(text, isNot(contains('failed on purpose')));
      expect(text, isNot(contains('.mp4')));
    });

    test('a failing database write in the re-match does not fail the '
        'volume either', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(reel.id, vid(10, 1));
      bridge.put([vid(110, 3, like: 10)], generation: 3);
      await h.turnOn({phone: at(3)});
      await h.db.customStatement(
        'CREATE TRIGGER no_reattach BEFORE UPDATE ON clips '
        "WHEN NEW.id = $d BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      final records = captureLogs();

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 0));
      expect((await clip(d)).missing, isTrue);
      expect(logText(records), isNot(contains('disk full')));
    });

    test('the log has volume names and counts, no names or folders', () async {
      final reel = await reels.create('Secret reel');
      await detachedIn(reel.id, vid(10, 1, name: 'Secret_take.mp4'));
      bridge.put([vid(110, 3, like: 10, name: 'Secret_take.mp4')]);
      await h.store([vid(110, 3, like: 10, name: 'Secret_take.mp4')]);
      await h.turnOn({phone: at(3)});
      final records = captureLogs();

      await h.scanner.scan();

      final text = logText(records);
      expect(text, contains('re-attached'));
      for (final secret in ['Secret', 'secret', '.mp4', 'DCIM']) {
        expect(text, isNot(contains(secret)));
      }
    });
  });

  group('when the session ends from the shade', () {
    Future<DateTime> start() async => (await h.turnOn({phone: at(3)})).since!;

    ShadeAction turnOff(DateTime session) => ShadeAction(
      kind: ShadeActionKind.turnOff,
      since: session,
      at: DateTime.utc(2026, 6, 1, 18),
      generations: const {phone: 3},
    );

    test('the capped end re-matches too', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(reel.id, vid(10, 1));
      bridge.put([vid(110, 3, like: 10)], generation: 3);
      final session = await start();
      h.background.shadeAction = turnOff(session);

      await h.scanner.scan();

      expect((await h.phoneState.loadShooting()).on, isFalse);
      expect((await clip(d)).mediaStoreId, 110);
      expect((await clip(d)).missing, isFalse);
    });

    test('a failing re-match does not keep the session open', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(reel.id, vid(10, 1));
      bridge.put([vid(110, 3, like: 10)], generation: 3);
      final session = await start();
      h.background.shadeAction = turnOff(session);
      bridge.failNext('allVideos');

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 0));
      expect((await h.phoneState.loadShooting()).on, isFalse);
      expect(h.background.shadeAction, isNull);
      expect((await clip(d)).missing, isTrue);
    });
  });
}
