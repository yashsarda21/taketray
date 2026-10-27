import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/housekeeping.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _minute = Duration(minutes: 1);

late AppDatabase db;
late FixedClock clock;
late ClipsRepository repo;
late ReelsRepository reels;

/// A detected clip with MediaStore id [id], shot [shotAt] (default: [_t0]).
NewClip mediaStoreClip(
  int id, {
  DateTime? shotAt,
  String volumeName = 'external_primary',
}) => NewClip.mediaStore(
  mediaStoreId: id,
  volumeName: volumeName,
  fingerprint: ClipFingerprint(
    sizeBytes: 1000 + id,
    durationMs: 5000,
    dateTakenUtc: shotAt ?? _t0,
    displayName: 'VID_$id.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  timeZoneId: 'Europe/London',
  generationAdded: 7,
);

NewClip pickerClip(String uri) => NewClip.picker(
  pickerUri: uri,
  fingerprint: ClipFingerprint(
    sizeBytes: 2000,
    durationMs: 8000,
    dateTakenUtc: _t0,
    displayName: 'picked.mp4',
  ),
  width: 0,
  height: 0,
  mimeType: 'video/mp4',
);

/// A [FixedClock] that, the first time it is read after [arm], starts an
/// orphan sweep outside the caller's transaction and does not wait for it.
///
/// The repositories read the clock inside their transaction, before they
/// insert a clip, so the sweep is queued while that transaction is open, just
/// like a reel delete or a remove-from-reel tapped at that moment. It runs as
/// soon as the database lets it: after the transaction if the clip and its
/// place are saved together, between them if someone split them in two.
class _SweepingClock extends FixedClock {
  _SweepingClock(super.time, this._db);

  final AppDatabase _db;
  bool _armed = false;

  /// The sweep started by the armed read: how many clips it deleted.
  Future<int>? sweep;

  void arm() => _armed = true;

  @override
  DateTime now() {
    if (_armed) {
      _armed = false;
      // Zone.root: outside the transaction's zone, so drift treats it as
      // another caller instead of running it inside the transaction.
      sweep = Zone.root.run(_db.deleteOrphanClips);
    }
    return super.now();
  }
}

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    repo = ClipsRepository(db, clock);
    reels = ReelsRepository(db, clock);
  });

  Future<List<int>> clipIds() async =>
      (await db.select(db.clips).get()).map((c) => c.id).toList()..sort();

  Future<List<InboxRow>> inboxRows() => db.select(db.inbox).get();

  Future<Set<int>> reelIdsOf(int clipId) async => {
    for (final l in await (db.select(
      db.clipReels,
    )..where((l) => l.clipId.equals(clipId))).get())
      l.reelId,
  };

  Future<DateTime> updatedAt(int reelId) async =>
      (await reels.getById(reelId))!.updatedAt;

  group('addDetectedClips', () {
    test('saves new clips as pending, in input order', () async {
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
        pickerClip('content://picker/1'),
      ]);

      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3));
      expect(await clipIds(), [...ids]..sort());
      final rows = await inboxRows();
      expect(rows.map((r) => r.clipId).toSet(), ids.toSet());
      expect(rows.map((r) => r.state).toSet(), {InboxState.pending});
      expect(rows.map((r) => r.addedAt).toSet(), {_t0});
      final first = await (db.select(
        db.clips,
      )..where((c) => c.id.equals(ids[0]))).getSingle();
      expect(first.mediaStoreId, 10);
      expect(first.firstSeenAt, _t0);
      expect(first.missing, isFalse);
      expect(first.lastVerifiedAt, isNull);
    });

    test(
      'the same clip detected twice is one clip, one inbox row, one id',
      () async {
        final first = await repo.addDetectedClips([mediaStoreClip(10)]);
        clock.advance(_minute);
        final second = await repo.addDetectedClips([mediaStoreClip(10)]);

        expect(second, first);
        expect(await clipIds(), first);
        final rows = await inboxRows();
        expect(rows, hasLength(1));
        expect(rows.single.addedAt, _t0);
        final clip = await db.select(db.clips).getSingle();
        expect(clip.firstSeenAt, _t0);
      },
    );

    test('the same clip twice in one call is one clip', () async {
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
        mediaStoreClip(10),
      ]);

      expect(ids[0], ids[2]);
      expect(ids[0], isNot(ids[1]));
      expect(await clipIds(), hasLength(2));
      expect(await inboxRows(), hasLength(2));
    });

    test('a picked clip is recognised by its picker URI', () async {
      final a = await repo.addDetectedClips([pickerClip('content://p/1')]);
      final b = await repo.addDetectedClips([pickerClip('content://p/1')]);
      final c = await repo.addDetectedClips([pickerClip('content://p/2')]);

      expect(b, a);
      expect(c.single, isNot(a.single));
      expect(await clipIds(), hasLength(2));
    });

    test('the same MediaStore id on another volume is another clip', () async {
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(10, volumeName: '1234-ABCD'),
      ]);

      expect(ids.toSet(), hasLength(2));
    });

    test(
      'a clip already tagged into a reel does not return to To tag',
      () async {
        final reel = await reels.create('Goa');
        final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
        await repo.tagClip(id, {reel.id});

        final again = await repo.addDetectedClips([mediaStoreClip(10)]);

        expect(again.single, id);
        expect(await inboxRows(), isEmpty);
        expect(await reelIdsOf(id), {reel.id});
      },
    );

    test('a skipped clip detected again stays skipped', () async {
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
      await repo.skip([id]);

      await repo.addDetectedClips([mediaStoreClip(10)]);

      expect((await inboxRows()).single.state, InboxState.skipped);
    });

    test('a detected clip survives the orphan sweep', () async {
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;

      await db.deleteOrphanClips();

      expect(await clipIds(), [id]);
    });

    test('an empty list does nothing', () async {
      expect(await repo.addDetectedClips([]), isEmpty);
      expect(await clipIds(), isEmpty);
    });
  });

  group('addNewClipsToReel', () {
    test('saves the clips linked to the reel, with no inbox row', () async {
      final reel = await reels.create('Goa');
      clock.advance(_minute);

      final ids = await repo.addNewClipsToReel(reel.id, [
        mediaStoreClip(10),
        pickerClip('content://p/1'),
      ]);

      expect(ids, hasLength(2));
      expect(await clipIds(), [...ids]..sort());
      expect(await inboxRows(), isEmpty);
      for (final id in ids) {
        expect(await reelIdsOf(id), {reel.id});
      }
      final links = await db.select(db.clipReels).get();
      expect(links.map((l) => l.addedAt).toSet(), {_t0.add(_minute)});
      expect(await updatedAt(reel.id), _t0.add(_minute));
    });

    test('finds a clip that is already known and links it', () async {
      final goa = await reels.create('Goa');
      final known = (await repo.addDetectedClips([mediaStoreClip(10)])).single;

      final ids = await repo.addNewClipsToReel(goa.id, [
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);

      expect(ids.first, known);
      expect(await clipIds(), hasLength(2));
      expect(await reelIdsOf(known), {goa.id});
      // It was in To tag before; adding it to a reel takes it out.
      expect(await inboxRows(), isEmpty);
    });

    test('a pending or skipped clip added to a reel leaves To tag', () async {
      final reel = await reels.create('Goa');
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
        mediaStoreClip(12),
      ]);
      await repo.skip([ids[1]]);

      await repo.addNewClipsToReel(reel.id, [
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);

      expect((await inboxRows()).map((r) => r.clipId), [ids[2]]);
      expect(await reelIdsOf(ids[0]), {reel.id});
      expect(await reelIdsOf(ids[1]), {reel.id});
    });

    test('a clip added this way survives the orphan sweep', () async {
      final reel = await reels.create('Goa');
      final ids = await repo.addNewClipsToReel(reel.id, [mediaStoreClip(10)]);

      expect(await db.deleteOrphanClips(), 0);

      expect(await clipIds(), ids);
    });

    test('adding a clip the reel already has keeps its addedAt', () async {
      final reel = await reels.create('Goa');
      await repo.addNewClipsToReel(reel.id, [mediaStoreClip(10)]);
      clock.advance(_minute);

      final ids = await repo.addNewClipsToReel(reel.id, [mediaStoreClip(10)]);

      expect(ids, hasLength(1));
      expect((await db.select(db.clipReels).getSingle()).addedAt, _t0);
      expect(await updatedAt(reel.id), _t0);
    });

    test('an unknown reel throws and saves nothing', () async {
      await expectLater(
        repo.addNewClipsToReel(99, [mediaStoreClip(10)]),
        throwsStateError,
      );
      expect(await clipIds(), isEmpty);
    });
  });

  group('a sweep while clips are being added cannot delete them (R6b)', () {
    late _SweepingClock sweeping;

    setUp(() {
      sweeping = _SweepingClock(_t0, db);
    });

    test('addDetectedClips: a sweep started mid-transaction cannot delete the '
        'new clip', () async {
      sweeping.arm();

      final [id] = await ClipsRepository(
        db,
        sweeping,
      ).addDetectedClips([mediaStoreClip(10)]);

      expect(sweeping.sweep, isNotNull, reason: 'the sweep was started');
      expect(await sweeping.sweep, 0);
      expect(await clipIds(), [id]);
      expect((await inboxRows()).single.clipId, id);
    });

    test('addNewClipsToReel: a sweep started mid-transaction cannot delete the '
        'new clip', () async {
      final reel = await reels.create('Goa');
      sweeping.arm();

      final ids = await ClipsRepository(db, sweeping).addNewClipsToReel(
        reel.id,
        [mediaStoreClip(10), pickerClip('content://p/1')],
      );

      expect(sweeping.sweep, isNotNull, reason: 'the sweep was started');
      expect(await sweeping.sweep, 0);
      expect(await clipIds(), [...ids]..sort());
      for (final id in ids) {
        expect(await reelIdsOf(id), {reel.id});
      }
    });

    // The same race between repositories: one adds clips while another
    // deletes a reel, whose transaction ends with the global sweep (D-56).
    // Both are started before either runs, so the delete's transaction is
    // queued right behind the add's.
    Future<int> reelWithAClipOnlyThere() async {
      final reel = await reels.create('Paris');
      await repo.addNewClipsToReel(reel.id, [mediaStoreClip(99)]);
      return reel.id;
    }

    test('addNewClipsToReel and a reel delete at once: the new clips stay, '
        "the deleted reel's clip goes", () async {
      final goa = await reels.create('Goa');
      final paris = await reelWithAClipOnlyThere();

      final (ids, _) = await (
        repo.addNewClipsToReel(goa.id, [
          mediaStoreClip(10),
          mediaStoreClip(11),
        ]),
        reels.delete(paris),
      ).wait;

      expect(await clipIds(), [...ids]..sort(), reason: 'clip 99 was swept');
      for (final id in ids) {
        expect(await reelIdsOf(id), {goa.id});
      }
    });

    test('addDetectedClips and a reel delete at once: the new clips stay, '
        "the deleted reel's clip goes", () async {
      final paris = await reelWithAClipOnlyThere();

      final (ids, _) = await (
        repo.addDetectedClips([mediaStoreClip(10), mediaStoreClip(11)]),
        reels.delete(paris),
      ).wait;

      expect(await clipIds(), [...ids]..sort(), reason: 'clip 99 was swept');
      expect({for (final r in await inboxRows()) r.clipId}, ids.toSet());
    });
  });

  group('tagClip', () {
    test('links the clip to its reels and leaves To tag', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;

      await repo.tagClip(id, {goa.id, paris.id});

      expect(await reelIdsOf(id), {goa.id, paris.id});
      expect(await inboxRows(), isEmpty);
    });

    test(
      'tagging again replaces the links and keeps addedAt of those that stay',
      () async {
        final goa = await reels.create('Goa');
        final paris = await reels.create('Paris');
        final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
        await repo.tagClip(id, {goa.id, paris.id});
        clock.advance(_minute);

        await repo.tagClip(id, {paris.id});

        expect(await reelIdsOf(id), {paris.id});
        final link = await db.select(db.clipReels).getSingle();
        expect(link.addedAt, _t0);
      },
    );

    test('a link gained later gets the time it was added', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
      await repo.tagClip(id, {goa.id});
      clock.advance(_minute);

      await repo.tagClip(id, {goa.id, paris.id});

      final links = await (db.select(
        db.clipReels,
      )..orderBy([(l) => OrderingTerm.asc(l.reelId)])).get();
      expect(links.map((l) => l.addedAt), [_t0, _t0.add(_minute)]);
    });

    test('bumps updatedAt of the reels that gained or lost the clip', () async {
      final kept = await reels.create('Kept');
      final lost = await reels.create('Lost');
      final gained = await reels.create('Gained');
      final untouched = await reels.create('Untouched');
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
      await repo.tagClip(id, {kept.id, lost.id});
      clock.advance(_minute);

      await repo.tagClip(id, {kept.id, gained.id});

      final later = _t0.add(_minute);
      expect(await updatedAt(kept.id), _t0);
      expect(await updatedAt(lost.id), later);
      expect(await updatedAt(gained.id), later);
      expect(await updatedAt(untouched.id), _t0);
    });

    test('removes a skipped clip from Skipped too', () async {
      final reel = await reels.create('Goa');
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
      await repo.skip([id]);

      await repo.tagClip(id, {reel.id});

      expect(await inboxRows(), isEmpty);
    });

    test('an empty set of reels is an ArgumentError', () async {
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;

      expect(() => repo.tagClip(id, {}), throwsArgumentError);
      expect((await inboxRows()).single.state, InboxState.pending);
    });

    test('an unknown clip or reel throws and changes nothing', () async {
      final reel = await reels.create('Goa');
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;

      await expectLater(repo.tagClip(99, {reel.id}), throwsStateError);
      await expectLater(repo.tagClip(id, {reel.id, 99}), throwsStateError);

      expect(await reelIdsOf(id), isEmpty);
      expect(await inboxRows(), hasLength(1));
    });
  });

  group('untagToInbox (Undo)', () {
    test('removes every link and puts the clip back in To tag', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
      await repo.tagClip(id, {goa.id, paris.id});
      clock.advance(_minute);

      await repo.untagToInbox(id);

      expect(await reelIdsOf(id), isEmpty);
      final row = (await inboxRows()).single;
      expect(row.clipId, id);
      expect(row.state, InboxState.pending);
      expect(row.addedAt, _t0.add(_minute));
      expect(await clipIds(), [id]);
      expect(await updatedAt(goa.id), _t0.add(_minute));
      expect(await updatedAt(paris.id), _t0.add(_minute));
    });

    test('a clip that is already pending stays one inbox row', () async {
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;

      await repo.untagToInbox(id);

      expect(await inboxRows(), hasLength(1));
    });

    test('an unknown clip throws', () async {
      await expectLater(repo.untagToInbox(99), throwsStateError);
    });
  });

  group('skip and restore', () {
    test('skip moves clips to Skipped and restore brings them back', () async {
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
        mediaStoreClip(12),
      ]);

      await repo.skip([ids[0], ids[1]]);
      expect(await repo.watchPendingCount().first, 1);
      expect((await repo.watchInbox(InboxState.skipped).first).length, 2);

      await repo.restore([ids[0], ids[1]]);
      expect(await repo.watchPendingCount().first, 3);
      expect(await repo.watchInbox(InboxState.skipped).first, isEmpty);
    });

    test('a clip that is in a reel (no inbox row) is left alone', () async {
      final reel = await reels.create('Goa');
      final id = (await repo.addNewClipsToReel(reel.id, [
        mediaStoreClip(1),
      ])).single;

      await repo.skip([id]);
      await repo.restore([id]);

      expect(await inboxRows(), isEmpty);
    });
  });

  group('addClipsToReel and removeClipsFromReel', () {
    test('add links the clips, once, and bumps updatedAt', () async {
      final reel = await reels.create('Goa');
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);
      clock.advance(_minute);

      await repo.addClipsToReel(reel.id, ids);
      expect(await updatedAt(reel.id), _t0.add(_minute));
      clock.advance(_minute);
      await repo.addClipsToReel(reel.id, ids);

      final links = await db.select(db.clipReels).get();
      expect(links, hasLength(2));
      expect(links.map((l) => l.addedAt).toSet(), {_t0.add(_minute)});
      // Nothing changed the second time, so the reel did not move.
      expect(await updatedAt(reel.id), _t0.add(_minute));
    });

    test('add takes pending and skipped clips out of To tag', () async {
      final reel = await reels.create('Goa');
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
        mediaStoreClip(12),
      ]);
      await repo.skip([ids[1]]);

      await repo.addClipsToReel(reel.id, [ids[0], ids[1]]);

      expect((await inboxRows()).map((r) => r.clipId), [ids[2]]);
      expect(await repo.watchPendingCount().first, 1);
      expect(await repo.watchInbox(InboxState.skipped).first, isEmpty);
    });

    test(
      'add throws for an unknown reel or clip and changes nothing',
      () async {
        final reel = await reels.create('Goa');
        final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;

        await expectLater(repo.addClipsToReel(99, [id]), throwsStateError);
        await expectLater(
          repo.addClipsToReel(reel.id, [id, 99]),
          throwsStateError,
        );

        expect(await db.select(db.clipReels).get(), isEmpty);
        expect(await inboxRows(), hasLength(1));
      },
    );

    test(
      'removing a clip from its last reel deletes it (no inbox row)',
      () async {
        final reel = await reels.create('Goa');
        final ids = await repo.addNewClipsToReel(reel.id, [
          mediaStoreClip(10),
          mediaStoreClip(11),
        ]);
        clock.advance(_minute);

        await repo.removeClipsFromReel(reel.id, [ids[0]]);

        expect(await clipIds(), [ids[1]]);
        expect(await updatedAt(reel.id), _t0.add(_minute));
      },
    );

    test('a clip still in another reel stays', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await repo.addNewClipsToReel(goa.id, [
        mediaStoreClip(10),
      ])).single;
      await repo.addClipsToReel(paris.id, [id]);

      await repo.removeClipsFromReel(goa.id, [id]);

      expect(await clipIds(), [id]);
      expect(await reelIdsOf(id), {paris.id});
    });

    test('a clip that is in To tag or Skipped stays', () async {
      final reel = await reels.create('Goa');
      final ids = await repo.addNewClipsToReel(reel.id, [
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);
      // The repository never leaves a clip in a reel and in a list at once,
      // so put the inbox rows in by hand to test the sweep on its own.
      await db
          .into(db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(ids[0]),
              state: InboxState.pending,
              addedAt: _t0,
            ),
          );
      await db
          .into(db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(ids[1]),
              state: InboxState.skipped,
              addedAt: _t0,
            ),
          );

      await repo.removeClipsFromReel(reel.id, ids);

      expect(await clipIds(), [...ids]..sort());
    });

    test('removing clips the reel does not have changes nothing', () async {
      final reel = await reels.create('Goa');
      final other = await reels.create('Other');
      final id = (await repo.addNewClipsToReel(other.id, [
        mediaStoreClip(10),
      ])).single;
      clock.advance(_minute);

      await repo.removeClipsFromReel(reel.id, [id, 99]);

      expect(await reelIdsOf(id), {other.id});
      expect(await updatedAt(reel.id), _t0);
    });

    test('removing from an unknown reel throws', () async {
      await expectLater(repo.removeClipsFromReel(99, [1]), throwsStateError);
    });

    test('keeps the VN copy row of the clip it deletes (D-54)', () async {
      final reel = await reels.create('Goa');
      final id = (await repo.addNewClipsToReel(reel.id, [
        mediaStoreClip(10),
      ])).single;
      await db
          .into(db.vnSessions)
          .insert(
            VnSessionsCompanion.insert(
              reelId: Value(reel.id),
              folderName: 'Goa',
              createdAt: _t0,
            ),
          );
      await db
          .into(db.vnCopies)
          .insert(
            VnCopiesCompanion.insert(
              reelId: reel.id,
              clipId: id,
              copyMediaStoreId: 500,
              fileName: 'VID_10.mp4',
              sizeBytes: 1010,
            ),
          );

      await repo.removeClipsFromReel(reel.id, [id]);

      expect(await clipIds(), isEmpty);
      expect(await db.select(db.vnCopies).get(), hasLength(1));
    });
  });

  group('recordVerification', () {
    test('flags missing and found clips and stamps the time', () async {
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
        mediaStoreClip(12),
      ]);
      await repo.recordVerification(found: {ids[0]}, missing: {ids[1]});
      clock.advance(_minute);

      // The first one goes missing, the second comes back.
      await repo.recordVerification(found: {ids[1]}, missing: {ids[0]});

      final rows = {for (final c in await db.select(db.clips).get()) c.id: c};
      expect(rows[ids[0]]!.missing, isTrue);
      expect(rows[ids[0]]!.lastVerifiedAt, _t0.add(_minute));
      expect(rows[ids[1]]!.missing, isFalse);
      expect(rows[ids[1]]!.lastVerifiedAt, _t0.add(_minute));
      // Not mentioned: untouched.
      expect(rows[ids[2]]!.missing, isFalse);
      expect(rows[ids[2]]!.lastVerifiedAt, isNull);
    });

    test('a clip in both sets is an ArgumentError', () async {
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;

      expect(
        () => repo.recordVerification(found: {id}, missing: {id}),
        throwsArgumentError,
      );
    });
  });

  group('watching', () {
    test('watchInbox is sorted by shooting time, ties by id', () async {
      final lateShot = _t0.add(const Duration(hours: 2));
      final earlyShot = _t0.subtract(const Duration(hours: 2));
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10, shotAt: lateShot),
        mediaStoreClip(11, shotAt: _t0),
        mediaStoreClip(12, shotAt: earlyShot),
        mediaStoreClip(13, shotAt: _t0),
      ]);

      final pending = await repo.watchInbox(InboxState.pending).first;

      expect(pending.map((c) => c.id), [ids[2], ids[1], ids[3], ids[0]]);
    });

    test('watchInbox maps every field of the clip', () async {
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
      await repo.recordVerification(found: {id}, missing: {});

      final clip = (await repo.watchInbox(InboxState.pending).first).single;

      expect(
        clip,
        Clip(
          id: id,
          source: ClipSource.mediaStore,
          mediaStoreId: 10,
          volumeName: 'external_primary',
          fingerprint: ClipFingerprint(
            sizeBytes: 1010,
            durationMs: 5000,
            dateTakenUtc: _t0,
            displayName: 'VID_10.mp4',
          ),
          width: 1080,
          height: 1920,
          mimeType: 'video/mp4',
          timeZoneId: 'Europe/London',
          generationAdded: 7,
          firstSeenAt: _t0,
          missing: false,
          lastVerifiedAt: _t0,
        ),
      );
    });

    test('watchInbox lists pending and skipped clips apart', () async {
      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);
      await repo.skip([ids[1]]);

      expect(
        (await repo.watchInbox(InboxState.pending).first).map((c) => c.id),
        [ids[0]],
      );
      expect(
        (await repo.watchInbox(InboxState.skipped).first).map((c) => c.id),
        [ids[1]],
      );
    });

    test('watchPendingCount follows detect, skip and tag', () async {
      final reel = await reels.create('Goa');
      final counts = <int>[];
      final sub = repo.watchPendingCount().listen(counts.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      final ids = await repo.addDetectedClips([
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);
      await pumpEventQueue();
      await repo.skip([ids[0]]);
      await pumpEventQueue();
      await repo.tagClip(ids[1], {reel.id});
      await pumpEventQueue();

      expect(counts, [0, 2, 1, 0]);
    });

    test('watchReelClips is sorted by shooting time, ties by id', () async {
      final reel = await reels.create('Goa');
      final other = await reels.create('Other');
      final lateShot = _t0.add(const Duration(hours: 1));
      final ids = await repo.addNewClipsToReel(reel.id, [
        mediaStoreClip(10, shotAt: lateShot),
        mediaStoreClip(11, shotAt: _t0),
        mediaStoreClip(12, shotAt: _t0),
      ]);
      await repo.addNewClipsToReel(other.id, [mediaStoreClip(13)]);

      final clips = await repo.watchReelClips(reel.id).first;

      expect(clips.map((c) => c.id), [ids[1], ids[2], ids[0]]);
    });

    test(
      'watchReelClips emits again when a clip is added or removed',
      () async {
        final reel = await reels.create('Goa');
        final seen = <List<int>>[];
        final sub = repo
            .watchReelClips(reel.id)
            .listen((clips) => seen.add([for (final c in clips) c.id]));
        addTearDown(sub.cancel);
        await pumpEventQueue();

        final ids = await repo.addNewClipsToReel(reel.id, [mediaStoreClip(10)]);
        await pumpEventQueue();
        await repo.removeClipsFromReel(reel.id, ids);
        await pumpEventQueue();

        expect(seen, [<int>[], ids, <int>[]]);
      },
    );

    test('watchReelIdsOf follows tag and Undo', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await repo.addDetectedClips([mediaStoreClip(10)])).single;
      final seen = <Set<int>>[];
      final sub = repo.watchReelIdsOf(id).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await repo.tagClip(id, {goa.id, paris.id});
      await pumpEventQueue();
      await repo.untagToInbox(id);
      await pumpEventQueue();

      expect(seen, [
        <int>{},
        {goa.id, paris.id},
        <int>{},
      ]);
    });
  });
}
