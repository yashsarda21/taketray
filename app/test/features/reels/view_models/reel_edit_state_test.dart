import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/rules/shooting_days.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/platform/copy_bridge.dart';

import '../../../support/reel_videos.dart';
import '../../../support/vm_harness.dart';
import '../edit_session_support.dart';

void main() {
  late VmHarness h;
  late ProviderContainer c;
  late ReelsRepository reels;

  setUp(() {
    h = reelHarness();
    c = h.container;
    reels = c.read(reelsRepositoryProvider);
  });

  /// Reel "Goa" with clips shot on 28 Oct (ids 1–3) and 29 Oct (ids 4–5).
  Future<(int, List<int>)> goaReel() async {
    final goa = await reels.create('Goa');
    final ids = await putInReel(h, goa.id, [
      for (final (id, day, hour) in [
        (1, 28, 9),
        (2, 28, 10),
        (3, 28, 11),
        (4, 29, 9),
        (5, 29, 10),
      ])
        reelVideo(id, shot: DateTime.utc(2026, 10, day, hour)),
    ]);
    return (goa.id, ids);
  }

  /// Keeps reel [id]'s edit state alive and returns its latest value.
  Future<ReelEditState?> stateOf(int id) async {
    final sub = c.listen(reelEditStateProvider(id), (_, _) {});
    addTearDown(sub.close);
    await settle();
    return await c.read(reelEditStateProvider(id).future);
  }

  List<List<int>> idsByDay(List<ShootingDay<ReelClip>> days) => [
    for (final d in days) [for (final rc in d.clips) rc.clip.id],
  ];

  group('reelEditState', () {
    test('is null for a reel with no session', () async {
      final (goa, _) = await goaReel();

      expect(await stateOf(goa), isNull);
    });

    test('a session of another reel leaves this one plain', () async {
      final (goa, _) = await goaReel();
      final london = await reels.create('London');
      await startEditing(h, london.id, EditorApp.vn, folder: 'London');

      expect(await stateOf(goa), isNull);
    });

    test('splits into new and in your edit by sent ∪ live copies', () async {
      final (goa, ids) = await goaReel();
      // 1 copied, 2 sent, 4 both; 3 and 5 are new.
      await startEditing(
        h,
        goa,
        EditorApp.capcut,
        copied: [ids[0], ids[3]],
        sent: [ids[1], ids[3]],
        copySize: 200 * 1000 * 1000,
      );

      final state = (await stateOf(goa))!;

      expect(state.editor, EditorApp.capcut);
      expect(state.session.folderName, 'Goa');
      expect(state.copyCount, 2);
      expect(state.copyBytes, 400 * 1000 * 1000);
      expect(state.newCount, 2);
      expect(state.inEditCount, 3);
      expect(idsByDay(state.newDays), [
        [ids[2]],
        [ids[4]],
      ]);
      expect(idsByDay(state.inEditDays), [
        [ids[0], ids[1]],
        [ids[3]],
      ]);
      expect(state.newLiveIds, [ids[2], ids[4]]);
    });

    test('a sent clip with no copy is in the edit (the union, not only '
        'copies)', () async {
      final (goa, ids) = await goaReel();
      await startEditing(h, goa, EditorApp.edits, sent: [ids[0]]);

      final state = (await stateOf(goa))!;

      expect(idsByDay(state.inEditDays), [
        [ids[0]],
      ]);
      expect(state.newCount, 4);
      expect(state.copyCount, 0);
      expect(state.copyBytes, 0);
    });

    test('a copied clip that was never sent is in the edit (the union, not '
        'only sent)', () async {
      final (goa, ids) = await goaReel();
      await startEditing(h, goa, EditorApp.vn, copied: [ids[4]]);

      final state = (await stateOf(goa))!;

      expect(idsByDay(state.inEditDays), [
        [ids[4]],
      ]);
      expect(state.inEditCount, 1);
    });

    test(
      "each part keeps the reel's own Day numbers and drops empty days",
      () async {
        final (goa, ids) = await goaReel();
        await startEditing(
          h,
          goa,
          EditorApp.vn,
          copied: [ids[0], ids[1], ids[2]],
        );

        final state = (await stateOf(goa))!;

        expect([for (final d in state.inEditDays) d.number], [1]);
        // Day 2 of the reel stays Day 2 in the new part, though it is the
        // part's only day.
        expect([for (final d in state.newDays) d.number], [2]);
        expect(idsByDay(state.newDays), [
          [ids[3], ids[4]],
        ]);
      },
    );

    test('no new clips: the new part is empty', () async {
      final (goa, ids) = await goaReel();
      await startEditing(h, goa, EditorApp.vn, copied: ids);

      final state = (await stateOf(goa))!;

      expect(state.newCount, 0);
      expect(state.newDays, isEmpty);
      expect(state.newLiveIds, isEmpty);
      expect(state.inEditCount, 5);
    });

    test('a missing clip stays in its part, and is no clip to copy', () async {
      final (goa, ids) = await goaReel();
      await startEditing(h, goa, EditorApp.vn, copied: [ids[0]]);
      await flagForTest(h, {ids[0], ids[2]}, missing: true);

      final state = (await stateOf(goa))!;

      expect(idsByDay(state.inEditDays), [
        [ids[0]],
      ]);
      expect(idsByDay(state.newDays), [
        [ids[1], ids[2]],
        [ids[3], ids[4]],
      ]);
      expect(state.newCount, 4);
      expect(state.newLiveIds, [ids[1], ids[3], ids[4]]);
    });

    test('a clip tagged in meanwhile is new at once', () async {
      final (goa, ids) = await goaReel();
      await startEditing(h, goa, EditorApp.vn, copied: ids);
      final seen = <int>[];
      final sub = c.listen(
        reelEditStateProvider(goa),
        (_, next) => next.whenData((s) => seen.add(s?.newCount ?? -1)),
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await settle();

      final [late] = await putInReel(h, goa, [
        reelVideo(9, shot: DateTime.utc(2026, 10, 29, 20)),
      ]);
      await settle();

      final state = (await c.read(reelEditStateProvider(goa).future))!;
      expect(state.newLiveIds, [late]);
      expect(seen.last, 1);
    });

    test('a copy forgotten by the copy check makes its clip new', () async {
      final (goa, ids) = await goaReel();
      final copies = await startEditing(
        h,
        goa,
        EditorApp.vn,
        copied: [ids[0], ids[1]],
      );
      expect((await stateOf(goa))!.inEditCount, 2);

      // The first copy was deleted outside TakeTray: the check forgets it.
      await c.read(editSessionsRepositoryProvider).removeCopies(goa, [
        copies[0],
      ]);
      await settle();

      final state = (await c.read(reelEditStateProvider(goa).future))!;
      expect(idsByDay(state.inEditDays), [
        [ids[1]],
      ]);
      expect(state.newLiveIds, [ids[0], ids[2], ids[3], ids[4]]);
      expect(state.copyCount, 1);
    });

    test('a sent clip whose copy is gone stays in the edit', () async {
      final (goa, ids) = await goaReel();
      final copies = await startEditing(
        h,
        goa,
        EditorApp.capcut,
        copied: [ids[0]],
        sent: [ids[0]],
      );
      await c.read(editSessionsRepositoryProvider).removeCopies(goa, [
        copies[0],
      ]);

      final state = (await stateOf(goa))!;

      expect(idsByDay(state.inEditDays), [
        [ids[0]],
      ]);
    });

    test('becomes null when Done editing ends the session', () async {
      final (goa, ids) = await goaReel();
      await startEditing(h, goa, EditorApp.vn, copied: [ids[0]]);
      expect(await stateOf(goa), isNotNull);

      await c.read(editSessionsRepositoryProvider).endSession(goa);
      await settle();

      expect(await c.read(reelEditStateProvider(goa).future), isNull);
    });
  });

  group('reelEditors', () {
    test('maps every reel being edited to its editor, and follows', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final seen = <Map<int, EditorApp>>[];
      final sub = c.listen(
        reelEditorsProvider,
        (_, next) => next.whenData(seen.add),
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await settle();

      await startEditing(h, goa.id, EditorApp.vn);
      await settle();
      await startEditing(h, london.id, EditorApp.edits, folder: 'London');
      await settle();
      await c.read(editSessionsRepositoryProvider).endSession(goa.id);
      await settle();

      expect(seen, [
        <int, EditorApp>{},
        {goa.id: EditorApp.vn},
        {goa.id: EditorApp.vn, london.id: EditorApp.edits},
        {london.id: EditorApp.edits},
      ]);
    });
  });

  group('runningCopyJobOf', () {
    CopyJob job(int reelId, CopyState state) => CopyJob(
      jobId: '$reelId-1',
      reelId: reelId,
      folderName: 'Goa',
      state: state,
      total: 3,
      done: 1,
      bytesDone: 1,
      bytesTotal: 3,
      copied: const [],
      failedClipIds: const [],
      undeleted: const [],
    );

    test('is the job only while it runs, and only for this reel', () {
      expect(runningCopyJobOf(job(7, CopyState.running), 7)?.jobId, '7-1');
      expect(runningCopyJobOf(job(8, CopyState.running), 7), isNull);
      expect(runningCopyJobOf(null, 7), isNull);
      for (final state in CopyState.values) {
        if (state == CopyState.running) continue;
        expect(runningCopyJobOf(job(7, state), 7), isNull, reason: '$state');
      }
    });
  });
}
