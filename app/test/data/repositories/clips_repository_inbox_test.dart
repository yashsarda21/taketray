import 'dart:async';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';

import '../../support/clip_setup.dart';
import '../../support/fixed_clock.dart';
import '../../support/shots.dart';
import '../../support/statement_log.dart';

// Skip, Skip all and Restore (D-94): each moves `inbox` rows between
// `pending` and `skipped` in one transaction, keeps their `addedAt`, and
// returns the rows it changed, as they were, for Undo.

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _minute = Duration(minutes: 1);

/// The part of a real clock's time that the database drops (see
/// `undo_test.dart`): stored times are still `_t0` plus whole minutes.
const Duration _subMillisecond = Duration(microseconds: 123);

/// Records every statement (as [StatementLog] does), and runs [armed] once,
/// right after the next `SELECT` from `inbox` and before its rows go back to
/// the caller: the moment between a read and the write that follows it.
class _InboxHook extends StatementLog {
  /// Runs once, then clears itself.
  Future<void> Function()? armed;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await super.runSelect(executor, statement, args);
    final hook = armed;
    if (hook != null && statement.contains('FROM "inbox"')) {
      armed = null;
      await hook();
    }
    return rows;
  }
}

late _InboxHook _hook;
late AppDatabase db;
late FixedClock clock;
late ClipsRepository clips;
late ReelsRepository reels;

/// A detected clip with MediaStore number [number].
NewClip shot(int number) =>
    mediaStoreShot(number, at: _t0.subtract(Duration(minutes: number)));

InboxEntry pendingAt(int clipId, DateTime at) =>
    InboxEntry(clipId: clipId, state: InboxState.pending, addedAt: at);

InboxEntry skippedAt(int clipId, DateTime at) =>
    InboxEntry(clipId: clipId, state: InboxState.skipped, addedAt: at);

void main() {
  setUp(() {
    _hook = _InboxHook();
    db = loggedTestDatabase(_hook);
    addTearDown(db.close);
    clock = FixedClock(_t0.add(_subMillisecond));
    clips = ClipsRepository(db, clock);
    reels = ReelsRepository(db, clock);
  });

  Future<Map<int, (InboxState, DateTime)>> inbox() async => {
    for (final row in await db.select(db.inbox).get())
      row.clipId: (row.state, row.addedAt),
  };

  group('skip', () {
    test('skip moves pending to skipped and returns them', () async {
      final [a, b, c] = await clips.saveDetected([shot(1), shot(2), shot(3)]);
      clock.advance(_minute);

      // Duplicates count once.
      final record = await clips.skipClips([b, a, b]);

      expect(record.after, InboxState.skipped);
      expect(record.before, [pendingAt(a, _t0), pendingAt(b, _t0)]);
      expect(record.isEmpty, isFalse);
      // The state moves; `addedAt` stays when the clip arrived.
      expect(await inbox(), {
        a: (InboxState.skipped, _t0),
        b: (InboxState.skipped, _t0),
        c: (InboxState.pending, _t0),
      });
      expect(
        () => record.before.add(pendingAt(c, _t0)),
        throwsUnsupportedError,
      );
    });

    test('skip ignores tagged and skipped clips', () async {
      final goa = await reels.create('Goa');
      final [pending, skipped] = await clips.saveDetected([shot(1), shot(2)]);
      final tagged = (await clips.addNewClipsToReel(goa.id, [shot(3)])).single;
      await clips.skipClips([skipped]);
      clock.advance(_minute);

      final record = await clips.skipClips([pending, skipped, tagged, 999]);

      expect(record.before, [pendingAt(pending, _t0)]);
      expect(await inbox(), {
        pending: (InboxState.skipped, _t0),
        skipped: (InboxState.skipped, _t0),
      });
      expect(await clips.watchReelIdsOf(tagged).first, {goa.id});
    });

    test('skip all takes every pending in one transaction', () async {
      final goa = await reels.create('Goa');
      final [a, b, skipped] = await clips.saveDetected([
        shot(1),
        shot(2),
        shot(3),
      ]);
      final tagged = (await clips.addNewClipsToReel(goa.id, [shot(4)])).single;
      await clips.skipClips([skipped]);
      clock.advance(_minute);

      // A scan saves a new video while skip all is between its read and its
      // write. The scan is another caller (outside skip all's zone), and the
      // hook gives it every chance to run there and then: it can only if
      // skip all has left its transaction.
      final outside = Zone.current;
      Future<List<int>>? scan;
      _hook.armed = () async {
        scan = outside.run(() => clips.saveDetected([shot(5)]));
        await Future.any<Object?>([
          scan!,
          Future<void>.delayed(const Duration(milliseconds: 200)),
        ]);
      };

      final record = await clips.skipAllPending();
      expect(scan, isNotNull, reason: 'skip all reads inbox first');
      final [scanned] = await scan!;

      expect(record.after, InboxState.skipped);
      expect(record.before, [pendingAt(a, _t0), pendingAt(b, _t0)]);
      // The scan's clip waited for skip all: it is not in the record and
      // stays in To tag, so Undo has nothing to lose and nothing to take.
      expect(await inbox(), {
        a: (InboxState.skipped, _t0),
        b: (InboxState.skipped, _t0),
        skipped: (InboxState.skipped, _t0),
        scanned: (InboxState.pending, _t0.add(_minute)),
      });
      expect(await clips.watchReelIdsOf(tagged).first, {goa.id});
    });
  });

  group('restore', () {
    test('restore moves skipped to pending', () async {
      final goa = await reels.create('Goa');
      final [s1, s2, pending] = await clips.saveDetected([
        shot(1),
        shot(2),
        shot(3),
      ]);
      final tagged = (await clips.addNewClipsToReel(goa.id, [shot(4)])).single;
      await clips.skipClips([s1, s2]);
      clock.advance(_minute);

      final record = await clips.restoreClips([s2, s1, pending, tagged, 999]);

      expect(record.after, InboxState.pending);
      expect(record.before, [skippedAt(s1, _t0), skippedAt(s2, _t0)]);
      expect(await inbox(), {
        s1: (InboxState.pending, _t0),
        s2: (InboxState.pending, _t0),
        pending: (InboxState.pending, _t0),
      });
      expect(await clips.watchReelIdsOf(tagged).first, {goa.id});
    });
  });

  group('edges', () {
    test('empty ids give an empty record', () async {
      final [id] = await clips.saveDetected([shot(1)]);
      _hook.writes.clear();

      final skip = await clips.skipClips(const []);
      final restore = await clips.restoreClips(const []);
      // A pending clip has nothing to restore.
      final restoreNone = await clips.restoreClips([id]);
      expect(_hook.writes, isEmpty);
      await clips.skipClips([id]);
      final before = await inbox();
      _hook.writes.clear();
      // Nothing is pending.
      final all = await clips.skipAllPending();

      for (final record in [skip, restore, restoreNone, all]) {
        expect(record.isEmpty, isTrue);
        expect(record.before, isEmpty);
      }
      expect(skip.after, InboxState.skipped);
      expect(restore.after, InboxState.pending);
      expect(all.after, InboxState.skipped);
      expect(_hook.writes, isEmpty);
      expect(await inbox(), before);

      // Undoing an empty record changes nothing.
      await clips.undoAll([skip, restore, restoreNone, all]);
      expect(_hook.writes, isEmpty);
      expect(await inbox(), before);
    });

    test('skip and restore take more ids than one batch', () async {
      const count = ClipsRepository.idBatch * 2 + 1;
      final ids = await clips.saveDetected([
        for (var n = 1; n <= count; n++) shot(n),
      ]);

      final skip = await clips.skipClips(ids);
      expect(skip.before, hasLength(count));
      expect(await clips.watchPendingCount().first, 0);

      final restore = await clips.restoreClips(ids);
      expect(restore.before, hasLength(count));
      expect(await clips.watchPendingCount().first, count);
    });

    test('watchSkippedCount follows skip, restore and skip all', () async {
      final [a, b, c] = await clips.saveDetected([shot(1), shot(2), shot(3)]);
      final counts = <int>[];
      final sub = clips.watchSkippedCount().listen(counts.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(counts.last, 0);

      await clips.skipClips([a]);
      await pumpEventQueue();
      expect(counts.last, 1);

      await clips.skipAllPending();
      await pumpEventQueue();
      expect(counts.last, 3);

      await clips.restoreClips([b, c]);
      await pumpEventQueue();
      expect(counts.last, 1);
      // Pending clips are not counted, and the pending count is its own.
      expect(await clips.watchPendingCount().first, 2);
    });

    test('skip, skip all and restore log ids and counts only', () async {
      final [a, b] = await clips.saveDetected([shot(1), shot(2)]);
      final lines = <String>[];
      final sub = Logger.root.onRecord.listen((r) => lines.add(r.message));
      addTearDown(sub.cancel);

      await clips.skipClips([a]);
      await clips.restoreClips([a]);
      await clips.skipAllPending();
      await clips.undo(await clips.restoreClips([a, b]));

      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(line, isNot(contains('VID_')));
        expect(line, isNot(contains('content://')));
      }
    });
  });
  group('placesOf reads one state (D-113)', () {
    test('a tag landing between its reads cannot mix two states', () async {
      final goa = await reels.create('Goa');
      final [id] = await clips.saveDetected([shot(1)]);
      expect(id, isPositive);

      // The user tags the clip (inbox row out, link in) the moment placesOf
      // has read the inbox and not yet the links. The tag is another caller
      // (outside placesOf's zone), and the hook gives it every chance to run
      // there and then: it can only if placesOf has left its transaction.
      final outside = Zone.current;
      Future<void>? tag;
      _hook.armed = () async {
        tag = outside.run(() => clips.tagClip(id, {goa.id}));
        await Future.any<Object?>([
          tag!,
          Future<void>.delayed(const Duration(milliseconds: 200)),
        ]);
      };

      final places = await clips.placesOf('external_primary', [1]);
      expect(tag, isNotNull, reason: 'placesOf reads the inbox');
      await tag;

      // Before the tag or after it, never "in To tag and in a reel".
      final place = places[1]!;
      final before = place.inbox == InboxState.pending && place.reelIds.isEmpty;
      final after = place.inbox == null && setEquals(place.reelIds, {goa.id});
      expect(
        before || after,
        isTrue,
        reason: 'got ${place.inbox} and ${place.reelIds}',
      );
      // And the read waited for nothing it did not need: the tag landed.
      expect(await clips.watchReelIdsOf(id).first, {goa.id});
    });
  });

  group('pending shot times (the background copy, D-106)', () {
    test('pending shot times ascending and only on change', () async {
      // shot(n) is shot n minutes before _t0: saved out of order.
      final [a, b, c] = await clips.saveDetected([shot(2), shot(5), shot(1)]);
      final seen = <List<DateTime>>[];
      final sub = clips.watchPendingShotTimes().listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      DateTime at(int n) => _t0.subtract(Duration(minutes: n));
      expect(seen, [
        [at(5), at(2), at(1)],
      ]);

      // A change that leaves the times as they were: no emission.
      await flagClips(db, {a}, missing: true, at: _t0);
      await reels.create('Trip');
      await pumpEventQueue();
      expect(seen, hasLength(1));

      // Skipped and tagged clips are not waiting.
      await clips.skipClips([b]);
      await pumpEventQueue();
      expect(seen.last, [at(2), at(1)]);
      final reel = await reels.create('Food');
      await clips.tagClip(c, {reel.id});
      await pumpEventQueue();
      expect(seen.last, [at(2)]);
      expect(seen, hasLength(3));

      expect(await clips.pendingShotTimes(), [at(2)]);
    });

    test('equal shot times are all kept', () async {
      await clips.saveDetected([
        mediaStoreShot(1, at: _t0),
        mediaStoreShot(2, at: _t0),
      ]);

      expect(await clips.watchPendingShotTimes().first, [_t0, _t0]);
      expect(await clips.pendingShotTimes(), [_t0, _t0]);
    });

    test('none waiting is an empty list', () async {
      expect(await clips.watchPendingShotTimes().first, isEmpty);
      expect(await clips.pendingShotTimes(), isEmpty);
    });
  });
}
