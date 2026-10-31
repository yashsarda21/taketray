import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/features/reels/view_models/clip_viewer_controller.dart';

import '../../../support/reel_videos.dart';
import '../../../support/vm_harness.dart';

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ClipsRepository clips;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    clips = h.container.read(clipsRepositoryProvider);
  });

  /// Opens the viewer on [clipId] of [reelId] like the screen does and keeps
  /// it open.
  ProviderContainer open(int reelId, int clipId) =>
      ProviderContainer.test(overrides: h.overrides)
        ..listen(clipViewerControllerProvider(reelId, clipId), (_, _) {});

  Future<ClipViewerState?> stateOf(
    ProviderContainer c,
    int reelId,
    int clipId,
  ) => c.read(clipViewerControllerProvider(reelId, clipId).future);

  /// Lets the controller see the database's latest answer.
  Future<ClipViewerState?> settled(
    ProviderContainer c,
    int reelId,
    int clipId,
  ) async {
    await pumpEventQueue();
    return await stateOf(c, reelId, clipId);
  }

  group('the pager', () {
    test('missing clips are not in the pager', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1),
        reelVideo(2),
        reelVideo(3),
        reelVideo(4),
      ]);
      await flagForTest(h, {ids[1], ids[3]}, missing: true);
      final c = open(goa.id, ids[0]);

      final state = await stateOf(c, goa.id, ids[0]);

      expect(state!.clips.map((rc) => rc.clip.id), [ids[0], ids[2]]);
      expect(state.clips.every((rc) => !rc.clip.missing), isTrue);
      expect(state.reel.name, 'Goa');
    });

    test("the clips are in the reel's order, oldest shot first", () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1, shot: DateTime.utc(2026, 10, 28, 12)),
        reelVideo(2, shot: DateTime.utc(2026, 10, 27, 12)),
        reelVideo(3, shot: DateTime.utc(2026, 10, 29, 12)),
      ]);
      final c = open(goa.id, ids[0]);

      final state = await stateOf(c, goa.id, ids[0]);

      expect(state!.clips.map((rc) => rc.clip.id), [ids[1], ids[0], ids[2]]);
      expect(state.index, 1);
    });

    test('opens on the tapped clip', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1),
        reelVideo(2),
        reelVideo(3),
      ]);
      final c = open(goa.id, ids[2]);

      final state = await stateOf(c, goa.id, ids[2]);

      expect(state!.index, 2);
      expect(state.current.clip.id, ids[2]);
    });

    test('a clip that is missing opens nothing, never another clip', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      await flagForTest(h, {ids[0]}, missing: true);
      final c = open(goa.id, ids[0]);

      expect(await stateOf(c, goa.id, ids[0]), isNull);
    });

    test('a clip that is not in the reel opens nothing', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final others = await putInReel(h, london.id, [reelVideo(2)]);
      final c = open(goa.id, others.single);

      expect(await stateOf(c, goa.id, others.single), isNull);
      // And the clip that is there is not opened for it either.
      expect(ids, hasLength(1));
    });

    test('a reel that is gone opens nothing', () async {
      final c = open(99, 1);

      expect(await stateOf(c, 99, 1), isNull);
    });

    test('goTo moves the index and ignores one that is not there', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1),
        reelVideo(2),
        reelVideo(3),
      ]);
      final c = open(goa.id, ids[0]);
      await stateOf(c, goa.id, ids[0]);
      final provider = clipViewerControllerProvider(goa.id, ids[0]);
      int index() => c.read(provider).value!.index;

      c.read(provider.notifier).goTo(2);
      expect(index(), 2);
      // An index that is not there changes nothing.
      c.read(provider.notifier)
        ..goTo(3)
        ..goTo(-1);
      expect(index(), 2);
      c.read(provider.notifier).goTo(0);
      expect(index(), 0);
      expect(c.read(provider).value!.current.clip.id, ids[0]);
    });

    test('the clip it is on survives a change of the list', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(3)]);
      final c = open(goa.id, ids[1]);
      await stateOf(c, goa.id, ids[1]);

      // A clip shot earlier joins the reel: the viewer stays on its clip.
      await putInReel(h, goa.id, [
        reelVideo(2, shot: DateTime.utc(2026, 10, 1, 8)),
      ]);
      final state = await settled(c, goa.id, ids[1]);

      expect(state!.clips, hasLength(3));
      expect(state.current.clip.id, ids[1]);
      expect(state.index, 2);
    });
  });

  group('leaving a clip', () {
    test(
      'remove leaves to the next clip, then the previous, then closes',
      () async {
        final goa = await reels.create('Goa');
        final ids = await putInReel(h, goa.id, [
          reelVideo(1),
          reelVideo(2),
          reelVideo(3),
        ]);
        final c = open(goa.id, ids[1]);
        await stateOf(c, goa.id, ids[1]);

        // Middle clip removed: the one after it.
        await clips.removeClipsFromReel(goa.id, {ids[1]});
        var state = await settled(c, goa.id, ids[1]);
        expect(state!.clips.map((rc) => rc.clip.id), [ids[0], ids[2]]);
        expect(state.current.clip.id, ids[2]);

        // The last clip removed: the one before it.
        await clips.removeClipsFromReel(goa.id, {ids[2]});
        state = await settled(c, goa.id, ids[1]);
        expect(state!.current.clip.id, ids[0]);

        // The only clip removed: nothing left, the viewer closes.
        await clips.removeClipsFromReel(goa.id, {ids[0]});
        state = await settled(c, goa.id, ids[1]);
        expect(state, isNull);
      },
    );

    test('move leaves the same way', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = open(goa.id, ids[1]);
      await stateOf(c, goa.id, ids[1]);

      await clips.moveClips(goa.id, london.id, {ids[1]});
      var state = await settled(c, goa.id, ids[1]);
      expect(state!.current.clip.id, ids[0]);

      await clips.moveClips(goa.id, london.id, {ids[0]});
      state = await settled(c, goa.id, ids[1]);
      expect(state, isNull);
    });

    test('a clip that turns missing is skipped, not played', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = open(goa.id, ids[0]);
      await stateOf(c, goa.id, ids[0]);

      await flagForTest(h, {ids[0]}, missing: true);
      final state = await settled(c, goa.id, ids[0]);

      expect(state!.clips.map((rc) => rc.clip.id), [ids[1]]);
      expect(state.current.clip.id, ids[1]);
    });

    test('Undo after the viewer closed still restores the clip', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final c = open(goa.id, ids[0]);
      await stateOf(c, goa.id, ids[0]);
      final undo = await clips.removeClipsFromReel(goa.id, {ids[0]});
      expect(await settled(c, goa.id, ids[0]), isNull);
      c.dispose();

      await clips.undo(undo);

      final back = await clips.watchReelClips(goa.id).first;
      expect(back.map((rc) => rc.clip.id), ids);
    });
  });

  group('times', () {
    test('each clip has the time where it was shot', () async {
      h.bridge.currentZone = 'Asia/Kolkata';
      final goa = await reels.create('Goa');
      final home = await putInReel(h, goa.id, [
        reelVideo(1, shot: DateTime.utc(2026, 7, 1, 8)),
      ], zoneId: 'Asia/Kolkata');
      final abroad = await putInReel(h, goa.id, [
        reelVideo(2, shot: DateTime.utc(2026, 7, 1, 12)),
      ], zoneId: 'Europe/London');
      final c = open(goa.id, home.single);
      await stateOf(c, goa.id, home.single);

      final state = await settled(c, goa.id, home.single);

      final here = state!.times[home.single]!;
      expect(here.isPhoneZone, isTrue);
      expect(here.wallClock, DateTime.utc(2026, 7, 1, 13, 30));
      final there = state.times[abroad.single]!;
      expect(there.isPhoneZone, isFalse);
      expect(there.zoneId, 'Europe/London');
      expect(there.wallClock, DateTime.utc(2026, 7, 1, 13));
    });

    test('the clips open without waiting for the times', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final gate = h.bridge.gate('zoneOffsetsMs');
      final c = open(goa.id, ids.single);

      final state = await stateOf(c, goa.id, ids.single);

      expect(state!.current.clip.id, ids.single);
      expect(state.times, isEmpty);
      gate.complete();
    });
  });

  group('the reels a clip is in', () {
    test('in-reels names, by reel, again after a change', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final c = ProviderContainer.test(overrides: h.overrides)
        ..listen(clipReelNamesProvider(ids.single), (_, _) {});

      expect(await c.read(clipReelNamesProvider(ids.single).future), ['Goa']);

      await clips.addClipsToReel(london.id, {ids.single});
      await pumpEventQueue();
      expect(await c.read(clipReelNamesProvider(ids.single).future), [
        'Goa',
        'London',
      ]);

      await reels.rename(london.id, 'Lisbon');
      await pumpEventQueue();
      expect(await c.read(clipReelNamesProvider(ids.single).future), [
        'Goa',
        'Lisbon',
      ]);
    });
  });
}
