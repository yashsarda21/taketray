import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/editors/view_models/edit_select_controller.dart';
import 'package:taketray/features/editors/view_models/editor_choices.dart';

import '../../support/reel_videos.dart';
import '../../support/vm_harness.dart';
import 'editors_support.dart';

void main() {
  late VmHarness h;
  late ProviderContainer c;

  setUp(() {
    h = reelHarness();
    c = h.container;
  });

  /// Reel with three clips: video 1 shot at 11:00 (size 400), 2 at 09:00
  /// (500), 3 at 10:00 (300, 10 s), so the shooting order is 2, 3, 1.
  Future<(int, List<int>)> reelWithClips() async {
    final goa = (await c.read(reelsRepositoryProvider).create('Goa')).id;
    final ids = await putInReel(h, goa, [
      sizedVideo(1, shot: DateTime.utc(2026, 10, 28, 11), size: 400),
      sizedVideo(2, shot: DateTime.utc(2026, 10, 28, 9), size: 500),
      sizedVideo(
        3,
        shot: DateTime.utc(2026, 10, 28, 10),
        size: 300,
        seconds: 10,
      ),
    ]);
    return (goa, ids);
  }

  /// The controller's state once it has loaded.
  Future<EditSelectState?> load(EditSelectArgs args) async {
    final sub = c.listen(editSelectControllerProvider(args), (_, _) {});
    addTearDown(sub.close);
    return await c.read(editSelectControllerProvider(args).future);
  }

  group('EditSelectController', () {
    test('starts with the preselected clips that are live and in the reel; '
        'the picked clips are in shooting order with their totals', () async {
      final (goa, ids) = await reelWithClips();
      await flagForTest(h, {ids[0]}, missing: true);
      final other = (await c.read(reelsRepositoryProvider).create('Other')).id;
      final [foreign] = await putInReel(h, other, [reelVideo(8)]);

      final state = await load(
        EditSelectArgs(goa, [ids[0], ids[1], ids[2], foreign, 12345]),
      );

      expect(state!.selected, {ids[1], ids[2]});
      // Video 2 (09:00) before video 3 (10:00).
      expect(state.pickedInOrder, [ids[1], ids[2]]);
      expect(state.pickedDurationMs, 14000);
      expect(state.pickedBytes, 800);
      expect(state.liveCount, 2);
      expect(state.allPicked, isTrue);
    });

    test('the picked clips are in shooting order, not in id order', () async {
      final (goa, ids) = await reelWithClips();

      final state = await load(EditSelectArgs(goa, [ids[0], ids[1], ids[2]]));

      // Video 2 (09:00), video 3 (10:00), video 1 (11:00).
      expect(state!.pickedInOrder, [ids[1], ids[2], ids[0]]);
    });

    test(
      'toggle, selectAll and clear only touch live clips of the reel',
      () async {
        final (goa, ids) = await reelWithClips();
        await flagForTest(h, {ids[0]}, missing: true);
        final args = EditSelectArgs(goa, const []);
        await load(args);
        final notifier = c.read(editSelectControllerProvider(args).notifier)
          ..toggle(ids[0])
          ..toggle(9999);
        expect(
          c.read(editSelectControllerProvider(args)).value!.selected,
          isEmpty,
        );

        notifier.toggle(ids[1]);
        expect(c.read(editSelectControllerProvider(args)).value!.selected, {
          ids[1],
        });
        notifier.toggle(ids[1]);
        expect(
          c.read(editSelectControllerProvider(args)).value!.selected,
          isEmpty,
        );

        notifier.selectAll();
        expect(c.read(editSelectControllerProvider(args)).value!.selected, {
          ids[1],
          ids[2],
        });
        notifier.clear();
        expect(
          c.read(editSelectControllerProvider(args)).value!.selected,
          isEmpty,
        );
      },
    );

    test('a clip that turns missing leaves the selection, and the rest '
        'stays picked', () async {
      final (goa, ids) = await reelWithClips();
      final args = EditSelectArgs(goa, ids);
      await load(args);

      await flagForTest(h, {ids[2]}, missing: true);
      // The reel's stream emits again; the controller rebuilds.
      await settle();
      final state = await c.read(editSelectControllerProvider(args).future);

      expect(state!.selected, {ids[0], ids[1]});
      expect(state.liveCount, 2);
    });

    test(
      'a toggle made on the screen survives a rebuild of the list',
      () async {
        final (goa, ids) = await reelWithClips();
        final args = EditSelectArgs(goa, [ids[0]]);
        await load(args);
        c.read(editSelectControllerProvider(args).notifier).toggle(ids[1]);

        // Another clip joins the reel: the list changes.
        await putInReel(h, goa, [reelVideo(5)]);
        await settle();
        final state = await c.read(editSelectControllerProvider(args).future);

        expect(state!.selected, {ids[0], ids[1]});
        expect(state.liveCount, 4);
      },
    );

    test('null once the reel is gone', () async {
      final (goa, _) = await reelWithClips();
      final args = EditSelectArgs(goa, const []);
      await load(args);

      await c.read(reelsRepositoryProvider).delete(goa);
      await settle();

      expect(await c.read(editSelectControllerProvider(args).future), isNull);
      expect(await load(EditSelectArgs(4242, const [])), isNull);
    });

    test('the arguments compare by value', () {
      EditSelectArgs args(int reel, List<int> ids) => EditSelectArgs(reel, ids);

      expect(args(1, [2, 3]), args(1, [2, 3]));
      expect(args(1, [2, 3]).hashCode, args(1, [2, 3]).hashCode);
      expect(args(1, [2, 3]), isNot(args(1, [3, 2])));
      expect(args(1, [2]), isNot(args(2, [2])));
    });
  });

  group('reelInEditingSession', () {
    test('follows the session of the reel', () async {
      final (goa, _) = await reelWithClips();
      final seen = <bool>[];
      final sub = c.listen(
        reelInEditingSessionProvider(goa),
        (_, next) => next.whenData(seen.add),
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await settle();
      final sessions = c.read(editSessionsRepositoryProvider);

      await sessions.startSession(goa, EditorApp.capcut, 'Goa');
      await settle();
      // More rows for the same session do not repeat the answer.
      final inReel = await c
          .read(clipsRepositoryProvider)
          .watchReelClips(goa)
          .first;
      await sessions.recordSent(goa, [for (final rc in inReel) rc.clip.id]);
      await settle();
      await sessions.endSession(goa);
      await settle();

      expect(seen, [false, true, false]);
    });
  });

  group('editorChoices', () {
    test('is what the service says, in editor order', () async {
      h.editors
        ..allow({'apps'})
        ..installed = {EditorApp.capcut.packageName: true};

      final choices = await c.read(editorChoicesProvider.future);

      expect(
        [for (final e in choices) (e.editor, e.installed)],
        [
          (EditorApp.capcut, true),
          (EditorApp.edits, false),
          (EditorApp.vn, false),
        ],
      );
    });

    test('a failing phone call gives all three as installed with no icon, '
        'and logs the error type only', () async {
      h.editors
        ..allow({'apps'})
        ..failNext('apps');
      final lines = <String>[];
      final sub = Logger.root.onRecord.listen((r) => lines.add(r.message));
      addTearDown(sub.cancel);

      final choices = await c.read(editorChoicesProvider.future);

      expect(
        [for (final e in choices) (e.editor, e.installed, e.icon)],
        [
          (EditorApp.capcut, true, null),
          (EditorApp.edits, true, null),
          (EditorApp.vn, true, null),
        ],
      );
      final all = lines.join('\n');
      expect(all, contains('PlatformException'));
      expect(all, isNot(contains('com.')));
      expect(all, isNot(contains('apps failed')));
    });
  });
}
