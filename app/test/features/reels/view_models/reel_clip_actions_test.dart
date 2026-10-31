import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/media_clip.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';

import '../../../support/clip_setup.dart';
import '../../../support/reel_videos.dart';
import '../../../support/vm_harness.dart';

/// A clips repository whose `addClipsToReel` fails for one reel.
class _FailingAdd extends ClipsRepository {
  _FailingAdd(VmHarness h, this.failFor) : super(h.media.db, h.media.clock);

  final int failFor;

  @override
  Future<AddUndo> addClipsToReel(int reelId, Iterable<int> clipIds) {
    if (reelId == failFor) return Future.error(StateError('disk full'));
    return super.addClipsToReel(reelId, clipIds);
  }
}

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ClipsRepository clips;
  late ReelClipActions actions;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    clips = h.container.read(clipsRepositoryProvider);
    actions = h.container.read(reelClipActionsProvider);
  });

  Future<Set<int>> clipIdsOf(int reelId) async => {
    for (final c in await clips.watchReelClips(reelId).first) c.clip.id,
  };

  group('add', () {
    test(
      'adds the clips to every picked reel and names them in pick order',
      () async {
        final goa = await reels.create('Goa');
        final london = await reels.create('London');
        final paris = await reels.create('Paris');
        final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);

        final outcome = await actions.addToReels(
          clipIds: ids.toSet(),
          reelIds: [paris.id, london.id],
        );

        expect(outcome.reelNames, ['Paris', 'London']);
        expect(outcome.records, hasLength(2));
        expect(outcome.records.every((r) => r is AddUndo), isTrue);
        expect(outcome.isEmpty, isFalse);
        expect(await clipIdsOf(paris.id), ids.toSet());
        expect(await clipIdsOf(london.id), ids.toSet());
        // The clips stay where they were.
        expect(await clipIdsOf(goa.id), ids.toSet());
      },
    );

    test('undoing every record puts everything back', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final paris = await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final outcome = await actions.addToReels(
        clipIds: ids.toSet(),
        reelIds: [london.id, paris.id],
      );

      for (final record in outcome.records.reversed) {
        await clips.undo(record);
      }

      expect(await clipIdsOf(london.id), isEmpty);
      expect(await clipIdsOf(paris.id), isEmpty);
      expect(await clipIdsOf(goa.id), ids.toSet());
    });

    test('clips the reel has already make an empty outcome', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      await clips.addClipsToReel(london.id, ids);

      final outcome = await actions.addToReels(
        clipIds: ids.toSet(),
        reelIds: [london.id],
      );

      expect(outcome.isEmpty, isTrue);
      expect(outcome.reelNames, ['London']);
    });

    test('a reel that is gone fails before anything is written', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);

      await expectLater(
        actions.addToReels(clipIds: ids.toSet(), reelIds: [london.id, 999]),
        throwsStateError,
      );

      expect(await clipIdsOf(london.id), isEmpty);
    });

    test('a failure on the second reel takes the first back', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final paris = await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final failing = ReelClipActions(reels, _FailingAdd(h, paris.id));

      await expectLater(
        failing.addToReels(
          clipIds: ids.toSet(),
          reelIds: [london.id, paris.id],
        ),
        throwsStateError,
      );

      expect(await clipIdsOf(london.id), isEmpty);
      expect(await clipIdsOf(paris.id), isEmpty);
    });

    test('no reels is an error', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);

      await expectLater(
        actions.addToReels(clipIds: ids.toSet(), reelIds: const []),
        throwsArgumentError,
      );
    });

    test('adding a clip out of To tag takes it out of To tag, and undo '
        'brings it back', () async {
      final goa = await reels.create('Goa');
      final ids = await h.media.clips.saveDetected([
        newClipFrom(reelVideo(1), now: reelTestNow, zoneId: null),
      ]);
      await clips.skip(ids);

      final outcome = await actions.addToReels(
        clipIds: ids.toSet(),
        reelIds: [goa.id],
      );
      expect(await clipIdsOf(goa.id), ids.toSet());

      await clips.undo(outcome.records.single);
      expect(await clipIdsOf(goa.id), isEmpty);
    });
  });

  group('move', () {
    test('moves the clips and names the target', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);

      final outcome = await actions.moveToReel(
        fromReelId: goa.id,
        toReelId: london.id,
        clipIds: ids.toSet(),
      );

      expect(outcome.reelNames, ['London']);
      expect(outcome.records.single, isA<MoveUndo>());
      expect(await clipIdsOf(goa.id), isEmpty);
      expect(await clipIdsOf(london.id), ids.toSet());
    });

    test('move removes from this reel and Undo puts it back', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final outcome = await actions.moveToReel(
        fromReelId: goa.id,
        toReelId: london.id,
        clipIds: ids.toSet(),
      );

      await clips.undo(outcome.records.single);

      expect(await clipIdsOf(goa.id), ids.toSet());
      expect(await clipIdsOf(london.id), isEmpty);
    });

    test('a target that is gone fails and moves nothing', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);

      await expectLater(
        actions.moveToReel(
          fromReelId: goa.id,
          toReelId: 999,
          clipIds: ids.toSet(),
        ),
        throwsStateError,
      );

      expect(await clipIdsOf(goa.id), ids.toSet());
    });
  });

  group('remove', () {
    test('removes and counts the clips taken out', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1),
        reelVideo(2),
        reelVideo(3),
      ]);

      final outcome = await actions.removeFromReel(
        reelId: goa.id,
        clipIds: {ids[0], ids[1]},
      );

      expect(outcome.clipCount, 2);
      expect(outcome.reelNames, ['Goa']);
      expect(outcome.records.single, isA<RemoveUndo>());
      expect(await clipIdsOf(goa.id), {ids[2]});
    });

    test('remove snack Undo restores the clips with their ids', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final outcome = await actions.removeFromReel(
        reelId: goa.id,
        clipIds: ids.toSet(),
      );
      // The only reel: the clip row was swept.
      expect(await clips.allClipIds(), isEmpty);

      await clips.undo(outcome.records.single);

      expect(await clips.allClipIds(), ids.toSet());
      expect(await clipIdsOf(goa.id), ids.toSet());
    });

    test('clips the reel does not have give an empty outcome', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, london.id, [reelVideo(1)]);

      final outcome = await actions.removeFromReel(
        reelId: goa.id,
        clipIds: ids.toSet(),
      );

      expect(outcome.isEmpty, isTrue);
      expect(outcome.clipCount, 0);
      expect(await clipIdsOf(london.id), ids.toSet());
    });
  });

  group('logs', () {
    test('hold ids and counts, never a reel name', () async {
      final logs = captureLogs();
      final goa = await reels.create('Secret Goa Name');
      final london = await reels.create('Secret London Name');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);

      await actions.addToReels(clipIds: ids.toSet(), reelIds: [london.id]);
      await actions.moveToReel(
        fromReelId: goa.id,
        toReelId: london.id,
        clipIds: ids.toSet(),
      );
      await actions.removeFromReel(reelId: london.id, clipIds: ids.toSet());

      expect(logs, isNotEmpty);
      expect(logText(logs), isNot(contains('Secret')));
    });
  });

  test('the provider is kept alive', () {
    final container = ProviderContainer.test(overrides: h.overrides);
    final first = container.read(reelClipActionsProvider);
    expect(container.read(reelClipActionsProvider), same(first));
  });
}
