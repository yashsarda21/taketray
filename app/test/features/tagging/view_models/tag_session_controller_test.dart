import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/reels/view_models/clip_player.dart';
import 'package:taketray/features/tagging/view_models/last_tags.dart';
import 'package:taketray/features/tagging/view_models/tag_player_muted.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';

import '../../../support/reel_videos.dart';
import '../../../support/vm_harness.dart';

/// A hold that only ends when the test says so.
class FakeHold implements Timer {
  FakeHold(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  /// Whether it was cancelled before it fired.
  bool cancelled = false;

  /// Ends the hold now, as the real timer would after [duration]. A hold
  /// that was cancelled or has fired already does nothing.
  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() {
    if (_active) cancelled = true;
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// Every hold the controller asked for, in order.
class FakeHolds {
  final List<FakeHold> made = [];

  Timer call(Duration duration, void Function() callback) {
    final hold = FakeHold(duration, callback);
    made.add(hold);
    return hold;
  }

  /// Ends every hold still running.
  void fireAll() {
    for (final hold in [...made]) {
      hold.fire();
    }
  }
}

/// The real repository, with each `addClipsToReels` call recorded, and a
/// gate a test can close (the write waits) or a failure it can plant.
class SpyClips extends ClipsRepository {
  SpyClips(VmHarness h) : super(h.media.db, h.media.clock);

  final List<(List<int>, List<int>)> addCalls = [];
  Completer<void>? gate;
  Exception? failNext;

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

void main() {
  late VmHarness h;
  late FakeHolds holds;
  late SpyClips spy;
  late ProviderContainer c;
  late ReelsRepository reels;

  setUp(() {
    h = reelHarness();
    holds = FakeHolds();
    spy = SpyClips(h);
    c = ProviderContainer.test(
      overrides: [
        ...h.overrides,
        holdTimerProvider.overrideWithValue(holds.call),
        clipsRepositoryProvider.overrideWithValue(spy),
      ],
    );
    reels = c.read(reelsRepositoryProvider);
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
      // During the hold the clip is tagged elsewhere: the player moves on.
      await h.media.clips.addClipsToReel(london.id, [ids[0]]);
      await settle();
      expect(stateOf().index, 1);
      holds.fireAll();
      final outcome = (await tagged)!;

      expect(outcome.clipId, ids[0]);
      expect(await reelsOf(ids[0]), {goa.id, london.id});
      expect(await reelsOf(ids[1]), isEmpty);
      expect(await pendingIds(), {ids[1], ids[2]});
      expect(stateOf().index, 1);
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

      final outcome = (await session.createReelAndTag('Goa'))!;

      final goa = (await reels.watchAll().first).single;
      expect(goa.name, 'Goa');
      expect(outcome.reelNames, ['Goa']);
      expect(outcome.clipId, ids[0]);
      expect(await reelsOf(ids[0]), {goa.id});
      expect(stateOf().index, 1);
      expect(stateOf().taggedPerReel, {goa.id: 1});

      // A name that is taken is thrown to the form, and nothing moves.
      await expectLater(
        session.createReelAndTag('goa'),
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

      expect(await session.createReelAndTag('Paris'), isNull);

      final paris = (await reels.watchAll().first).firstWhere(
        (r) => r.name == 'Paris',
      );
      expect(stateOf().picked, [goa.id, paris.id]);
      expect(stateOf().index, 0);
      expect(stateOf().busy, isFalse);
      expect(await reelsOf(ids[0]), isEmpty);
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
