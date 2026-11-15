import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';

import '../../support/clip_setup.dart';
import '../../support/fixed_clock.dart';
import '../../support/reel_videos.dart';
import '../../support/test_database.dart';
import '../../support/vm_harness.dart';

// Every path a clip leaves a reel runs the copy clean-up first (R8, D-123):
// `removeFromReel`, `moveToReel`, `removeMissing` and the reel delete call
// `EditSessionService.beforeClipsLeaveReel` from their view models (tested
// there); the paths below have no screen of their own, so the repositories
// take a `BeforeClipsLeave` hook. Each test names the path and the exact
// calls, the order against the write, and what a throwing hook leaves.

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _minute = Duration(minutes: 1);
const String _phone = 'external_primary';

NewClip _clip(int id, {int? like}) => NewClip.mediaStore(
  mediaStoreId: id,
  volumeName: _phone,
  fingerprint: ClipFingerprint(
    sizeBytes: 1000 + (like ?? id),
    durationMs: 5000,
    dateTakenUtc: _t0,
    displayName: 'VID_$id.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  timeZoneId: 'Europe/London',
  generationAdded: 7,
);

bool _same(Clip stored, NewClip incoming) =>
    stored.fingerprint.sizeBytes == incoming.fingerprint.sizeBytes;

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ClipsRepository repo;
  late ReelsRepository reels;

  /// What the hook was asked: `reel:sorted clip ids`.
  late List<String> asked;

  /// The links (`reel:clip`) in the database each time the hook ran.
  late List<Set<String>> linksSeen;
  Exception? failWith;

  Future<void> hook(int reelId, Set<int> clipIds) async {
    asked.add('$reelId:${(clipIds.toList()..sort()).join(',')}');
    linksSeen.add({
      for (final l in await db.select(db.clipReels).get())
        '${l.reelId}:${l.clipId}',
    });
    final fail = failWith;
    if (fail != null) throw fail;
  }

  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    asked = [];
    linksSeen = [];
    failWith = null;
    repo = ClipsRepository(db, clock, beforeLeave: hook);
    reels = ReelsRepository(db, clock, beforeLeave: hook);
  });

  Future<int> save(NewClip clip) async =>
      (await repo.saveDetected([clip])).single;

  Future<Set<String>> links() async => {
    for (final l in await db.select(db.clipReels).get())
      '${l.reelId}:${l.clipId}',
  };

  group('undo of an add', () {
    test('asks about the clips whose link the add created, before the link '
        'goes; the clips the reel had already are not asked', () async {
      final goa = (await reels.create('Goa')).id;
      final had = await save(_clip(10));
      final fresh = await save(_clip(11));
      await repo.addClipsToReel(goa, [had]);
      clock.advance(_minute);
      final add = await repo.addClipsToReel(goa, [had, fresh]);

      await repo.undo(add);

      expect(asked, ['$goa:$fresh']);
      expect(linksSeen.single, contains('$goa:$fresh'));
      expect(await links(), {'$goa:$had'});
    });

    test('also through ReelsRepository.undoAll (the reel picker)', () async {
      final goa = (await reels.create('Goa')).id;
      final paris = (await reels.create('Paris')).id;
      final a = await save(_clip(10));
      final records = await repo.addClipsToReels({goa, paris}, [a]);

      await reels.undoAll(records);

      expect(asked.toSet(), {'$goa:$a', '$paris:$a'});
      expect(asked, hasLength(2));
      expect(await links(), isEmpty);
    });

    test('a link the user removed and added again since is not asked about '
        "(it is the user's now)", () async {
      final goa = (await reels.create('Goa')).id;
      final keep = (await reels.create('Keep')).id;
      final a = await save(_clip(10));
      await repo.addClipsToReel(keep, [a]);
      final add = await repo.addClipsToReel(goa, [a]);
      await repo.removeClipsFromReel(goa, [a]);
      clock.advance(_minute);
      await repo.addClipsToReel(goa, [a]);

      await repo.undo(add);

      expect(asked, isEmpty);
    });

    test('a hook that throws stops the undo before anything changes, and '
        'the same undo works once it does not throw', () async {
      final goa = (await reels.create('Goa')).id;
      final a = await save(_clip(10));
      final add = await repo.addClipsToReel(goa, [a]);
      failWith = Exception('copies not deleted');

      await expectLater(repo.undo(add), throwsException);
      expect(await links(), {'$goa:$a'});

      failWith = null;
      await repo.undo(add);
      expect(await links(), isEmpty);
    });

    test('an undone record is not asked about again', () async {
      final goa = (await reels.create('Goa')).id;
      final a = await save(_clip(10));
      final add = await repo.addClipsToReel(goa, [a]);
      await repo.undo(add);
      asked.clear();

      await repo.undo(add);

      expect(asked, isEmpty);
    });
  });

  group('undo of a move', () {
    test('asks about the target reel (where the move created the links), '
        'not the source', () async {
      final from = (await reels.create('From')).id;
      final to = (await reels.create('To')).id;
      final a = await save(_clip(10));
      final b = await save(_clip(11));
      await repo.addClipsToReel(from, [a, b]);
      final move = await repo.moveClips(from, to, [a, b]);

      await repo.undo(move);

      expect(asked, ['$to:$a,$b']);
      expect(linksSeen.single, containsAll(['$to:$a', '$to:$b']));
      expect(await links(), {'$from:$a', '$from:$b'});
    });
  });

  test('the undo of a remove, a reel delete, and a skip leaves nothing to '
      'clean up: no call', () async {
    final goa = (await reels.create('Goa')).id;
    final a = await save(_clip(10));
    await repo.addClipsToReel(goa, [a]);
    final removed = await repo.removeClipsFromReel(goa, [a]);
    await repo.undo(removed);
    final deleted = await reels.delete(goa);
    await reels.undo(deleted);

    expect(asked, isEmpty);
  });

  test('removeClipsFromReel and moveClips do not ask here (their callers '
      'ran the clean-up already: no second call)', () async {
    final from = (await reels.create('From')).id;
    final to = (await reels.create('To')).id;
    final a = await save(_clip(10));
    final b = await save(_clip(11));
    await repo.addClipsToReel(from, [a, b]);

    await repo.moveClips(from, to, [a]);
    await repo.removeClipsFromReel(from, [b]);

    expect(asked, isEmpty);
  });

  group('undoHandAdd', () {
    test('a new clip added to a reel by hand and a known clip linked to it: '
        'both asked before their links go', () async {
      final goa = (await reels.create('Goa')).id;
      final paris = (await reels.create('Paris')).id;
      final known = await save(_clip(10));
      await repo.addClipsToReel(paris, [known]);
      clock.advance(_minute);
      final add = await repo.addByHand(
        [_clip(10), _clip(11)],
        reelId: goa,
        sameVideo: _same,
      );

      await repo.undoHandAdd(add.undo);

      expect(asked, hasLength(1));
      final [entry] = asked;
      expect(entry, startsWith('$goa:'));
      final ids = entry.substring('$goa:'.length).split(',').map(int.parse);
      expect(ids.length, 2);
      expect(ids, contains(known));
      expect(linksSeen.single, hasLength(3));
      expect(await links(), {'$paris:$known'});
    });

    test('an add to To tag has no reel: no call', () async {
      final add = await repo.addByHand([_clip(10)], sameVideo: _same);

      await repo.undoHandAdd(add.undo);

      expect(asked, isEmpty);
    });

    test(
      'a hook that throws stops the undo; the clips stay in the reel; a '
      'second undo that works runs, and an undone one asks nothing',
      () async {
        final goa = (await reels.create('Goa')).id;
        final add = await repo.addByHand(
          [_clip(10)],
          reelId: goa,
          sameVideo: _same,
        );
        failWith = Exception('copies not deleted');

        await expectLater(repo.undoHandAdd(add.undo), throwsException);
        expect(await links(), hasLength(1));

        failWith = null;
        await repo.undoHandAdd(add.undo);
        expect(await links(), isEmpty);
        asked.clear();
        await repo.undoHandAdd(add.undo);
        expect(asked, isEmpty);
      },
    );
  });

  group('tagClip and untagToInbox', () {
    test('tagClip asks about the reels the clip loses, not the ones it '
        'keeps or gains', () async {
      final goa = (await reels.create('Goa')).id;
      final paris = (await reels.create('Paris')).id;
      final rome = (await reels.create('Rome')).id;
      final a = await save(_clip(10));
      await repo.addClipsToReels({goa, paris}, [a]);

      await repo.tagClip(a, {paris, rome});

      expect(asked, ['$goa:$a']);
      expect(linksSeen.single, contains('$goa:$a'));
      expect(await links(), {'$paris:$a', '$rome:$a'});
    });

    test('tagClip with a throwing hook changes nothing', () async {
      final goa = (await reels.create('Goa')).id;
      final paris = (await reels.create('Paris')).id;
      final a = await save(_clip(10));
      await repo.addClipsToReel(goa, [a]);
      failWith = Exception('copies not deleted');

      await expectLater(repo.tagClip(a, {paris}), throwsException);

      expect(await links(), {'$goa:$a'});
    });

    test('untagToInbox asks about every reel the clip is in', () async {
      final goa = (await reels.create('Goa')).id;
      final paris = (await reels.create('Paris')).id;
      final a = await save(_clip(10));
      await repo.addClipsToReels({goa, paris}, [a]);

      await repo.untagToInbox(a);

      expect(asked.toSet(), {'$goa:$a', '$paris:$a'});
      expect(asked, hasLength(2));
      expect(await links(), isEmpty);
    });

    test('untagToInbox with a throwing hook changes nothing', () async {
      final goa = (await reels.create('Goa')).id;
      final a = await save(_clip(10));
      await repo.addClipsToReel(goa, [a]);
      failWith = Exception('copies not deleted');

      await expectLater(repo.untagToInbox(a), throwsException);

      expect(await links(), {'$goa:$a'});
    });
  });

  group('reattachDetached merges', () {
    /// A detached clip numbered [id], in [reel]; the same video as [dupOf]
    /// under another number, which came in as a new clip and is in [dupReel].
    Future<(int, int)> detachedWithDuplicate(
      int id,
      int dupId, {
      required int dupReel,
    }) async {
      final detached = await save(_clip(id));
      await detachClips(db, {detached}, at: _t0);
      final dup = await save(_clip(dupId, like: id));
      await repo.addClipsToReel(dupReel, [dup]);
      return (detached, dup);
    }

    test('the duplicate that is merged away is asked about, in each of its '
        'reels, before the merge', () async {
      final goa = (await reels.create('Goa')).id;
      final paris = (await reels.create('Paris')).id;
      final (d, dup) = await detachedWithDuplicate(10, 110, dupReel: goa);
      await repo.addClipsToReel(paris, [dup]);

      final result = await repo.reattachDetached(_phone, {d: 110});

      expect(result.merged, 1);
      expect(asked.toSet(), {'$goa:$dup', '$paris:$dup'});
      expect(asked, hasLength(2));
      expect(linksSeen.first, contains('$goa:$dup'));
    });

    test('a hook that throws leaves that pair detached (left), the other '
        'pair still merges', () async {
      final goa = (await reels.create('Goa')).id;
      final (d1, dup1) = await detachedWithDuplicate(10, 110, dupReel: goa);
      final (d2, dup2) = await detachedWithDuplicate(11, 111, dupReel: goa);
      failWith = Exception('copies not deleted');
      Future<void> failFirstOnly(int reelId, Set<int> clipIds) async {
        if (clipIds.contains(dup1)) throw StateError('copies not deleted');
      }

      final picky = ClipsRepository(db, clock, beforeLeave: failFirstOnly);
      final result = await picky.reattachDetached(_phone, {d1: 110, d2: 111});

      expect((result.reattached, result.merged, result.left), (0, 1, 1));
      final clipRows = {for (final c in await db.select(db.clips).get()) c.id};
      expect(clipRows, containsAll([d1, dup1, d2]));
      expect(clipRows, isNot(contains(dup2)));
    });

    test('a plain re-attach (no clip holds the video) or a holder that is '
        'another video asks nothing', () async {
      final goa = (await reels.create('Goa')).id;
      final plain = await save(_clip(10));
      await repo.addClipsToReel(goa, [plain]);
      await detachClips(db, {plain}, at: _t0);
      final other = await save(_clip(11));
      await detachClips(db, {other}, at: _t0);
      final stale = await save(_clip(211, like: 999));
      await repo.addClipsToReel(goa, [stale]);

      final result = await repo.reattachDetached(_phone, {
        plain: 110,
        other: 211,
      });

      expect((result.reattached, result.merged, result.left), (1, 0, 1));
      expect(asked, isEmpty);
    });
  });

  group('the providers wire the editing service in', () {
    late VmHarness h;

    setUp(() {
      h = reelHarness();
      h.editors.allowAll();
      h.copy.allowAll();
      // Building the service hands the repositories their hook.
      h.container.read(editSessionServiceProvider);
    });

    Future<(int, List<int>)> reelWithCopies() async {
      final goa =
          (await h.container.read(reelsRepositoryProvider).create('Goa')).id;
      final ids = await putInReel(h, goa, [reelVideo(1), reelVideo(2)]);
      final sessions = EditSessionsRepository(h.media.db, h.media.clock);
      await sessions.startSession(goa, EditorApp.vn, 'Goa');
      for (final (i, id) in ids.indexed) {
        await sessions.recordCopies([
          EditCopy(
            reelId: goa,
            clipId: id,
            copyMediaStoreId: 500 + i,
            fileName: 'f$i.mp4',
            sizeBytes: 10,
            copiedAt: DateTime.utc(2026, 10, 29),
          ),
        ]);
      }
      h.editors.existing = {500, 501};
      return (goa, ids);
    }

    test('the clips provider: undo of a move deletes the copy in the '
        'target reel', () async {
      final (goa, [a, _]) = await reelWithCopies();
      final reels = h.container.read(reelsRepositoryProvider);
      final to = (await reels.create('To')).id;
      final sessions = EditSessionsRepository(h.media.db, h.media.clock);
      await sessions.startSession(to, EditorApp.vn, 'To');
      final clips = h.container.read(clipsRepositoryProvider);
      final move = await clips.moveClips(goa, to, [a]);
      await sessions.recordCopies([
        EditCopy(
          reelId: to,
          clipId: a,
          copyMediaStoreId: 700,
          fileName: 'moved.mp4',
          sizeBytes: 10,
          copiedAt: DateTime.utc(2026, 10, 29),
        ),
      ]);
      h.editors.existing = {700};

      await clips.undo(move);

      expect(h.editors.existing, isEmpty);
      expect(await sessions.copiesOf(to), isEmpty);
    });

    test(
      "the reels provider wires the same hook (the reel picker's undo)",
      () async {
        final (_, _) = await reelWithCopies();
        final reels = h.container.read(reelsRepositoryProvider);
        final clips = h.container.read(clipsRepositoryProvider);
        final to = (await reels.create('To')).id;
        final sessions = EditSessionsRepository(h.media.db, h.media.clock);
        await sessions.startSession(to, EditorApp.vn, 'To');
        final fresh = (await clips.saveDetected([_clip(77)])).single;
        final add = await clips.addClipsToReel(to, [fresh]);
        await sessions.recordCopies([
          EditCopy(
            reelId: to,
            clipId: fresh,
            copyMediaStoreId: 800,
            fileName: 'fresh.mp4',
            sizeBytes: 10,
            copiedAt: DateTime.utc(2026, 10, 29),
          ),
        ]);
        h.editors.existing = {800};

        await reels.undo(add);

        expect(h.editors.existing, isEmpty);
        expect(await sessions.copiesOf(to), isEmpty);
      },
    );
  });
}
