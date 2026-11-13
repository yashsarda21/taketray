import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/media_clip.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';

import '../../../support/clip_setup.dart';
import '../../../support/reel_videos.dart';
import '../../../support/spy_edit_session_service.dart';
import '../../../support/vm_harness.dart';

/// A reels repository where [vanishes] is deleted (by someone else) just
/// after its name was read, so the add finds the reel gone.
class _VanishingReel extends ReelsRepository {
  // ignore: use_super_parameters, the parameters of ReelsRepository are private
  _VanishingReel(AppDatabase db, Clock clock, this.vanishes) : super(db, clock);

  final int vanishes;

  @override
  Future<Reel?> getById(int id) async {
    final reel = await super.getById(id);
    if (id == vanishes) await delete(id);
    return reel;
  }
}

/// A clips repository that counts its add calls.
class _CountingClips extends ClipsRepository {
  _CountingClips(VmHarness h) : super(h.media.db, h.media.clock);

  int calls = 0;

  @override
  Future<List<AddUndo>> addClipsToReels(
    Set<int> reelIds,
    Iterable<int> clipIds,
  ) {
    calls++;
    return super.addClipsToReels(reelIds, clipIds);
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

    test('a reel that vanishes after its name was read leaves nothing added '
        'to the others', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final paris = await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final failing = ReelClipActions(
        _VanishingReel(h.media.db, h.media.clock, paris.id),
        clips,
        h.container.read(editSessionServiceProvider),
      );

      await expectLater(
        failing.addToReels(
          clipIds: ids.toSet(),
          reelIds: [london.id, paris.id],
        ),
        throwsStateError,
      );

      expect(await clipIdsOf(london.id), isEmpty);
      expect(await clipIdsOf(goa.id), ids.toSet());
    });

    test('the add is one repository call, not one per reel', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final paris = await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final counting = _CountingClips(h);

      await ReelClipActions(
        reels,
        counting,
        h.container.read(editSessionServiceProvider),
      ).addToReels(clipIds: ids.toSet(), reelIds: [london.id, paris.id]);

      expect(counting.calls, 1);
    });

    test('no reels is an error', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);

      await expectLater(
        actions.addToReels(clipIds: ids.toSet(), reelIds: const []),
        throwsArgumentError,
      );
    });

    test('clips that have gone since the picker opened are dropped before '
        'the write (Phase 5 later item)', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1),
        reelVideo(2),
        reelVideo(3),
      ]);
      // Clip 2 is removed and swept (in no other reel) while the picker is
      // open, as a verify or another screen can do.
      await clips.removeClipsFromReel(goa.id, [ids[1]]);
      expect(await clips.clipsByIds([ids[1]]), isEmpty);

      final outcome = await actions.addToReels(
        clipIds: ids.toSet(),
        reelIds: [london.id],
      );

      expect(await clipIdsOf(london.id), {ids[0], ids[2]});
      expect(outcome.clipCount, 2, reason: 'only the clips still there');
      expect(outcome.isEmpty, isFalse);
      final created = (outcome.records.single as AddUndo).createdLinks;
      expect(created.map((l) => l.clipId).toSet(), {ids[0], ids[2]});
    });

    test('every confirm keeps working, not only the first', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final paris = await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      await clips.removeClipsFromReel(goa.id, [ids[0]]);

      await actions.addToReels(clipIds: ids.toSet(), reelIds: [london.id]);
      await actions.addToReels(clipIds: ids.toSet(), reelIds: [paris.id]);

      expect(await clipIdsOf(london.id), {ids[1]});
      expect(await clipIdsOf(paris.id), {ids[1]});
    });

    test('every clip gone: nothing is written, the outcome is empty and '
        'counts 0', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      await clips.removeClipsFromReel(goa.id, ids);
      final before = (await reels.getById(london.id))!.updatedAt;

      final outcome = await actions.addToReels(
        clipIds: ids.toSet(),
        reelIds: [london.id],
      );

      expect(outcome.isEmpty, isTrue);
      expect(outcome.clipCount, 0);
      expect(outcome.reelNames, ['London']);
      expect(await clipIdsOf(london.id), isEmpty);
      expect((await reels.getById(london.id))!.updatedAt, before);
    });

    test(
      'a reel that is gone still fails, even when clips are gone too',
      () async {
        final goa = await reels.create('Goa');
        final ids = await putInReel(h, goa.id, [reelVideo(1)]);
        await clips.removeClipsFromReel(goa.id, ids);

        await expectLater(
          actions.addToReels(clipIds: ids.toSet(), reelIds: [999]),
          throwsStateError,
        );
      },
    );

    test('adding a clip out of To tag takes it out of To tag, and undo '
        'brings it back', () async {
      final goa = await reels.create('Goa');
      final ids = await h.media.clips.saveDetected([
        newClipFrom(reelVideo(1), now: reelTestNow, zoneId: null),
      ]);
      await clips.skipClips(ids);

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

  group('during an editing session (R8, D-123, p8-task6)', () {
    late SpyEditSessionService spy;
    late ReelClipActions hooked;

    setUp(() {
      spy = SpyEditSessionService(h);
      final container = ProviderContainer.test(
        overrides: [
          ...h.overrides,
          editSessionServiceProvider.overrideWithValue(spy),
        ],
      );
      hooked = container.read(reelClipActionsProvider);
    });

    Future<void> copyOf(int reelId, int clipId, int copyId) =>
        spy.h.container.read(editSessionsRepositoryProvider).recordCopies([
          EditCopy(
            reelId: reelId,
            clipId: clipId,
            copyMediaStoreId: copyId,
            fileName: 'c$copyId.mp4',
            sizeBytes: 10,
            copiedAt: reelTestNow,
          ),
        ]);

    test("remove deletes the clips' copies first, while they are still in "
        'the reel, and says how many', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      await h.container
          .read(editSessionsRepositoryProvider)
          .startSession(goa.id, EditorApp.vn, 'Goa');
      await copyOf(goa.id, ids.first, 501);
      h.editors
        ..allow({'deleteCopies'})
        ..existing = {501};

      final outcome = await hooked.removeFromReel(
        reelId: goa.id,
        clipIds: {ids.first},
      );

      expect(spy.calls, ['leave ${goa.id} ${ids.first}']);
      expect(spy.reelClipsAtLeave.single, ids.toSet());
      expect(outcome.copiesDeleted, 1);
      expect(outcome.clipCount, 1);
      expect(h.editors.existing, isEmpty);
      expect(await clipIdsOf(goa.id), {ids.last});
    });

    test('a remove and a move in a reel with no session touch no bridge '
        '(D-123)', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);

      await hooked.moveToReel(
        fromReelId: goa.id,
        toReelId: paris.id,
        clipIds: {ids.first},
      );
      await hooked.removeFromReel(reelId: goa.id, clipIds: {ids.last});

      expect(spy.calls, hasLength(2));
      expect(h.editors.calls, isEmpty);
      expect(h.copy.calls, isEmpty);
    });

    test('a remove whose copies cannot be deleted removes nothing and '
        'throws', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      spy.failLeave = const CopiesNotDeleted(1);

      await expectLater(
        hooked.removeFromReel(reelId: goa.id, clipIds: ids.toSet()),
        throwsA(isA<CopiesNotDeleted>()),
      );
      expect(await clipIdsOf(goa.id), ids.toSet());
    });

    test('a move asks for the source reel first; when that fails nothing '
        'moves', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);

      final outcome = await hooked.moveToReel(
        fromReelId: goa.id,
        toReelId: paris.id,
        clipIds: {ids.last},
      );
      expect(spy.calls, ['leave ${goa.id} ${ids.last}']);
      expect(spy.reelClipsAtLeave.single, ids.toSet());
      expect(outcome.copiesDeleted, 0);
      expect(await clipIdsOf(paris.id), {ids.last});

      spy.failLeave = const CopiesNotDeleted(2);
      await expectLater(
        hooked.moveToReel(
          fromReelId: goa.id,
          toReelId: paris.id,
          clipIds: {ids.first},
        ),
        throwsA(isA<CopiesNotDeleted>()),
      );
      expect(await clipIdsOf(goa.id), {ids.first});
      expect(await clipIdsOf(paris.id), {ids.last});
    });

    test('an add calls no clean-up', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);

      await hooked.addToReels(clipIds: ids.toSet(), reelIds: [paris.id]);

      expect(spy.calls, isEmpty);
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
