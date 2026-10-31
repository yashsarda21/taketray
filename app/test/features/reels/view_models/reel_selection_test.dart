import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/view_models/reel_selection.dart';

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

  /// A selection of reel [id], kept alive like the screen keeps it, once the
  /// reel's clips have been read.
  Future<ProviderContainer> open(int id) async {
    final container = ProviderContainer.test(overrides: h.overrides)
      ..listen(reelSelectionProvider(id), (_, _) {});
    await container.read(reelClipsProvider(id).future);
    return container;
  }

  ReelSelectionState stateOf(ProviderContainer c, int id) =>
      c.read(reelSelectionProvider(id));

  ReelSelection notifierOf(ProviderContainer c, int id) =>
      c.read(reelSelectionProvider(id).notifier);

  group('starting and toggling', () {
    test('long press starts selection', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = await open(goa.id);
      expect(stateOf(c, goa.id).selecting, isFalse);
      expect(stateOf(c, goa.id).selected, isEmpty);

      notifierOf(c, goa.id).start(ids.first);

      expect(stateOf(c, goa.id).selecting, isTrue);
      expect(stateOf(c, goa.id).selected, {ids.first});
    });

    test('toggle adds and removes a clip', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = await open(goa.id);
      final selection = notifierOf(c, goa.id)
        ..start(ids.first)
        ..toggle(ids.last);
      expect(stateOf(c, goa.id).selected, {ids.first, ids.last});

      selection.toggle(ids.first);
      expect(stateOf(c, goa.id).selected, {ids.last});
      expect(stateOf(c, goa.id).selecting, isTrue);
    });

    test('toggle to empty ends selection', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = await open(goa.id);
      notifierOf(c, goa.id)
        ..start(ids.first)
        ..toggle(ids.first);

      expect(stateOf(c, goa.id).selecting, isFalse);
      expect(stateOf(c, goa.id).selected, isEmpty);
    });

    test('toggle on a clip starts selecting too', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final c = await open(goa.id);

      notifierOf(c, goa.id).toggle(ids.single);

      expect(stateOf(c, goa.id).selecting, isTrue);
      expect(stateOf(c, goa.id).selected, {ids.single});
    });

    test('begin selects nothing yet but selection is on, and toggling the '
        'only clip on and off ends it', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final c = await open(goa.id);
      final selection = notifierOf(c, goa.id)..begin();

      expect(stateOf(c, goa.id).selecting, isTrue);
      expect(stateOf(c, goa.id).selected, isEmpty);

      selection
        ..toggle(ids.single)
        ..toggle(ids.single);
      expect(stateOf(c, goa.id).selecting, isFalse);
    });

    test('clear ends selection', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = await open(goa.id);
      notifierOf(c, goa.id)
        ..start(ids.first)
        ..toggle(ids.last)
        ..clear();

      expect(stateOf(c, goa.id).selecting, isFalse);
      expect(stateOf(c, goa.id).selected, isEmpty);
    });

    test('clear with nothing selected changes nothing', () async {
      final goa = await reels.create('Goa');
      final c = await open(goa.id);

      notifierOf(c, goa.id).clear();

      expect(stateOf(c, goa.id).selecting, isFalse);
    });

    test('each reel has its own selection', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      final goaIds = await putInReel(h, goa.id, [reelVideo(1)]);
      await putInReel(h, london.id, [reelVideo(2)]);
      final c = await open(goa.id);
      c.listen(reelSelectionProvider(london.id), (_, _) {});

      notifierOf(c, goa.id).start(goaIds.single);

      expect(stateOf(c, london.id).selecting, isFalse);
    });
  });

  group('select all', () {
    test('select all skips missing', () async {
      final goa = await reels.create('Goa');
      final live = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final gone = await putInReel(h, goa.id, [reelVideo(3)], onPhone: false);
      await flagForTest(h, gone.toSet(), missing: true);
      final c = await open(goa.id);

      notifierOf(c, goa.id).selectAll();

      expect(stateOf(c, goa.id).selecting, isTrue);
      expect(stateOf(c, goa.id).selected, live.toSet());
      expect(stateOf(c, goa.id).selected, isNot(contains(gone.single)));
    });

    test('select all adds to what is chosen already', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [
        reelVideo(1),
        reelVideo(2),
        reelVideo(3),
      ]);
      final c = await open(goa.id);
      notifierOf(c, goa.id)
        ..start(ids.first)
        ..selectAll();

      expect(stateOf(c, goa.id).selected, ids.toSet());
    });

    test('select all in a reel with only missing clips selects nothing but '
        'stays in selection', () async {
      final goa = await reels.create('Goa');
      final gone = await putInReel(h, goa.id, [reelVideo(1)], onPhone: false);
      await flagForTest(h, gone.toSet(), missing: true);
      final c = await open(goa.id);

      notifierOf(c, goa.id).selectAll();

      expect(stateOf(c, goa.id).selected, isEmpty);
      expect(stateOf(c, goa.id).selecting, isTrue);
    });
  });

  group('missing and foreign clips cannot be selected', () {
    test('missing tile cannot be selected', () async {
      final goa = await reels.create('Goa');
      final live = await putInReel(h, goa.id, [reelVideo(1)]);
      final gone = await putInReel(h, goa.id, [reelVideo(2)], onPhone: false);
      await flagForTest(h, gone.toSet(), missing: true);
      final c = await open(goa.id);
      final selection = notifierOf(c, goa.id)..start(gone.single);
      expect(stateOf(c, goa.id).selecting, isFalse);

      selection
        ..start(live.single)
        ..toggle(gone.single);
      expect(stateOf(c, goa.id).selected, {live.single});
    });

    test('a clip of another reel cannot be selected', () async {
      final goa = await reels.create('Goa');
      final london = await reels.create('London');
      await putInReel(h, goa.id, [reelVideo(1)]);
      final elsewhere = await putInReel(h, london.id, [reelVideo(2)]);
      final c = await open(goa.id);

      notifierOf(c, goa.id).start(elsewhere.single);

      expect(stateOf(c, goa.id).selecting, isFalse);
    });

    test('before the clips are read nothing can be selected', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1)]);
      final c = ProviderContainer.test(overrides: h.overrides)
        ..listen(reelSelectionProvider(goa.id), (_, _) {});

      c.read(reelSelectionProvider(goa.id).notifier)
        ..start(ids.single)
        ..selectAll();

      expect(c.read(reelSelectionProvider(goa.id)).selected, isEmpty);
    });
  });

  group('the clips change while choosing', () {
    test('a chosen clip that goes missing leaves the selection', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = await open(goa.id);
      notifierOf(c, goa.id)
        ..start(ids.first)
        ..toggle(ids.last);

      await flagForTest(h, {ids.last}, missing: true);
      await settle();

      expect(stateOf(c, goa.id).selected, {ids.first});
      expect(stateOf(c, goa.id).selecting, isTrue);
    });

    test('when the last chosen clip goes, selection ends', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = await open(goa.id);
      notifierOf(c, goa.id).start(ids.first);

      await flagForTest(h, {ids.first}, missing: true);
      await settle();

      expect(stateOf(c, goa.id).selecting, isFalse);
      expect(stateOf(c, goa.id).selected, isEmpty);
    });

    test('a chosen clip removed from the reel elsewhere leaves it', () async {
      final goa = await reels.create('Goa');
      final ids = await putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]);
      final c = await open(goa.id);
      notifierOf(c, goa.id)
        ..start(ids.first)
        ..toggle(ids.last);

      await clips.removeClipsFromReel(goa.id, [ids.first]);
      await settle();

      expect(stateOf(c, goa.id).selected, {ids.last});
    });

    test('an empty selection (begin) is kept when the list changes', () async {
      final goa = await reels.create('Goa');
      await putInReel(h, goa.id, [reelVideo(1)]);
      final c = await open(goa.id);
      notifierOf(c, goa.id).begin();

      await putInReel(h, goa.id, [reelVideo(2)]);
      await settle();

      expect(stateOf(c, goa.id).selecting, isTrue);
    });
  });
}
