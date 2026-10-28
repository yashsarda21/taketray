import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../support/fake_media_bridge.dart';
import '../../support/test_database.dart';
import 'media_harness.dart';

MediaVideo video(int id, {String volume = phone, int? sizeBytes}) => fakeVideo(
  id: id,
  generation: id,
  volume: volume,
  sizeBytes: sizeBytes ?? 1000000 + id,
);

Matcher outcome({
  Set<int> found = const {},
  Set<int> missing = const {},
  Set<int> skipped = const {},
}) => isA<VerifyOutcome>()
    .having((o) => o.found, 'found', found)
    .having((o) => o.missing, 'missing', missing)
    .having((o) => o.skipped, 'skipped', skipped);

MediaHarness? _built;

/// Built on first use, so a test that makes its own harness never has two
/// databases open.
MediaHarness get h => _built ??= MediaHarness();

RecordingBridge get bridge => h.bridge;

ReelsRepository get reels => ReelsRepository(h.db, h.clock);

void main() {
  setUp(() => _built = null);

  /// Stores [videos] as clips (in To tag) and returns them, by MediaStore id.
  Future<Map<int, Clip>> stored(List<MediaVideo> videos) async {
    final ids = await h.store(videos);
    final clips = await h.clips.clipsByIds(ids);
    return {for (final c in clips) c.mediaStoreId!: c};
  }

  test('verifier skips without full access', () async {
    final clips = await stored([video(1), video(2)]);
    // Under limited access a query returns only the picked videos: here none.
    bridge.put([]);
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      bridge.access = MediaAccess(level: level, canAskAgain: true, sdkInt: 34);

      expect(
        await h.verifier.verify(clips.values),
        outcome(skipped: {for (final c in clips.values) c.id}),
      );
    }

    expect(bridge.calls.toSet(), {'accessReport'});
    for (final c in await h.allClips()) {
      expect(c.missing, isFalse);
      expect(c.lastVerifiedAt, isNull);
    }
    expect(await h.toTag(), hasLength(2));
  });

  test('found / missing / detached sorting', () async {
    final clips = await stored([video(1), video(2), video(3)]);
    // In a reel, so the missing ones keep their rows to look at.
    final reel = await reels.create('Goa');
    await h.clips.addClipsToReel(reel.id, [for (final c in clips.values) c.id]);
    // 1 is there, 2 is gone, 3's number now holds a different video.
    bridge.put([video(1), video(3, sizeBytes: 42)]);
    await h.clips.recordVerification(found: {}, missing: {clips[1]!.id});
    h.clock.advance(const Duration(hours: 1));

    final result = await h.verifier.verify(clips.values);

    expect(
      result,
      outcome(found: {clips[1]!.id}, missing: {clips[2]!.id, clips[3]!.id}),
    );
    final found = await h.clip(clips[1]!.id);
    final gone = await h.clip(clips[2]!.id);
    final other = await h.clip(clips[3]!.id);
    expect((found.mediaStoreId, found.missing), (1, false));
    expect(found.lastVerifiedAt, h.clock.now());
    expect((gone.mediaStoreId, gone.missing), (2, true));
    expect(gone.lastVerifiedAt, h.clock.now());
    expect((other.mediaStoreId, other.missing), (-other.id, true));
    expect(other.lastVerifiedAt, h.clock.now());
  });

  test('unmounted volume is skipped', () async {
    final clips = await stored([video(1), video(2, volume: card)]);
    bridge
      ..put([video(1)])
      ..put([], volume: card, version: 'c1')
      ..setVolume(card, version: null);

    expect(
      await h.verifier.verify(clips.values),
      outcome(found: {clips[1]!.id}, skipped: {clips[2]!.id}),
    );

    bridge.removeVolume(card);
    expect(
      await h.verifier.verify(clips.values),
      outcome(found: {clips[1]!.id}, skipped: {clips[2]!.id}),
    );
    expect(bridge.byIds.map((q) => q.$1), everyElement(phone));
    final onCard = await h.clip(clips[2]!.id);
    expect(onCard.missing, isFalse);
    expect(onCard.lastVerifiedAt, isNull);
    expect(await h.toTag(), hasLength(2));
  });

  test(
    'missing inbox clip leaves To tag, missing reel clip is flagged',
    () async {
      final clips = await stored([video(1), video(2), video(3)]);
      await h.clips.skip([clips[2]!.id]);
      final reel = await reels.create('Goa');
      await h.clips.tagClip(clips[3]!.id, {reel.id});
      bridge.put([]);

      final result = await h.verifier.verify(clips.values);

      expect(result.missing, {for (final c in clips.values) c.id});
      expect(await h.toTag(), isEmpty);
      expect(await h.skipped(), isEmpty);
      final inReel = await h.clips.watchReelClips(reel.id).first;
      expect(
        [for (final c in inReel) (c.id, c.missing)],
        [(clips[3]!.id, true)],
      );
      expect([for (final c in await h.allClips()) c.id], [clips[3]!.id]);
    },
  );

  test('a missing clip in both To tag and a reel is flagged and stays in the '
      'reel', () async {
    final clips = await stored([video(1)]);
    final id = clips[1]!.id;
    final reel = await reels.create('Goa');
    await h.clips.tagClip(id, {reel.id});
    // The repository never leaves a clip in a reel and a list at once, so put
    // the inbox row back by hand.
    await h.db
        .into(h.db.inbox)
        .insert(
          InboxCompanion.insert(
            clipId: Value(id),
            state: InboxState.pending,
            addedAt: h.clock.now(),
          ),
        );
    bridge.put([]);

    expect(await h.verifier.verify(clips.values), outcome(missing: {id}));

    expect(await h.toTag(), isEmpty);
    final inReel = await h.clips.watchReelClips(reel.id).first;
    expect([for (final c in inReel) (c.id, c.missing)], [(id, true)]);
  });

  test('1201 ids → 3 batches', () async {
    final all = [for (var i = 1; i <= 1201; i++) video(i)];
    final clips = await stored(all);
    bridge.put(all);

    final result = await h.verifier.verify(clips.values);

    expect(result.found, hasLength(1201));
    expect([for (final q in bridge.byIds) q.$2.length], [500, 500, 201]);
    final asked = [for (final q in bridge.byIds) ...q.$2];
    expect(asked.toSet(), {for (var i = 1; i <= 1201; i++) i});
  });

  test('clips are grouped by volume', () async {
    await h.store([video(1), video(1, volume: card), video(2)]);
    bridge
      ..put([video(1), video(2)])
      ..put(
        [video(1, volume: card)],
        volume: card,
        version: 'c1',
      );

    final result = await h.verifier.verify(await h.allClips());

    expect(result.found, hasLength(3));
    expect(bridge.byIds, hasLength(2));
    expect(
      {for (final (volume, ids) in bridge.byIds) volume: ids.toSet()},
      {
        phone: {1, 2},
        card: {1},
      },
    );
  });

  test('detached clips are skipped', () async {
    final clips = await stored([video(1), video(2)]);
    await h.clips.detach({clips[2]!.id});
    bridge.put([video(1), video(2)]);

    expect(
      await h.verifier.verify(clips.values),
      outcome(found: {clips[1]!.id}, skipped: {clips[2]!.id}),
    );
    expect([for (final q in bridge.byIds) ...q.$2], [1]);
    expect((await h.clip(clips[2]!.id)).mediaStoreId, -clips[2]!.id);
  });

  test('picked clips and clips that no longer exist are skipped', () async {
    final clips = await stored([video(1)]);
    final reel = await reels.create('Goa');
    final picked = await h.clips.addNewClipsToReel(reel.id, [
      NewClip.picker(
        pickerUri: 'content://picker/1',
        fingerprint: ClipFingerprint(
          sizeBytes: 5,
          durationMs: 5,
          dateTakenUtc: h.clock.now(),
          displayName: 'p.mp4',
        ),
        width: 0,
        height: 0,
        mimeType: 'video/mp4',
      ),
    ]);
    final ghost = clips[1]!.copyWith(id: 999);
    bridge.put([video(1)]);

    expect(
      await h.verifier.verify([
        ...clips.values,
        ghost,
        ...await h.clips.clipsByIds(picked),
      ]),
      outcome(found: {clips[1]!.id}, skipped: {999, picked.single}),
    );
  });

  test('verifyAll counts', () async {
    final clips = await stored([video(1), video(2), video(3, volume: card)]);
    bridge
      ..put([video(1)])
      ..put([], volume: card, version: 'c1')
      ..setVolume(card, version: null);

    expect(
      await h.verifier.verifyAll(),
      outcome(
        found: {clips[1]!.id},
        missing: {clips[2]!.id},
        skipped: {clips[3]!.id},
      ),
    );
  });

  test('nothing to verify asks the phone nothing', () async {
    expect(await h.verifier.verify([]), outcome());
    expect(await h.verifier.verifyAll(), outcome());
    expect(bridge.calls, isEmpty);
  });

  test(
    'videosByIds failing for one volume skips its clips, never missing',
    () async {
      // 600 clips on the phone (two batches), one on the card. The second
      // phone batch fails: none of the phone's clips may count as checked.
      final h = MediaHarness(bridge: _FailOnSecondPhoneBatch());
      final ids = await h.store([
        for (var i = 1; i <= 600; i++) video(i),
        video(7, volume: card),
      ]);
      h.bridge
        ..put([for (var i = 1; i <= 600; i++) video(i)])
        ..put([], volume: card, version: 'c1');
      final phoneIds = ids.take(600).toSet();

      final result = await h.verifier.verifyAll();

      expect(result, outcome(missing: {ids.last}, skipped: phoneIds));
      expect(h.bridge.byIds.map((q) => q.$1), [phone, phone, card]);
      for (final c in await h.allClips()) {
        if (c.volumeName == phone) {
          expect(c.missing, isFalse);
          expect(c.lastVerifiedAt, isNull);
        }
      }
      expect(await h.toTag(), hasLength(600));
    },
  );

  test('a failing volume list throws and writes nothing', () async {
    final clips = await stored([video(1)]);
    bridge
      ..put([])
      ..failNext('volumes');

    await expectLater(
      h.verifier.verify(clips.values),
      throwsA(isA<PlatformException>()),
    );
    final clip = await h.clip(clips[1]!.id);
    expect(clip.missing, isFalse);
    expect(clip.lastVerifiedAt, isNull);
  });

  test('a verify called during a paused scan runs after it, and does not '
      'detach a clip the scan remapped', () async {
    // The library was rebuilt: clip A's video is now number 21, and number 1
    // holds a different video.
    final a = video(1);
    bridge.put([a], generation: 10);
    final clipA = (await stored([a]))[1]!;
    await h.turnOnNow();
    bridge
      ..videosByVolume[phone] = []
      ..put([
        a.copyWith(mediaStoreId: 21),
        video(1, sizeBytes: 7),
      ], version: 'v2');
    final gate = bridge.gate('allVideos');

    final scan = h.scanner.scan();
    await until(() => bridge.calls.contains('allVideos'));
    final verify = h.verifier.verify([clipA]);
    await settle();
    expect(bridge.calls, isNot(contains('videosByIds')));
    gate.complete();
    await scan;
    final result = await verify;

    expect(result, outcome(found: {clipA.id}));
    expect(bridge.byIds.single.$2, [21]);
    final now = await h.clip(clipA.id);
    expect((now.mediaStoreId, now.missing), (21, false));
  });

  test('mediaVerifierProvider builds one verifier', () {
    final db = testDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaBridgeProvider.overrideWithValue(FakeMediaBridge()),
      ],
    );
    addTearDown(container.dispose);
    final verifier = container.read(mediaVerifierProvider);
    expect(container.read(mediaVerifierProvider), same(verifier));
  });
}

/// The second `videosByIds` call for the phone fails, like a phone that
/// stops answering halfway through a volume.
class _FailOnSecondPhoneBatch extends RecordingBridge {
  int _phoneBatches = 0;

  @override
  Future<List<MediaVideo>> videosByIds(String volumeName, List<int> ids) async {
    final answer = await super.videosByIds(volumeName, ids);
    if (volumeName == phone && ++_phoneBatches == 2) {
      throw PlatformException(code: 'native-error', message: 'boom');
    }
    return answer;
  }
}
