import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';

import '../../support/clip_setup.dart';
import '../../support/fixed_clock.dart';
import '../../support/statement_log.dart';

// Undo of Skip, Skip all and Restore (D-94): each row goes back to its state
// and `addedAt` only while it is still exactly as the action left it, so a
// clip that was tagged, restored, skipped or put back in To tag since keeps
// what happened to it. Through `undo` / `undoAll`, idempotent (D-84).

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _minute = Duration(minutes: 1);

/// The part of a real clock's time that the database drops (see
/// `undo_test.dart`): stored times are still `_t0` plus whole minutes.
const Duration _subMillisecond = Duration(microseconds: 123);

late StatementLog log;
late AppDatabase db;
late FixedClock clock;
late ClipsRepository clips;
late ReelsRepository reels;

/// A detected clip with MediaStore number [number].
NewClip shot(int number) => NewClip.mediaStore(
  mediaStoreId: number,
  volumeName: 'external_primary',
  fingerprint: ClipFingerprint(
    sizeBytes: 1000 + number,
    durationMs: 4000 + number,
    dateTakenUtc: _t0.subtract(Duration(minutes: number)),
    displayName: 'VID_$number.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  timeZoneId: 'Asia/Kolkata',
  generationAdded: 40 + number,
);

void main() {
  setUp(() {
    log = StatementLog();
    db = loggedTestDatabase(log);
    addTearDown(db.close);
    clock = FixedClock(_t0.add(_subMillisecond));
    clips = ClipsRepository(db, clock);
    reels = ReelsRepository(db, clock);
  });

  Future<Map<int, (InboxState, DateTime)>> inbox() async => {
    for (final row in await db.select(db.inbox).get())
      row.clipId: (row.state, row.addedAt),
  };

  Future<Set<int>> reelIdsOf(int clipId) => clips.watchReelIdsOf(clipId).first;

  /// Every row of every table a tag, skip or undo touches.
  Future<String> dump() async {
    String rows(List<Object> all) =>
        (all.map((r) => r.toString()).toList()..sort()).join('\n');
    return [
      rows(await db.select(db.reels).get()),
      rows(await db.select(db.clips).get()),
      rows(await db.select(db.clipReels).get()),
      rows(await db.select(db.inbox).get()),
    ].join('\n---\n');
  }

  test('undo skip puts them back pending with addedAt', () async {
    final [a, b, c] = await clips.saveDetected([shot(1), shot(2), shot(3)]);
    clock.advance(_minute);
    final start = await inbox();
    final record = await clips.skipClips([a, b]);
    clock.advance(_minute);

    await clips.undo(record);

    expect(await inbox(), start);
    expect(start, {
      a: (InboxState.pending, _t0),
      b: (InboxState.pending, _t0),
      c: (InboxState.pending, _t0),
    });
  });

  test('undo skip all leaves new clips pending', () async {
    final [a, b] = await clips.saveDetected([shot(1), shot(2)]);
    clock.advance(_minute);
    final record = await clips.skipAllPending();
    clock.advance(_minute);
    // A scan adds two clips after skip all; the user skips one of them.
    final [fresh, freshSkipped] = await clips.saveDetected([shot(3), shot(4)]);
    await clips.skipClips([freshSkipped]);

    await clips.undo(record);

    expect(await inbox(), {
      a: (InboxState.pending, _t0),
      b: (InboxState.pending, _t0),
      fresh: (InboxState.pending, _t0.add(_minute * 2)),
      freshSkipped: (InboxState.skipped, _t0.add(_minute * 2)),
    });
  });

  test('undo skip does not untag a clip tagged since', () async {
    final goa = await reels.create('Goa');
    final [tagged, other] = await clips.saveDetected([shot(1), shot(2)]);
    final record = await clips.skipClips([tagged, other]);
    // Tagged from Skipped through the picker.
    await clips.addClipsToReels({goa.id}, [tagged]);

    await clips.undo(record);

    expect(await reelIdsOf(tagged), {goa.id});
    expect(await inbox(), {other: (InboxState.pending, _t0)});
  });

  test('undo restore leaves a tagged clip alone', () async {
    final goa = await reels.create('Goa');
    final [tagged, other] = await clips.saveDetected([shot(1), shot(2)]);
    await clips.skipClips([tagged, other]);
    final record = await clips.restoreClips([tagged, other]);
    await clips.addClipsToReels({goa.id}, [tagged]);

    await clips.undo(record);

    expect(await reelIdsOf(tagged), {goa.id});
    expect(await inbox(), {other: (InboxState.skipped, _t0)});
  });

  test(
    'undo skip leaves a clip that came back to To tag since alone',
    () async {
      final goa = await reels.create('Goa');
      final [moved] = await clips.saveDetected([shot(1)]);
      final record = await clips.skipClips([moved]);
      await clips.addClipsToReel(goa.id, [moved]);
      clock.advance(_minute);
      // Back in To tag by another path: pending again, a new `addedAt`.
      await clips.untagToInbox(moved);

      await clips.undo(record);

      expect(await inbox(), {moved: (InboxState.pending, _t0.add(_minute))});
    },
  );

  test(
    'undo restore leaves a clip that came back to To tag since alone',
    () async {
      final goa = await reels.create('Goa');
      final [moved] = await clips.saveDetected([shot(1)]);
      await clips.skipClips([moved]);
      final record = await clips.restoreClips([moved]);
      await clips.addClipsToReel(goa.id, [moved]);
      clock.advance(_minute);
      // Pending again, as the restore left it, but by another path: the
      // `addedAt` says it is not the row the restore wrote.
      await clips.untagToInbox(moved);

      await clips.undo(record);

      expect(await inbox(), {moved: (InboxState.pending, _t0.add(_minute))});
    },
  );

  test('undo is idempotent', () async {
    final [a, b] = await clips.saveDetected([shot(1), shot(2)]);
    final record = await clips.skipClips([a, b]);
    await clips.undo(record);
    // Skipped again by a new action: its rows are as `record` left them.
    final again = await clips.skipClips([a]);
    final skippedAgain = await dump();

    await clips.undo(record);
    await clips.undoAll([record]);
    expect(await dump(), skippedAgain);

    // A double tap on Undo: both calls queue, the second changes nothing.
    await Future.wait([clips.undo(again), clips.undo(again)]);
    expect(await inbox(), {
      a: (InboxState.pending, _t0),
      b: (InboxState.pending, _t0),
    });
  });

  test('undoAll of an add and a skip is one transaction', () async {
    final goa = await reels.create('Goa');
    final paris = await reels.create('Paris');
    final [tagged, skipped] = await clips.saveDetected([shot(1), shot(2)]);
    clock.advance(_minute);
    final start = await dump();
    // The player: one clip into two reels, the next one skipped.
    final add = await clips.addClipsToReels({goa.id, paris.id}, [tagged]);
    final skip = await clips.skipClips([skipped]);
    final done = await dump();
    final records = <UndoRecord>[...add, skip];

    // Last to first: the skip goes back, Paris's link goes, then Goa's first
    // step (the To tag row back) fails. Nothing stays undone.
    log.failWhen = (sql) => sql.startsWith('INSERT INTO "inbox"');
    await expectLater(clips.undoAll(records), throwsA(isA<StateError>()));
    expect(await dump(), done);

    // Nothing was marked, so the same list works again, and once only.
    await clips.undoAll(records);
    expect(await dump(), start);
    await clips.undoAll(records);
    expect(await dump(), start);
  });

  test(
    'undo add after tag puts the clip back in To tag with its addedAt',
    () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final [id] = await clips.saveDetected([shot(1)]);
      clock.advance(_minute + _subMillisecond);
      // The player's tag: `addClipsToReels`, one record per reel.
      final records = await clips.addClipsToReels({goa.id, paris.id}, [id]);
      expect(await inbox(), isEmpty);
      clock.advance(_minute);

      await clips.undoAll(records);

      expect(await inbox(), {id: (InboxState.pending, _t0)});
      expect(await reelIdsOf(id), isEmpty);
      expect((await clips.clipsByIds([id])).single.id, id);
    },
  );
}
