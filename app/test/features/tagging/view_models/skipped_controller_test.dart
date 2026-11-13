import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/features/tagging/view_models/skipped_controller.dart';
import 'package:taketray/features/tagging/view_models/skipped_selection.dart';

import '../../../support/fake_media_bridge.dart';
import '../../../support/reel_videos.dart';
import '../../../support/vm_harness.dart';

void main() {
  late VmHarness h;
  late ClipsRepository clips;

  setUp(() {
    h = VmHarness();
    clips = h.container.read(clipsRepositoryProvider);
  });

  /// Opens Skipped like the screen does and keeps it open.
  ProviderSubscription<AsyncValue<List<Clip>>> open() =>
      h.container.listen(skippedControllerProvider, (_, _) {});

  List<int?> shownIds() => [
    for (final c
        in h.container.read(skippedControllerProvider).value ?? <Clip>[])
      c.mediaStoreId,
  ];

  /// Stores videos [ids] (generation = id; dates taken in id order, minutes
  /// apart) and skips them.
  Future<List<int>> skipped(List<int> ids) async {
    final stored = await h.media.store([
      for (final id in ids)
        fakeVideo(
          id: id,
          generation: id,
          dateTakenMs: 1780000000000 + id * 60000,
        ),
    ]);
    await clips.skipClips(stored);
    return stored;
  }

  test('shows the skipped clips newest first', () async {
    h.bridge.put([
      for (final id in [1, 2, 3])
        fakeVideo(
          id: id,
          generation: id,
          dateTakenMs: 1780000000000 + id * 60000,
        ),
    ]);
    await skipped([1, 2, 3]);
    open();

    await h.container.read(skippedControllerProvider.future);

    expect(shownIds(), [3, 2, 1]);
  });

  test('a clip waiting in To tag is not in it', () async {
    h.bridge.put([
      for (final id in [1, 2])
        fakeVideo(
          id: id,
          generation: id,
          dateTakenMs: 1780000000000 + id * 60000,
        ),
    ]);
    await skipped([1]);
    await h.media.store([
      fakeVideo(id: 2, generation: 2, dateTakenMs: 1780000000000 + 2 * 60000),
    ]);
    open();

    await h.container.read(skippedControllerProvider.future);

    expect(shownIds(), [1]);
  });

  test(
    'verifies the skipped clips when it opens, not the waiting ones',
    () async {
      h.bridge.put([fakeVideo(id: 1, dateTakenMs: 1780000060000)]);
      await skipped([1]);
      open();

      await settle();

      // Once, for the skipped clip; no scan (that is To tag's).
      expect(h.bridge.count('videosByIds'), 1);
      expect(h.bridge.count('videosAddedAfter'), 0);
    },
  );

  test('a skipped clip whose video left the phone leaves the list', () async {
    h.bridge.put([fakeVideo(id: 1, dateTakenMs: 1780000060000)]);
    await skipped([1, 9]);
    open();

    await settle();

    expect(shownIds(), [1], reason: 'video 9 is not on the phone');
  });

  test('a clip waiting in To tag is not verified by Skipped', () async {
    await h.media.store([fakeVideo(id: 9, generation: 9)]);
    open();

    await settle();

    // Skipped has no clips: the verifier is asked about none. (Video 9 is
    // not on the phone, and it is still waiting.)
    expect((await h.media.toTag()).length, 1);
  });

  test(
    'a verify that throws is logged by type, the list still shows',
    () async {
      final records = captureLogs();
      h.bridge.put([fakeVideo(id: 1, dateTakenMs: 1780000060000)]);
      await skipped([1]);
      h.bridge.failNext('accessReport');
      open();

      await settle();

      expect(shownIds(), [1]);
      expect(
        logText(records),
        contains('The verify failed: PlatformException'),
      );
      expect(logText(records), isNot(contains('failed on purpose')));
    },
  );

  test(
    'restore moves the clips to To tag and returns what Undo needs',
    () async {
      final ids = await skipped([1, 2, 3]);
      open();
      await h.container.read(skippedControllerProvider.future);

      final record = await h.container
          .read(skippedControllerProvider.notifier)
          .restore({ids[0], ids[2]});

      expect(record.before.map((e) => e.clipId), [ids[0], ids[2]]);
      expect([for (final c in await h.media.toTag()) c.id], [ids[0], ids[2]]);
      expect([for (final c in await h.media.skipped()) c.id], [ids[1]]);
      await clips.undoAll([record]);
      expect([for (final c in await h.media.skipped()) c.id], ids);
    },
  );

  test('restore of a clip that is not skipped moves nothing', () async {
    final ids = await skipped([1]);
    open();
    await h.container.read(skippedControllerProvider.future);
    final controller = h.container.read(skippedControllerProvider.notifier);
    await controller.restore(ids);

    final again = await controller.restore(ids);

    expect(again.isEmpty, isTrue);
  });

  test('removeMissing takes a missing skipped clip out and returns what Undo '
      'needs; a clip that is not missing is left alone', () async {
    h.bridge.put([
      for (final id in [1, 2])
        fakeVideo(
          id: id,
          generation: id,
          dateTakenMs: 1780000000000 + id * 60000,
        ),
    ]);
    final ids = await skipped([1, 2]);
    open();
    // The opening verify finds both videos; then one is flagged missing.
    await settle();
    await flagInPlaceForTest(h, {ids[0]});
    final controller = h.container.read(skippedControllerProvider.notifier);

    final left = await controller.removeMissing(ids[1]);
    final record = await controller.removeMissing(ids[0]);

    expect(left.isEmpty, isTrue);
    expect([for (final c in await h.media.skipped()) c.id], [ids[1]]);
    await clips.undoAll([record]);
    expect([for (final c in await h.media.skipped()) c.id], ids);
  });

  test('retry reads the list and verifies again', () async {
    h.bridge.put([fakeVideo(id: 1, dateTakenMs: 1780000060000)]);
    await skipped([1]);
    open();
    await settle();
    final verifies = h.bridge.count('videosByIds');

    h.container.read(skippedControllerProvider.notifier).retry();
    await settle();

    expect(h.bridge.count('videosByIds'), verifies + 1);
    expect(shownIds(), [1]);
  });

  test('closing at once: the verify runs, or fails quietly by type', () async {
    final records = captureLogs();
    await skipped([1]);
    open().close();
    await h.container.pump();

    await settle();

    // An error that escaped the step would fail this test on its own (the
    // test zone reports it). Here: either the check ran, or its failure
    // (reading `ref` after the provider went) was logged as one line with
    // the error's type only (D-10).
    final failures = [
      for (final r in records)
        if (r.loggerName == 'skipped') r.message,
    ];
    final ran = records.any((r) => r.loggerName == 'verifier');
    expect(ran || failures.isNotEmpty, isTrue);
    for (final message in failures) {
      expect(message, matches(RegExp(r'^The verify failed: \w+$')));
    }
  });

  group('SkippedSelection', () {
    late List<int> ids;

    Future<void> openWith(int count) async {
      ids = await skipped([for (var i = 1; i <= count; i++) i]);
      h.container.listen(skippedControllerProvider, (_, _) {});
      h.container.listen(skippedSelectionProvider, (_, _) {});
      await h.container.read(skippedControllerProvider.future);
    }

    SkippedSelection notifier() =>
        h.container.read(skippedSelectionProvider.notifier);
    SkippedSelectionState state() => h.container.read(skippedSelectionProvider);

    test('starts with nothing chosen', () async {
      await openWith(3);

      expect(state(), const SkippedSelectionState());
    });

    test('begin chooses nothing and starts choosing', () async {
      await openWith(3);

      notifier().begin();

      expect(state().selecting, isTrue);
      expect(state().selected, isEmpty);
    });

    test('start, toggle and the last un-choose', () async {
      await openWith(3);

      notifier().start(ids[0]);
      notifier().toggle(ids[1]);
      expect(state().selected, {ids[0], ids[1]});
      notifier().toggle(ids[0]);
      notifier().toggle(ids[1]);

      expect(state(), const SkippedSelectionState());
    });

    test('a clip that is not in the list cannot be chosen', () async {
      await openWith(2);

      notifier().start(9999);
      notifier().begin();
      notifier().toggle(9999);

      expect(state().selected, isEmpty);
    });

    test('a chosen clip that leaves the list is dropped', () async {
      await openWith(3);
      notifier().start(ids[0]);
      notifier().toggle(ids[1]);

      await clips.restoreClips({ids[1]});
      await settle();

      expect(state().selected, {ids[0]});
      expect(state().selecting, isTrue);
    });

    test('choosing ends when every chosen clip has left', () async {
      await openWith(3);
      notifier().start(ids[0]);

      await clips.restoreClips({ids[0]});
      await settle();

      expect(state(), const SkippedSelectionState());
    });

    test(
      'choosing ends when the list empties, even with nothing chosen',
      () async {
        await openWith(2);
        notifier().begin();

        await clips.restoreClips(ids);
        await settle();

        expect(state(), const SkippedSelectionState());
      },
    );

    test('clear ends choosing', () async {
      await openWith(2);
      notifier().start(ids[0]);

      notifier().clear();

      expect(state(), const SkippedSelectionState());
    });
  });
}
