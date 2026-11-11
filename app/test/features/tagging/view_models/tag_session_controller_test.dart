import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/reels/view_models/clip_player.dart';
import 'package:taketray/features/tagging/view_models/last_tags.dart';
import 'package:taketray/features/tagging/view_models/tag_player_muted.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';

import '../../../support/fake_hold.dart';
import '../../../support/reel_videos.dart';
import '../../../support/vm_harness.dart';

/// The real repository, with each `addClipsToReels` call recorded, and a
/// gate a test can close (the write waits) or a failure it can plant.
class SpyClips extends ClipsRepository {
  SpyClips(VmHarness h) : super(h.media.db, h.media.clock);

  final List<(List<int>, List<int>)> addCalls = [];
  Completer<void>? gate;
  Exception? failNext;

  /// When set, the next look at a clip's reels fails (after an Undo has
  /// been written, it is only for the counts).
  bool failReelIds = false;

  /// When set, the next watch of To tag fails at once (the session cannot
  /// load).
  bool failWatch = false;

  @override
  Stream<Set<int>> watchReelIdsOf(int clipId) {
    if (failReelIds) {
      failReelIds = false;
      return Stream.error(const FileSystemException('disk'));
    }
    return super.watchReelIdsOf(clipId);
  }

  @override
  Stream<List<Clip>> watchInbox(InboxState state) {
    if (failWatch && state == InboxState.pending) {
      failWatch = false;
      return Stream.error(const FileSystemException('disk'));
    }
    return super.watchInbox(state);
  }

  @override
  Future<List<AddUndo>> addClipsToReels(
    Set<int> reelIds,
    Iterable<int> clipIds,
  ) async {
    addCalls.add((reelIds.toList(), clipIds.toList()));
    final wait = gate;
    if (wait != null) await wait.future;
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return await super.addClipsToReels(reelIds, clipIds);
  }
}

/// The real reels repository, with a gate a test can close: `create` waits
/// for it before it writes.
class SpyReels extends ReelsRepository {
  SpyReels(VmHarness h) : super(h.media.db, h.media.clock);

  Completer<void>? gate;

  /// Runs when the controller reads the reels' names, which it does at the
  /// start of every tag: the moment a test deletes a clip "mid-write".
  Future<void> Function()? onNames;

  @override
  Stream<List<Reel>> watchAll() async* {
    await onNames?.call();
    yield* super.watchAll();
  }

  @override
  Future<Reel> create(String name, {String? description}) async {
    final wait = gate;
    if (wait != null) await wait.future;
    return await super.create(name, description: description);
  }
}

void main() {
  late VmHarness h;
  late FakeHolds holds;
  late SpyClips spy;
  late ProviderContainer c;
  late SpyReels reels;

  setUp(() {
    h = reelHarness();
    holds = FakeHolds();
    spy = SpyClips(h);
    reels = SpyReels(h);
    c = ProviderContainer.test(
      overrides: [
        ...h.overrides,
        holdTimerProvider.overrideWithValue(holds.call),
        clipsRepositoryProvider.overrideWithValue(spy),
        reelsRepositoryProvider.overrideWithValue(reels),
      ],
    );
  });

  /// Puts [count] clips in To tag, shot a minute apart, oldest first.
  Future<List<int>> waiting(int count) =>
      h.media.store([for (var i = 1; i <= count; i++) reelVideo(i)]);

  /// The session as the player opens it on [at], kept open like the screen.
  late ProviderSubscription<AsyncValue<TagSessionState>> sub;
  Future<TagSessionController> start({int? at}) async {
    sub = c.listen(tagSessionControllerProvider(at), (_, _) {});
    await c.read(tagSessionControllerProvider(at).future);
    final controller = c.read(tagSessionControllerProvider(at).notifier);
    return controller;
  }

  TagSessionState stateOf({int? at}) =>
      c.read(tagSessionControllerProvider(at)).requireValue;

  Future<Set<int>> reelsOf(int clipId) => spy.watchReelIdsOf(clipId).first;

  Future<Set<int>> pendingIds() async => {
    for (final clip in await h.media.toTag()) clip.id,
  };

  Future<Reel> reel(String name) => reels.create(name);

  group('start', () {
    test('starts at the tapped clip', () async {
      final ids = await waiting(3);
      await start(at: ids[1]);

      final s = stateOf(at: ids[1]);
      expect(s.session, ids);
      expect(s.index, 1);
      expect(s.done, isFalse);
      expect(s.pending, ids.toSet());
      expect(s.clips[s.session[s.index]]!.id, ids[1]);
    });

    test('a start clip that is not waiting starts at the first', () async {
      final ids = await waiting(2);
      await start(at: 999);

      expect(stateOf(at: 999).index, 0);
      expect(stateOf(at: 999).session, ids);
    });

    test('empty session is done', () async {
      await start();

      final s = stateOf();
      expect(s.session, isEmpty);
      expect(s.done, isTrue);
    });

    test('the scene of the clip showing', () async {
      final ids = await h.media.store([
        reelVideo(1, shot: DateTime.utc(2026, 10, 28, 9)),
        reelVideo(2, shot: DateTime.utc(2026, 10, 28, 9, 1)),
        reelVideo(3, shot: DateTime.utc(2026, 10, 28, 11)),
      ]);
      await start();
      final s = stateOf();

      final (first, total, scene) = s.sceneOf(1)!;
      expect((first, total), (1, 2));
      expect(scene.clips.map((clip) => clip.id), [ids[0], ids[1]]);
      final (second, _, last) = s.sceneOf(2)!;
      expect(second, 2);
      expect(last.clips.single.id, ids[2]);
      expect(s.sceneOf(3), isNull);
      expect(s.sceneOf(-1), isNull);
    });
  });

  group('the hold', () {
    test('tap tags after the hold and advances', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final session = await start();

      final tagged = session.tapReel(goa.id);
      await settle();
      expect(stateOf().confirmingReelId, goa.id);
      expect(holds.made.single.duration, const Duration(milliseconds: 400));
      // Nothing is written during the hold.
      expect(await reelsOf(ids[0]), isEmpty);
      expect(stateOf().index, 0);

      holds.fireAll();
      final outcome = (await tagged)!;

      expect(outcome.clipId, ids[0]);
      expect(outcome.reelNames, ['Goa']);
      expect(outcome.skipped, isFalse);
      expect(outcome.records.single, isA<AddUndo>());
      expect(await reelsOf(ids[0]), {goa.id});
      final s = stateOf();
      expect(s.index, 1);
      expect(s.confirmingReelId, isNull);
      expect(s.busy, isFalse);
      expect(s.taggedPerReel, {goa.id: 1});
      expect(s.lastActedClipId, ids[0]);
      expect(s.pending, {ids[1], ids[2]});
      expect(c.read(lastTagsProvider), [goa.id]);
    });

    test('double tap on a chip tags once', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start();

      final first = session.tapReel(goa.id);
      final second = session.tapReel(goa.id);
      final other = session.tapReel(london.id);

      // One hold: the other taps were ignored at once.
      expect(holds.made, hasLength(1));
      expect(stateOf().confirmingReelId, goa.id);
      holds.fireAll();
      expect(await first, isNotNull);
      expect(await second, isNull);
      expect(await other, isNull);
      await settle();

      expect(spy.addCalls, hasLength(1));
      expect(await reelsOf(ids[0]), {goa.id});
      expect(await reelsOf(ids[1]), isEmpty);
      expect(await pendingIds(), {ids[1], ids[2]});
      expect(stateOf().index, 1);
    });

    test('skip during the hold is ignored', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start();

      final tagged = session.tapReel(goa.id);
      expect(await session.skip(), isNull);
      expect(await session.sameAsPrevious(), isNull);
      session
        ..next()
        ..longPressReel(goa.id);
      expect(stateOf().index, 0);
      expect(stateOf().multi, isFalse);
      holds.fireAll();
      await tagged;

      expect(await h.media.skipped(), isEmpty);
      expect(await reelsOf(ids[0]), {goa.id});
      expect(stateOf().skipped, 0);
      expect(stateOf().index, 1);
    });

    test('tag goes to the clip shown when tapped', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start();

      final tagged = session.tapReel(goa.id);
      // During the hold another clip of the session (the next one) leaves To
      // tag: the hold goes on, and the tap still means the clip showing.
      await h.media.clips.addClipsToReel(london.id, [ids[1]]);
      await settle();
      expect(stateOf().index, 0);
      expect(holds.made.single.cancelled, isFalse);
      holds.fireAll();
      final outcome = (await tagged)!;

      expect(outcome.clipId, ids[0]);
      expect(await reelsOf(ids[0]), {goa.id});
      expect(await reelsOf(ids[1]), {london.id});
      expect(await pendingIds(), {ids[2]});
      expect(stateOf().index, 2);
    });

    test('a clip leaving during the hold cancels the tap', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start();

      final tagged = session.tapReel(goa.id);
      // During the hold the clip showing is tagged elsewhere: the tap is
      // dropped as if it never happened, and the player moves on.
      await h.media.clips.addClipsToReel(london.id, [ids[0]]);
      await settle();

      expect(holds.made.single.cancelled, isTrue);
      expect(await tagged, isNull);
      final s = stateOf();
      expect(s.index, 1);
      expect(s.confirmingReelId, isNull);
      expect(s.busy, isFalse);
      expect(s.taggedPerReel, isEmpty);
      holds.fireAll();
      await settle();
      expect(spy.addCalls, isEmpty);
      expect(await reelsOf(ids[0]), {london.id});
      expect(await reelsOf(ids[1]), isEmpty);
      expect(await pendingIds(), {ids[1], ids[2]});

      // The next tap is taken, on the new clip.
      final again = session.tapReel(goa.id);
      expect(holds.made, hasLength(2));
      holds.made.last.fire();
      expect((await again)!.clipId, ids[1]);
    });

    test('same as previous while a tag writes is ignored', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start();
      final first = session.tapReel(goa.id);
      holds.fireAll();
      await first;

      final gate = spy.gate = Completer<void>();
      final second = session.tapReel(london.id);
      holds.fireAll();
      await settle();
      expect(await session.sameAsPrevious(), isNull);
      expect(await session.skip(), isNull);
      expect(await session.confirmPicks(), isNull);
      gate.complete();
      await second;

      expect(spy.addCalls, hasLength(2));
      expect(await reelsOf(ids[1]), {london.id});
      expect(await reelsOf(ids[2]), isEmpty);
      expect(await pendingIds(), {ids[2]});
      expect(stateOf().index, 2);
    });

    test('the clip leaving while its tag writes moves on once', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start();

      final gate = spy.gate = Completer<void>();
      final tagged = session.tapReel(goa.id);
      holds.fireAll();
      await settle();
      // The next clip leaves To tag while the write waits.
      await h.media.clips.addClipsToReel(london.id, [ids[1]]);
      await settle();
      expect(stateOf().index, 0);
      gate.complete();
      await tagged;
      await settle();

      expect(stateOf().index, 2);
      expect(await reelsOf(ids[0]), {goa.id});
    });

    test('closing during the hold tags nothing', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start();

      final tagged = session.tapReel(goa.id);
      sub.close();
      await settle();

      expect(holds.made.single.cancelled, isTrue);
      expect(await tagged, isNull);
      expect(await reelsOf(ids[0]), isEmpty);
      expect(await pendingIds(), ids.toSet());
      expect(spy.addCalls, isEmpty);
    });

    test('leave in the hold tags nothing, at once', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start();

      final tagged = session.tapReel(goa.id);
      await settle();
      expect(stateOf().confirmingReelId, goa.id);
      // The player starts to close; the session is still alive (the route's
      // exit transition is running).
      session.leave();

      expect(holds.made.single.cancelled, isTrue);
      expect(await tagged, isNull);
      expect(stateOf().confirmingReelId, isNull);
      // The hold's timer firing late does nothing either.
      holds.fireAll();
      await settle();
      expect(spy.addCalls, isEmpty);
      expect(await reelsOf(ids[0]), isEmpty);
      expect(await pendingIds(), ids.toSet());
      expect(c.exists(tagSessionControllerProvider(null)), isTrue);
    });

    test('after leave every action is ignored, and Undo still works', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final session = await start();
      final skipped = (await session.skip())!;
      expect(stateOf().index, 1);

      session
        ..leave()
        ..leave();

      expect(await session.tapReel(goa.id), isNull);
      expect(await session.skip(), isNull);
      expect(await session.sameAsPrevious(), isNull);
      session
        ..setMulti(true)
        ..longPressReel(goa.id)
        ..next()
        ..previous();
      expect(await session.confirmPicks(), isNull);
      expect(holds.made, isEmpty);
      expect(spy.addCalls, isEmpty);
      expect(stateOf().multi, isFalse);
      expect(stateOf().index, 1);
      expect(await pendingIds(), {ids[1], ids[2]});

      // The snack outlives the player: its Undo still puts the clip back.
      await session.undo(skipped.records, skipped.clipId);
      expect(await pendingIds(), ids.toSet());
      expect(stateOf().index, 0);
      expect(stateOf().skipped, 0);
    });

    test('enter after leave takes actions again', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start()
        ..leave();
      expect(await session.skip(), isNull);

      // The player opened again while the old one slides away: same session.
      session.enter();
      final tagged = session.tapReel(goa.id);
      holds.fireAll();

      expect((await tagged)!.clipId, ids[0]);
      expect(await reelsOf(ids[0]), {goa.id});
    });

    test('reduced motion holds 120 ms', () async {
      await waiting(1);
      final goa = await reel('Goa');
      final session = await start();

      unawaited(session.tapReel(goa.id, reducedMotion: true));

      expect(holds.made.single.duration, const Duration(milliseconds: 120));
    });
  });

  group('pick several', () {
    test('pick several stays on after advance and clears picks', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start()
        ..setMulti(true)
        ..togglePick(goa.id)
        ..togglePick(london.id);
      expect(stateOf().picked, [goa.id, london.id]);

      await session.confirmPicks();

      final s = stateOf();
      expect(s.index, 1);
      expect(s.multi, isTrue);
      expect(s.picked, isEmpty);
      expect(await reelsOf(ids[0]), {goa.id, london.id});
      // A tap on a chip picks, it does not tag.
      expect(await session.tapReel(goa.id), isNull);
      expect(holds.made, isEmpty);
    });

    test('long press starts pick several with that reel', () async {
      final ids = await waiting(2);
      await reel('Goa');
      final london = await reel('London');
      final session = await start();

      session.longPressReel(london.id);

      expect(stateOf().multi, isTrue);
      expect(stateOf().picked, [london.id]);
      expect(await reelsOf(ids[0]), isEmpty);
      expect(holds.made, isEmpty);
      // Cancel turns it off and drops the picks.
      session.setMulti(false);
      expect(stateOf().multi, isFalse);
      expect(stateOf().picked, isEmpty);
    });

    test('confirm picks tags into all in one transaction', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final london = await reel('London');
      final paris = await reel('Paris');
      final session = await start()
        ..setMulti(true)
        ..togglePick(london.id)
        ..togglePick(goa.id)
        ..togglePick(paris.id)
        ..togglePick(paris.id);

      final outcome = (await session.confirmPicks())!;

      final (reelIds, clipIds) = spy.addCalls.single;
      expect(reelIds, [london.id, goa.id]);
      expect(clipIds, [ids[0]]);
      expect(outcome.reelNames, ['London', 'Goa']);
      expect(outcome.records.map((r) => (r as AddUndo).reelId), [
        london.id,
        goa.id,
      ]);
      expect(await reelsOf(ids[0]), {goa.id, london.id});
      expect(c.read(lastTagsProvider), [london.id, goa.id]);
      expect(stateOf().taggedPerReel, {london.id: 1, goa.id: 1});
    });

    test(
      'a picked reel deleted elsewhere is dropped from the confirm',
      () async {
        final ids = await waiting(2);
        final goa = await reel('Goa');
        final london = await reel('London');
        final session = await start()
          ..setMulti(true)
          ..togglePick(goa.id)
          ..togglePick(london.id);
        await reels.delete(london.id);

        final outcome = (await session.confirmPicks())!;

        expect(outcome.reelIds, [goa.id]);
        expect(spy.addCalls.single.$1, [goa.id]);
        expect(await reelsOf(ids[0]), {goa.id});
        expect(stateOf().index, 1);
        expect(stateOf().taggedPerReel, {goa.id: 1});
      },
    );

    test('every picked reel deleted elsewhere: confirm does nothing', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start()
        ..setMulti(true)
        ..togglePick(goa.id);
      await reels.delete(goa.id);

      expect(await session.confirmPicks(), isNull);

      final s = stateOf();
      expect(s.index, 0);
      expect(s.busy, isFalse);
      // The pick of the reel that is gone goes too: the footer is disabled.
      expect(s.picked, isEmpty);
      expect(s.multi, isTrue);
      expect(spy.addCalls, isEmpty);
      expect(await pendingIds(), ids.toSet());
      // And the next confirm still works once a reel is picked.
      final paris = await reel('Paris');
      session.togglePick(paris.id);
      expect(await session.confirmPicks(), isNotNull);
    });

    test('confirm with nothing picked does nothing', () async {
      await waiting(1);
      final session = await start()
        ..setMulti(true);

      expect(await session.confirmPicks(), isNull);
      expect(spy.addCalls, isEmpty);
    });
  });

  group('same as previous', () {
    test('same as previous uses the last tags that still exist', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start()
        ..setMulti(true)
        ..togglePick(london.id)
        ..togglePick(goa.id);
      await session.confirmPicks();
      await reels.delete(london.id);

      final outcome = (await session.sameAsPrevious())!;

      expect(outcome.clipId, ids[1]);
      expect(outcome.reelNames, ['Goa']);
      final (reelIds, clipIds) = spy.addCalls.last;
      expect(reelIds, [goa.id]);
      expect(clipIds, [ids[1]]);
      expect(await reelsOf(ids[1]), {goa.id});
      expect(stateOf().index, 2);
    });

    test('same as previous does nothing with none', () async {
      final ids = await waiting(2);
      final session = await start();

      expect(await session.sameAsPrevious(), isNull);
      // A last tag whose reels are all gone is none too.
      c.read(lastTagsProvider.notifier).set([999]);
      expect(await session.sameAsPrevious(), isNull);

      expect(spy.addCalls, isEmpty);
      expect(stateOf().index, 0);
      expect(stateOf().busy, isFalse);
      expect(await pendingIds(), ids.toSet());
    });
  });

  group('skip and moving', () {
    test('skip advances and counts', () async {
      final ids = await waiting(2);
      final session = await start();

      final outcome = (await session.skip())!;

      expect(outcome.skipped, isTrue);
      expect(outcome.clipId, ids[0]);
      expect(outcome.reelNames, isEmpty);
      expect(outcome.records.single, isA<InboxUndo>());
      expect((await h.media.skipped()).map((clip) => clip.id), [ids[0]]);
      final s = stateOf();
      expect(s.index, 1);
      expect(s.skipped, 1);
      expect(s.lastActedClipId, ids[0]);
      expect(c.read(lastTagsProvider), isEmpty);
    });

    test('last clip goes to done', () async {
      await waiting(1);
      final goa = await reel('Goa');
      final session = await start();

      final tagged = session.tapReel(goa.id);
      holds.fireAll();

      expect(await tagged, isNotNull);
      expect(stateOf().done, isTrue);
      expect(stateOf().sortedCount, 1);
    });

    test('wraps to an earlier pending clip', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final session = await start(at: ids[1]);

      final tagged = session.tapReel(goa.id);
      holds.fireAll();
      await tagged;
      expect(stateOf(at: ids[1]).index, 2);
      await session.skip();

      expect(stateOf(at: ids[1]).index, 0);
      expect(stateOf(at: ids[1]).done, isFalse);
    });

    test(
      'previous and next move without tagging and keep pick several',
      () async {
        final ids = await waiting(3);
        final goa = await reel('Goa');
        final session = await start()
          ..longPressReel(goa.id);
        expect(stateOf().hasPrevious, isFalse);
        expect(stateOf().hasNext, isTrue);

        session.next();
        expect(stateOf().index, 1);
        expect(stateOf().multi, isTrue);
        expect(stateOf().picked, isEmpty);
        session
          ..next()
          ..next();
        expect(stateOf().index, 2);
        expect(stateOf().hasNext, isFalse);
        session.previous();
        expect(stateOf().index, 1);
        expect(await pendingIds(), ids.toSet());
        expect(spy.addCalls, isEmpty);
      },
    );
  });

  group('undo', () {
    test('undo goes back to the clip', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final session = await start();
      final tagged = session.tapReel(goa.id);
      holds.fireAll();
      final outcome = (await tagged)!;
      expect(stateOf().index, 1);

      await session.undo(outcome.records, outcome.clipId);

      final s = stateOf();
      expect(s.index, 0);
      expect(s.busy, isFalse);
      expect(s.taggedPerReel, isEmpty);
      expect(s.pending, ids.toSet());
      expect(await reelsOf(ids[0]), isEmpty);
      expect(await pendingIds(), ids.toSet());
      // "Same as previous" offers what it offered before the tag.
      expect(c.read(lastTagsProvider), isEmpty);

      // A second Undo of the same records changes nothing.
      await session.undo(outcome.records, outcome.clipId);
      expect(stateOf().taggedPerReel, isEmpty);
      expect(stateOf().index, 0);
      expect(await pendingIds(), ids.toSet());
    });

    test('undo while the next tag writes restores the right clip', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start();
      final first = session.tapReel(goa.id);
      holds.fireAll();
      final outcome = (await first)!;

      final gate = spy.gate = Completer<void>();
      final second = session.tapReel(london.id);
      holds.fireAll();
      await settle();
      expect(stateOf().busy, isTrue);
      final undone = session.undo(outcome.records, outcome.clipId);
      await settle();
      // Undo waits for the write that is running.
      expect(await reelsOf(ids[0]), {goa.id});

      gate.complete();
      expect((await second)!.clipId, ids[1]);
      await undone;

      expect(await reelsOf(ids[0]), isEmpty);
      expect(await reelsOf(ids[1]), {london.id});
      expect(await pendingIds(), {ids[0], ids[2]});
      final s = stateOf();
      expect(s.index, 0);
      expect(s.busy, isFalse);
      expect(s.taggedPerReel, {london.id: 1});
    });

    test(
      'undo during a chip hold waits, the held tag lands, then goes back',
      () async {
        final ids = await waiting(3);
        final goa = await reel('Goa');
        final london = await reel('London');
        final session = await start();
        final first = session.tapReel(goa.id);
        holds.fireAll();
        final outcome = (await first)!;

        final second = session.tapReel(london.id);
        await settle();
        expect(stateOf().confirmingReelId, london.id);
        var undoneYet = false;
        final undone = session
            .undo(outcome.records, outcome.clipId)
            .then((_) => undoneYet = true);
        await settle();
        // Undo waits for the hold: nothing is undone yet.
        expect(undoneYet, isFalse);
        expect(await reelsOf(ids[0]), {goa.id});

        holds.made.last.fire();
        expect((await second)!.clipId, ids[1]);
        await undone;

        expect(await reelsOf(ids[0]), isEmpty);
        expect(await reelsOf(ids[1]), {london.id});
        final s = stateOf();
        expect(s.index, 0);
        expect(s.taggedPerReel, {london.id: 1});
        expect(s.busy, isFalse);
      },
    );

    test('closing during a hold lets a queued undo run', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start();
      final first = session.tapReel(goa.id);
      holds.fireAll();
      final outcome = (await first)!;

      final second = session.tapReel(london.id);
      final undone = session.undo(outcome.records, outcome.clipId);
      await settle();
      sub.close();
      await settle();

      expect(await second, isNull);
      await undone.timeout(const Duration(seconds: 5));
      expect(await reelsOf(ids[0]), isEmpty);
      expect(await reelsOf(ids[1]), isEmpty);
      expect(await pendingIds(), ids.toSet());
    });

    test('undo counts back only a skip it really undid', () async {
      final ids = await waiting(2);
      final london = await reel('London');
      final session = await start();
      final outcome = (await session.skip())!;
      expect(stateOf().skipped, 1);
      // Elsewhere: restored from Skipped, then tagged.
      await spy.restoreClips([ids[0]]);
      await spy.addClipsToReel(london.id, [ids[0]]);
      await settle();

      await session.undo(outcome.records, outcome.clipId);

      // The Undo found nothing to put back: the count stays.
      expect(await reelsOf(ids[0]), {london.id});
      expect(stateOf().skipped, 1);
      expect(stateOf().index, 1);
    });

    test('undo counts back only the reels the clip has left', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start()
        ..setMulti(true)
        ..togglePick(goa.id)
        ..togglePick(london.id);
      final outcome = (await session.confirmPicks())!;
      expect(stateOf().taggedPerReel, {goa.id: 1, london.id: 1});
      // Elsewhere: taken out of Goa. London is now its only place, and Undo
      // never takes a clip's last place (D-84), so the Undo changes nothing.
      await spy.removeClipsFromReel(goa.id, [ids[0]]);
      await settle();

      await session.undo(outcome.records, outcome.clipId);

      // Still in London, so London keeps its +1; Goa's is no longer true.
      expect(await reelsOf(ids[0]), {london.id});
      expect(stateOf().taggedPerReel, {london.id: 1});
      expect(stateOf().index, 1);
    });

    test('undo after the player closed restores the clip', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start();
      final tagged = session.tapReel(goa.id);
      holds.fireAll();
      final outcome = (await tagged)!;
      expect(c.read(lastTagsProvider), [goa.id]);

      // The player closes; the snack, on the root messenger, stays.
      sub.close();
      await settle();
      expect(c.exists(tagSessionControllerProvider(null)), isFalse);

      await session.undo(outcome.records, outcome.clipId);

      expect(await pendingIds(), ids.toSet());
      expect(await reelsOf(ids[0]), isEmpty);
      expect(c.read(lastTagsProvider), isEmpty);
    });

    test('an action after close does nothing and does not throw', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start();
      sub.close();
      await settle();

      expect(await session.tapReel(goa.id), isNull);
      expect(await session.skip(), isNull);
      expect(await session.confirmPicks(), isNull);
      expect(await session.sameAsPrevious(), isNull);
      expect(await session.createReelAndTag('Paris', clipId: ids[0]), isNull);
      session
        ..longPressReel(goa.id)
        ..setMulti(true)
        ..togglePick(goa.id)
        ..next()
        ..previous();

      expect(holds.made, isEmpty);
      expect(spy.addCalls, isEmpty);
      expect(await pendingIds(), ids.toSet());
      expect(await reels.watchAll().first, hasLength(1));
    });

    test('undo after done reopens the session', () async {
      final ids = await waiting(1);
      final session = await start();
      final outcome = (await session.skip())!;
      expect(stateOf().done, isTrue);

      await session.undo(outcome.records, outcome.clipId);

      expect(stateOf().done, isFalse);
      expect(stateOf().index, 0);
      expect(stateOf().skipped, 0);
      expect(await pendingIds(), {ids[0]});
    });

    test('a failure after the undo was written is not a failed undo', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final session = await start();
      final tagged = session.tapReel(goa.id);
      holds.fireAll();
      final outcome = (await tagged)!;
      // The reels of the clip are read after the undo, for the counts only.
      spy.failReelIds = true;

      await session.undo(outcome.records, outcome.clipId);

      // Done, and said so: the snack does not say "Couldn't undo".
      expect(await reelsOf(ids[0]), isEmpty);
      expect(await pendingIds(), ids.toSet());
      final s = stateOf();
      expect(s.index, 0);
      expect(s.busy, isFalse);
      // Nothing is stuck: the next tap works.
      final again = session.tapReel(goa.id);
      holds.fireAll();
      expect((await again)!.clipId, ids[0]);
    });

    test('undo works when the session could not load', () async {
      final ids = await waiting(2);
      // Skipped before the player opened (its snack is still up).
      final record = await spy.skipClips([ids[0]]);
      spy.failWatch = true;
      sub = c.listen(tagSessionControllerProvider(null), (_, _) {});
      await settle();
      expect(c.read(tagSessionControllerProvider(null)).hasError, isTrue);
      final session = c.read(tagSessionControllerProvider(null).notifier);

      await session.undo([record], ids[0]);

      expect(await pendingIds(), ids.toSet());
    });
  });

  group('the list changing', () {
    test('current clip leaving To tag moves on', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      await start();

      await h.media.clips.addClipsToReel(goa.id, [ids[0]]);
      await settle();
      expect(stateOf().index, 1);
      expect(stateOf().pending, {ids[1], ids[2]});

      await h.media.clips.skipClips([ids[1], ids[2]]);
      await settle();
      expect(stateOf().done, isTrue);
    });

    test('new clips are not added to the session', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start();

      final late = await h.media.store([reelVideo(9)]);
      await settle();
      expect(stateOf().session, ids);
      expect(stateOf().pending, ids.toSet());

      for (var i = 0; i < 2; i++) {
        final tagged = session.tapReel(goa.id);
        holds.fireAll();
        await tagged;
      }
      expect(stateOf().done, isTrue);
      expect(await pendingIds(), {late.single});
    });
  });

  group('new reel', () {
    test('create reel and tag', () async {
      final ids = await waiting(2);
      final session = await start();

      final made = (await session.createReelAndTag('Goa', clipId: ids[0]))!;

      final goa = (await reels.watchAll().first).single;
      expect(goa.name, 'Goa');
      expect(made.reel.id, goa.id);
      final outcome = made.outcome!;
      expect(outcome.reelNames, ['Goa']);
      expect(outcome.clipId, ids[0]);
      expect(await reelsOf(ids[0]), {goa.id});
      expect(stateOf().index, 1);
      expect(stateOf().taggedPerReel, {goa.id: 1});

      // A name that is taken is thrown to the form, and nothing moves.
      await expectLater(
        session.createReelAndTag('goa', clipId: ids[1]),
        throwsA(isA<InvalidInputException>()),
      );
      expect(stateOf().index, 1);
      expect(stateOf().busy, isFalse);
    });

    test('create reel in pick several picks it', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start()
        ..setMulti(true)
        ..togglePick(goa.id);

      final made = (await session.createReelAndTag('Paris', clipId: ids[0]))!;

      expect(made.outcome, isNull);
      expect(made.reel.name, 'Paris');
      expect(stateOf().picked, [goa.id, made.reel.id]);
      expect(stateOf().index, 0);
      expect(stateOf().busy, isFalse);
      expect(await reelsOf(ids[0]), isEmpty);
    });

    test('the clip leaving while a reel is made to pick moves on', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start()
        ..setMulti(true)
        ..togglePick(goa.id);

      final gate = reels.gate = Completer<void>();
      final made = session.createReelAndTag('Paris', clipId: ids[0]);
      await settle();
      // The clip showing is tagged elsewhere while the reel is made.
      await spy.addClipsToReel(london.id, [ids[0]]);
      await settle();
      gate.complete();
      await made;
      await settle();

      final s = stateOf();
      expect(s.index, 1);
      expect(s.busy, isFalse);
      expect(s.multi, isTrue);
      // The picks were for the clip that left.
      expect(s.picked, isEmpty);
      expect(await session.confirmPicks(), isNull);
      expect(await reelsOf(ids[0]), {london.id});
      expect(await reelsOf(ids[1]), isEmpty);
    });

    test('a new reel goes to the clip the sheet was opened on', () async {
      final ids = await waiting(3);
      final london = await reel('London');
      final session = await start();
      // The sheet opened on the first clip; it left To tag meanwhile and the
      // player moved on.
      await spy.addClipsToReel(london.id, [ids[0]]);
      await settle();
      expect(stateOf().index, 1);

      final made = (await session.createReelAndTag('Paris', clipId: ids[0]))!;

      // The reel is made (the user asked for it), and nothing is tagged:
      // not the clip that left, and not the one showing now.
      expect(made.reel.name, 'Paris');
      expect(made.outcome, isNull);
      expect(await reelsOf(ids[0]), {london.id});
      expect(await reelsOf(ids[1]), isEmpty);
      expect(stateOf().index, 1);
      expect(stateOf().busy, isFalse);
    });

    test('a new reel while a hold runs waits for it, then is made', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final session = await start();

      final tagged = session.tapReel(goa.id);
      final made = session.createReelAndTag('Paris', clipId: ids[0]);
      await settle();
      expect((await reels.watchAll().first).map((r) => r.name), ['Goa']);
      holds.fireAll();
      expect((await tagged)!.clipId, ids[0]);
      final result = (await made)!;

      // The hold tagged the clip, so the new reel is only made.
      expect(result.reel.name, 'Paris');
      expect(result.outcome, isNull);
      expect(await reelsOf(ids[0]), {goa.id});
      expect(await reelsOf(ids[1]), isEmpty);
      expect(stateOf().index, 1);
    });
  });

  group('a clip deleted by a verify while its tag is written', () {
    /// A verify finds clip [id] gone from the phone: flagged, out of To tag
    /// and (in no reel) deleted.
    Future<void> verifyDeletes(int id) async {
      await h.media.clips.applyVerification(
        found: {},
        gone: {id},
        otherVideo: {},
      );
      expect(await spy.clipsByIds([id]), isEmpty);
    }

    /// Nothing was written for it and the player is not stuck on it.
    Future<void> expectNothingTagged(
      List<int> ids,
      int goneId,
      Reel goa,
    ) async {
      await settle();
      final s = stateOf();
      expect(s.busy, isFalse);
      expect(s.confirmingReelId, isNull);
      expect(s.taggedPerReel, isEmpty);
      expect(s.pending, ids.where((id) => id != goneId).toSet());
      expect(s.session[s.index], isNot(goneId), reason: 'moved on');
      expect(await reelsOf(ids[1]), isEmpty);
      expect(spy.addCalls.expand((call) => call.$2), isEmpty);
      expect((await reels.getById(goa.id))!.updatedAt, goa.updatedAt);
      expect(c.read(lastTagsProvider), isEmpty);
    }

    test(
      'a chip tap: nothing is tagged, no error, the player moves on',
      () async {
        final ids = await waiting(2);
        final goa = await reel('Goa');
        final session = await start();
        reels.onNames = () async {
          reels.onNames = null;
          await verifyDeletes(ids[0]);
        };

        final tagged = session.tapReel(goa.id);
        holds.fireAll();

        expect(await tagged, isNull);
        await expectNothingTagged(ids, ids[0], goa);
      },
    );

    test('Add to {k} reels: nothing is tagged, and the picks stay', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final london = await reel('London');
      final session = await start()
        ..setMulti(true)
        ..togglePick(goa.id)
        ..togglePick(london.id);
      reels.onNames = () async {
        reels.onNames = null;
        await verifyDeletes(ids[0]);
      };

      expect(await session.confirmPicks(), isNull);

      await expectNothingTagged(ids, ids[0], goa);
      expect((await reels.getById(london.id))!.updatedAt, london.updatedAt);
    });

    test('Same as previous: nothing is tagged', () async {
      final ids = await waiting(3);
      final goa = await reel('Goa');
      final session = await start();
      final first = session.tapReel(goa.id);
      holds.fireAll();
      await first;
      spy.addCalls.clear();
      final before = (await reels.getById(goa.id))!;
      reels.onNames = () async {
        reels.onNames = null;
        await verifyDeletes(ids[1]);
      };

      expect(await session.sameAsPrevious(), isNull);

      await settle();
      final s = stateOf();
      expect(s.busy, isFalse);
      expect(s.session[s.index], ids[2], reason: 'moved on');
      expect(s.taggedPerReel, {goa.id: 1}, reason: 'only the first tag');
      expect(spy.addCalls.expand((call) => call.$2), isEmpty);
      expect((await reels.getById(goa.id))!.updatedAt, before.updatedAt);
      expect(c.read(lastTagsProvider), [goa.id], reason: 'the earlier tag');
    });

    test('a new reel is still made; the gone clip is not tagged', () async {
      final ids = await waiting(2);
      final session = await start();
      final gate = reels.gate = Completer<void>();

      final made = session.createReelAndTag('Paris', clipId: ids[0]);
      await settle();
      await verifyDeletes(ids[0]);
      gate.complete();
      final result = (await made)!;

      expect(result.reel.name, 'Paris');
      expect(result.outcome, isNull);
      await settle();
      final s = stateOf();
      expect(s.busy, isFalse);
      expect(s.session[s.index], ids[1], reason: 'moved on');
      expect(s.taggedPerReel, isEmpty);
      expect(await reelsOf(ids[1]), isEmpty);
    });

    test('the next tag still works', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start();
      reels.onNames = () async {
        reels.onNames = null;
        await verifyDeletes(ids[0]);
      };
      final lost = session.tapReel(goa.id);
      holds.fireAll();
      expect(await lost, isNull);
      await settle();

      final next = session.tapReel(goa.id);
      holds.fireAll();

      expect((await next)!.clipId, ids[1]);
      expect(await reelsOf(ids[1]), {goa.id});
    });
  });

  group('failure', () {
    test('failure keeps the clip and clears busy', () async {
      final ids = await waiting(2);
      final goa = await reel('Goa');
      final session = await start();
      spy.failNext = const FileSystemException('the disk is full');

      final tagged = session.tapReel(goa.id);
      holds.fireAll();
      await expectLater(tagged, throwsA(isA<FileSystemException>()));

      var s = stateOf();
      expect(s.index, 0);
      expect(s.busy, isFalse);
      expect(s.confirmingReelId, isNull);
      expect(s.taggedPerReel, isEmpty);
      expect(c.read(lastTagsProvider), isEmpty);
      expect(await pendingIds(), ids.toSet());

      // The next try works.
      final again = session.tapReel(goa.id);
      holds.fireAll();
      expect(await again, isNotNull);
      s = stateOf();
      expect(s.index, 1);
      expect(await reelsOf(ids[0]), {goa.id});
    });
  });

  test('muted starts on and is kept', () async {
    await waiting(1);
    expect(c.read(tagPlayerMutedProvider), isTrue);
    c.read(tagPlayerMutedProvider.notifier).toggle();

    await start();
    sub.close();
    await settle();

    expect(c.read(tagPlayerMutedProvider), isFalse);
    // The viewer's switch is its own.
    expect(c.read(viewerMutedProvider), isFalse);
  });
}
