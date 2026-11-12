import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/housekeeping.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';

import '../../support/clip_setup.dart';
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

  // `saveDetected` (test/support/clip_setup.dart) is `addCheckedClips` with a
  // `sameVideo` that accepts every stored clip: the saving of new clips and
  // the finding of known ones. (These tests were written for the removed
  // `addDetectedClips`, which nothing in lib/ called.)
  group('addCheckedClips saving new and known clips', () {
    test('saves new clips as pending, in input order', () async {
      final ids = await repo.saveDetected([
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
        final first = await repo.saveDetected([mediaStoreClip(10)]);
        clock.advance(_minute);
        final second = await repo.saveDetected([mediaStoreClip(10)]);

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
      final ids = await repo.saveDetected([
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
      final a = await repo.saveDetected([pickerClip('content://p/1')]);
      final b = await repo.saveDetected([pickerClip('content://p/1')]);
      final c = await repo.saveDetected([pickerClip('content://p/2')]);

      expect(b, a);
      expect(c.single, isNot(a.single));
      expect(await clipIds(), hasLength(2));
    });

    test('the same MediaStore id on another volume is another clip', () async {
      final ids = await repo.saveDetected([
        mediaStoreClip(10),
        mediaStoreClip(10, volumeName: '1234-ABCD'),
      ]);

      expect(ids.toSet(), hasLength(2));
    });

    test(
      'a clip already tagged into a reel does not return to To tag',
      () async {
        final reel = await reels.create('Goa');
        final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
        await repo.tagClip(id, {reel.id});

        final again = await repo.saveDetected([mediaStoreClip(10)]);

        expect(again.single, id);
        expect(await inboxRows(), isEmpty);
        expect(await reelIdsOf(id), {reel.id});
      },
    );

    test('a skipped clip detected again stays skipped', () async {
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
      await repo.skipClips([id]);

      await repo.saveDetected([mediaStoreClip(10)]);

      expect((await inboxRows()).single.state, InboxState.skipped);
    });

    test('a detected clip survives the orphan sweep', () async {
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;

      await db.deleteOrphanClips();

      expect(await clipIds(), [id]);
    });

    test('an empty list does nothing', () async {
      expect(await repo.saveDetected([]), isEmpty);
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
      final known = (await repo.saveDetected([mediaStoreClip(10)])).single;

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
      final ids = await repo.saveDetected([
        mediaStoreClip(10),
        mediaStoreClip(11),
        mediaStoreClip(12),
      ]);
      await repo.skipClips([ids[1]]);

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

    test('addCheckedClips: a sweep started mid-transaction cannot delete the '
        'new clip', () async {
      sweeping.arm();

      final [id] = await ClipsRepository(
        db,
        sweeping,
      ).saveDetected([mediaStoreClip(10)]);

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

    test('addCheckedClips and a reel delete at once: the new clips stay, '
        "the deleted reel's clip goes", () async {
      final paris = await reelWithAClipOnlyThere();

      final (ids, _) = await (
        repo.saveDetected([mediaStoreClip(10), mediaStoreClip(11)]),
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
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;

      await repo.tagClip(id, {goa.id, paris.id});

      expect(await reelIdsOf(id), {goa.id, paris.id});
      expect(await inboxRows(), isEmpty);
    });

    test(
      'tagging again replaces the links and keeps addedAt of those that stay',
      () async {
        final goa = await reels.create('Goa');
        final paris = await reels.create('Paris');
        final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
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
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
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
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
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
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
      await repo.skipClips([id]);

      await repo.tagClip(id, {reel.id});

      expect(await inboxRows(), isEmpty);
    });

    test('an empty set of reels is an ArgumentError', () async {
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;

      expect(() => repo.tagClip(id, {}), throwsArgumentError);
      expect((await inboxRows()).single.state, InboxState.pending);
    });

    test('an unknown clip or reel throws and changes nothing', () async {
      final reel = await reels.create('Goa');
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;

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
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
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
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;

      await repo.untagToInbox(id);

      expect(await inboxRows(), hasLength(1));
    });

    test('an unknown clip throws', () async {
      await expectLater(repo.untagToInbox(99), throwsStateError);
    });
  });

  group('skip and restore', () {
    test('skip moves clips to Skipped and restore brings them back', () async {
      final ids = await repo.saveDetected([
        mediaStoreClip(10),
        mediaStoreClip(11),
        mediaStoreClip(12),
      ]);

      await repo.skipClips([ids[0], ids[1]]);
      expect(await repo.watchPendingCount().first, 1);
      expect((await repo.watchInbox(InboxState.skipped).first).length, 2);

      await repo.restoreClips([ids[0], ids[1]]);
      expect(await repo.watchPendingCount().first, 3);
      expect(await repo.watchInbox(InboxState.skipped).first, isEmpty);
    });

    test('a clip that is in a reel (no inbox row) is left alone', () async {
      final reel = await reels.create('Goa');
      final id = (await repo.addNewClipsToReel(reel.id, [
        mediaStoreClip(1),
      ])).single;

      await repo.skipClips([id]);
      await repo.restoreClips([id]);

      expect(await inboxRows(), isEmpty);
    });
  });

  group('addClipsToReel and removeClipsFromReel', () {
    test('add links the clips, once, and bumps updatedAt', () async {
      final reel = await reels.create('Goa');
      final ids = await repo.saveDetected([
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
      final ids = await repo.saveDetected([
        mediaStoreClip(10),
        mediaStoreClip(11),
        mediaStoreClip(12),
      ]);
      await repo.skipClips([ids[1]]);

      await repo.addClipsToReel(reel.id, [ids[0], ids[1]]);

      expect((await inboxRows()).map((r) => r.clipId), [ids[2]]);
      expect(await repo.watchPendingCount().first, 1);
      expect(await repo.watchInbox(InboxState.skipped).first, isEmpty);
    });

    test(
      'add throws for an unknown reel or clip and changes nothing',
      () async {
        final reel = await reels.create('Goa');
        final id = (await repo.saveDetected([mediaStoreClip(10)])).single;

        await expectLater(repo.addClipsToReel(99, [id]), throwsStateError);
        await expectLater(
          repo.addClipsToReel(reel.id, [id, 99]),
          throwsStateError,
        );

        expect(await db.select(db.clipReels).get(), isEmpty);
        expect(await inboxRows(), hasLength(1));
      },
    );

    group('addClipsToReels (several reels, one transaction)', () {
      Future<String> state() async => [
        for (final l in await db.select(db.clipReels).get())
          'link ${l.clipId} ${l.reelId} ${l.addedAt}',
        for (final i in await inboxRows())
          'inbox ${i.clipId} ${i.state} ${i.addedAt}',
        for (final r in await db.select(db.reels).get())
          'reel ${r.id} ${r.updatedAt}',
      ].join('\n');

      test(
        'adds to every reel and gives one record per reel, in order',
        () async {
          final goa = await reels.create('Goa');
          final paris = await reels.create('Paris');
          final lisbon = await reels.create('Lisbon');
          final ids = await repo.saveDetected([
            mediaStoreClip(10),
            mediaStoreClip(11),
          ]);

          final records = await repo.addClipsToReels({
            lisbon.id,
            goa.id,
            paris.id,
          }, ids);

          expect(records.map((r) => r.reelId), [lisbon.id, goa.id, paris.id]);
          for (final record in records) {
            expect(record.createdLinks.map((l) => l.clipId), ids);
          }
          for (final reel in [goa, paris, lisbon]) {
            expect(await repo.watchReelClips(reel.id).first, hasLength(2));
          }
          // The clips left To tag once, by the first reel's record.
          expect(await inboxRows(), isEmpty);
        },
      );

      test('a reel that is gone, second in line, leaves nothing added '
          'to the first', () async {
        final goa = await reels.create('Goa');
        final ids = await repo.saveDetected([mediaStoreClip(10)]);
        clock.advance(_minute);
        final before = await state();

        await expectLater(
          repo.addClipsToReels({goa.id, 99}, ids),
          throwsStateError,
        );

        expect(await state(), before);
        expect(await db.select(db.clipReels).get(), isEmpty);
        expect(await inboxRows(), hasLength(1));
        expect(await updatedAt(goa.id), _t0);
      });

      test('a clip that is gone fails before any reel changes', () async {
        final goa = await reels.create('Goa');
        final paris = await reels.create('Paris');
        final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
        final before = await state();

        await expectLater(
          repo.addClipsToReels({goa.id, paris.id}, [id, 99]),
          throwsStateError,
        );

        expect(await state(), before);
      });

      test('undoing the records last to first restores everything', () async {
        final goa = await reels.create('Goa');
        final paris = await reels.create('Paris');
        final ids = await repo.saveDetected([
          mediaStoreClip(10),
          mediaStoreClip(11),
        ]);
        await repo.skipClips([ids.last]);
        // With microseconds, as a real clock has: the records must hold the
        // times the database stores (milliseconds), or undo misreads them.
        clock.advance(_minute + const Duration(microseconds: 123));
        final before = await state();

        final records = await repo.addClipsToReels({goa.id, paris.id}, ids);
        expect(await state(), isNot(before));
        for (final record in records.reversed) {
          await repo.undo(record);
        }

        expect(await state(), before);
      });

      test('a clip a reel has already makes an empty record for it', () async {
        final goa = await reels.create('Goa');
        final paris = await reels.create('Paris');
        final ids = await repo.addNewClipsToReel(goa.id, [mediaStoreClip(10)]);

        final records = await repo.addClipsToReels({goa.id, paris.id}, ids);

        expect(records.first.isEmpty, isTrue);
        expect(records.last.createdLinks, hasLength(1));
      });

      test('no reels gives no records and changes nothing', () async {
        final ids = await repo.saveDetected([mediaStoreClip(10)]);
        final before = await state();

        expect(await repo.addClipsToReels(const {}, ids), isEmpty);

        expect(await state(), before);
      });
    });

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
          .into(db.editSessions)
          .insert(
            EditSessionsCompanion.insert(
              reelId: Value(reel.id),
              folderName: 'Goa',
              createdAt: _t0,
            ),
          );
      await db
          .into(db.editCopies)
          .insert(
            EditCopiesCompanion.insert(
              reelId: reel.id,
              clipId: id,
              copyMediaStoreId: 500,
              fileName: 'VID_10.mp4',
              sizeBytes: 1010,
            ),
          );

      await repo.removeClipsFromReel(reel.id, [id]);

      expect(await clipIds(), isEmpty);
      expect(await db.select(db.editCopies).get(), hasLength(1));
    });
  });

  group('phone queries, rebuild remap and verification', () {
    Future<ClipRow> rowOf(int id) =>
        (db.select(db.clips)..where((c) => c.id.equals(id))).getSingle();

    /// Every row of every table, as text.
    Future<String> snapshot() async => [
      for (final table in db.allTables)
        '${table.actualTableName}: ${await db.select(table).get()}',
    ].join('\n');

    Future<List<int>> detect(List<int> mediaStoreIds, {String? volume}) =>
        repo.saveDetected([
          for (final id in mediaStoreIds)
            mediaStoreClip(id, volumeName: volume ?? 'external_primary'),
        ]);

    /// A picked clip that (wrongly, only a hand-made backup can do it) carries
    /// a volume and a MediaStore id. Returns its clip id.
    Future<int> pickerWithVolume(int mediaStoreId) => db
        .into(db.clips)
        .insert(
          ClipsCompanion.insert(
            source: ClipSource.picker,
            mediaStoreId: Value(mediaStoreId),
            volumeName: const Value('external_primary'),
            pickerUri: const Value('content://p/with-volume'),
            sizeBytes: 1,
            durationMs: 1,
            dateTakenUtc: _t0,
            displayName: 'picked.mp4',
            width: 0,
            height: 0,
            mimeType: 'video/mp4',
            firstSeenAt: _t0,
          ),
        );

    group('mediaStoreClipsHolding', () {
      test(
        'the attached MediaStore clips holding those numbers, by number',
        () async {
          final [a, b] = await detect([10, 11]);
          await detect([12], volume: '1234-ABCD');
          await pickerWithVolume(13);
          await detachClips(db, {b}, at: clock.now());

          final held = await repo.mediaStoreClipsHolding('external_primary', [
            10,
            11,
            12,
            13,
            99,
          ]);

          expect(held.keys, [10]);
          expect(held[10]!.id, a);
          expect(
            (await repo.mediaStoreClipsHolding('1234-ABCD', [10, 12])).keys,
            [12],
          );
          expect(
            await repo.mediaStoreClipsHolding('external_primary', []),
            isEmpty,
          );
        },
      );

      test('works past one batch of numbers', () async {
        await detect([for (var i = 1; i <= 1201; i++) i]);

        final held = await repo.mediaStoreClipsHolding('external_primary', [
          for (var i = 1; i <= 1300; i++) i,
        ]);

        expect(held.keys.toSet(), {for (var i = 1; i <= 1201; i++) i});
      });
    });

    group('addCheckedClips (Ruling U)', () {
      bool sameFingerprint(Clip stored, NewClip incoming) =>
          stored.fingerprint == incoming.fingerprint;

      /// Clip 10's number, now holding a different video (another size).
      final otherVideo = mediaStoreClip(10).copyWith(
        fingerprint: mediaStoreClip(10).fingerprint.copyWith(sizeBytes: 77),
      );

      test(
        'a stored clip that is the same video is found, not inserted',
        () async {
          final [a] = await detect([10]);

          final result = await repo.addCheckedClips([
            mediaStoreClip(10),
            mediaStoreClip(11),
          ], sameVideo: sameFingerprint);

          expect(result.ids.first, a);
          expect(result.inserted, [result.ids.last]);
          expect(result.detached, isEmpty);
          expect((await rowOf(a)).mediaStoreId, 10);
        },
      );

      test('a stored clip that is another video is detached and the video '
          'saved as a new clip; the old one keeps its reel', () async {
        final [a] = await detect([10]);
        final reel = await reels.create('Goa');
        await repo.tagClip(a, {reel.id});

        final result = await repo.addCheckedClips([
          otherVideo,
        ], sameVideo: sameFingerprint);

        expect(result.detached, {a});
        expect(result.inserted, hasLength(1));
        final fresh = result.inserted.single;
        expect(fresh, isNot(a));
        final old = await rowOf(a);
        expect((old.mediaStoreId, old.missing), (-a, true));
        expect(await repo.watchReelIdsOf(a).first, {reel.id});
        final created = await rowOf(fresh);
        expect((created.mediaStoreId, created.sizeBytes), (10, 77));
        expect(
          [
            for (final c in await repo.watchInbox(InboxState.pending).first)
              c.id,
          ],
          [fresh],
        );
      });

      test('an inbox-only stored clip that is another video leaves To tag '
          '(Ruling Y)', () async {
        final [a] = await detect([10]);

        final result = await repo.addCheckedClips([
          otherVideo,
        ], sameVideo: sameFingerprint);

        expect(result.detached, {a});
        final ids = [for (final c in await db.select(db.clips).get()) c.id];
        expect(ids, [result.inserted.single], reason: 'the old row was swept');
        expect(
          [
            for (final c in await repo.watchInbox(InboxState.pending).first)
              c.id,
          ],
          [result.inserted.single],
        );
      });

      test(
        'a skipped stored clip that is another video leaves Skipped',
        () async {
          final [a] = await detect([10]);
          await repo.skipClips([a]);

          await repo.addCheckedClips([otherVideo], sameVideo: sameFingerprint);

          expect(await repo.watchInbox(InboxState.skipped).first, isEmpty);
          expect(
            (await db.select(db.clips).get()).map((c) => c.id),
            isNot(contains(a)),
          );
        },
      );

      test('the detach, the list removal and the insert are one transaction '
          'when the removal fails', () async {
        await detect([10]);
        await db.customStatement(
          'CREATE TRIGGER no_delete BEFORE DELETE ON inbox '
          "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
        final before = await snapshot();

        await expectLater(
          repo.addCheckedClips([otherVideo], sameVideo: sameFingerprint),
          throwsA(anything),
        );

        expect(await snapshot(), before);
      });

      test('the detach and the insert are one transaction', () async {
        await detect([10]);
        await db.customStatement(
          'CREATE TRIGGER no_inbox BEFORE INSERT ON inbox '
          "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
        final before = await snapshot();

        await expectLater(
          repo.addCheckedClips([otherVideo], sameVideo: sameFingerprint),
          throwsA(anything),
        );

        expect(await snapshot(), before);
      });

      test(
        'a picked clip holding the identity is never taken for the video',
        () async {
          await pickerWithVolume(55);
          var asked = false;
          final before = await snapshot();

          // The unique key refuses a second holder of (volume, 55): the call
          // fails and changes nothing, instead of "finding" the picked clip.
          await expectLater(
            repo.addCheckedClips([
              mediaStoreClip(55),
            ], sameVideo: (_, _) => asked = true),
            throwsA(anything),
          );

          expect(asked, isFalse);
          expect(await snapshot(), before);
        },
      );
    });

    group('applyVerification', () {
      test('detaches, flags and takes missing clips out of the lists, in one '
          'go', () async {
        final [found, gone, other, inReel] = await detect([10, 11, 12, 13]);
        final reel = await reels.create('Goa');
        await repo.tagClip(inReel, {reel.id});
        clock.advance(_minute);

        final removed = await repo.applyVerification(
          found: {found},
          gone: {gone, inReel},
          otherVideo: {other},
        );

        expect(removed, 2);
        final kept = await rowOf(found);
        expect((kept.missing, kept.lastVerifiedAt), (false, clock.now()));
        final flagged = await rowOf(inReel);
        expect((flagged.mediaStoreId, flagged.missing), (13, true));
        expect(flagged.lastVerifiedAt, clock.now());
        expect(await repo.watchReelIdsOf(inReel).first, {reel.id});
        final ids = [for (final c in await db.select(db.clips).get()) c.id];
        expect(ids, unorderedEquals([found, inReel]));
      });

      // The tests below moved here from the removed `detach`,
      // `recordVerification` and `removeMissingFromLists` (nothing in lib/
      // called them; this is the one method that does what they did).
      test('otherVideo clips are detached like lost ones: a negative id, '
          'missing, the time, the volume; a reel keeps its clip', () async {
        final [a, b] = await detect([10, 11]);
        final goa = (await reels.create('Goa')).id;
        await repo.tagClip(a, {goa});
        clock.advance(_minute);

        await repo.applyVerification(found: {}, gone: {}, otherVideo: {a, b});

        final row = await rowOf(a);
        expect(row.mediaStoreId, -a);
        expect(row.missing, isTrue);
        expect(row.lastVerifiedAt, _t0.add(_minute));
        expect(row.volumeName, 'external_primary');
        expect(await reelIdsOf(a), {goa});
        // b was only in To tag: it left (detach alone used to keep it).
        expect(await clipIds(), [a]);
        expect(await inboxRows(), isEmpty);
      });

      test('an unknown id is ignored without an error, other clips stay '
          'as they are', () async {
        final [a, b] = await detect([10, 11]);
        clock.advance(_minute);

        final removed = await repo.applyVerification(
          found: {},
          gone: {9999},
          otherVideo: {9998},
        );

        expect(removed, 0);
        expect((await rowOf(a)).mediaStoreId, 10);
        expect((await rowOf(b)).missing, isFalse);
        expect(await inboxRows(), hasLength(2));
      });

      test('a picked clip in otherVideo has no MediaStore id to detach: it '
          'is not flagged and keeps its place in To tag', () async {
        // Also the "missing" guard of the list removal: only a clip that is
        // flagged missing in the same transaction leaves the lists.
        final [picked] = await repo.saveDetected([pickerClip('content://p/1')]);
        final before = await snapshot();

        final removed = await repo.applyVerification(
          found: {},
          gone: {},
          otherVideo: {picked},
        );

        expect(removed, 0);
        expect(await snapshot(), before);
        expect((await inboxRows()).single.clipId, picked);
      });

      test('a picked clip that carries a volume and an id is left '
          'unchanged in otherVideo', () async {
        await detect([10]);
        final picked = await pickerWithVolume(55);
        // In To tag, so the orphan sweep does not take it.
        await db
            .into(db.inbox)
            .insert(
              InboxCompanion.insert(
                clipId: Value(picked),
                state: InboxState.pending,
                addedAt: _t0,
              ),
            );
        final before = await snapshot();

        await repo.applyVerification(found: {}, gone: {}, otherVideo: {picked});

        expect(await snapshot(), before);
      });

      // Phase 7 final review I-1 (D-116): a picked clip whose address cannot
      // be read may be on an unplugged drive; it is flagged, never removed.
      test('flagOnly clips are flagged missing and keep their place in To tag, '
          'Skipped and a reel; nothing is deleted', () async {
        final [inTag, inSkipped, inReel] = [
          for (final n in [1, 2, 3])
            (await repo.saveDetected([pickerClip('content://p/$n')])).single,
        ];
        await repo.skipClips([inSkipped]);
        final goa = (await reels.create('Goa')).id;
        await repo.tagClip(inReel, {goa});
        clock.advance(_minute);

        final removed = await repo.applyVerification(
          found: {},
          gone: {},
          otherVideo: {},
          flagOnly: {inTag, inSkipped, inReel},
        );

        expect(removed, 0);
        for (final id in [inTag, inSkipped, inReel]) {
          final row = await rowOf(id);
          expect((row.missing, row.lastVerifiedAt), (true, clock.now()));
          expect(row.pickerUri, isNotNull, reason: 'its address is kept');
        }
        expect(await clipIds(), unorderedEquals([inTag, inSkipped, inReel]));
        expect(
          {for (final r in await inboxRows()) r.clipId: r.state},
          {inTag: InboxState.pending, inSkipped: InboxState.skipped},
        );
        expect(await reelIdsOf(inReel), {goa});
      });

      test('flagOnly beside gone: the gone clip leaves, the flagOnly one '
          'stays', () async {
        final [gone] = await detect([10]);
        final [picked] = await repo.saveDetected([pickerClip('content://p/1')]);

        final removed = await repo.applyVerification(
          found: {},
          gone: {gone},
          otherVideo: {},
          flagOnly: {picked},
        );

        expect(removed, 1);
        expect(await clipIds(), [picked]);
        expect((await rowOf(picked)).missing, isTrue);
        expect((await inboxRows()).single.clipId, picked);
      });

      test('flagOnly alone is not "nothing to apply"', () async {
        final [picked] = await repo.saveDetected([pickerClip('content://p/1')]);
        clock.advance(_minute);

        await repo.applyVerification(
          found: {},
          gone: {},
          otherVideo: {},
          flagOnly: {picked},
        );

        expect((await rowOf(picked)).missing, isTrue);
      });

      test('a flagged flagOnly clip found again is un-flagged by the next '
          'verification', () async {
        final [picked] = await repo.saveDetected([pickerClip('content://p/1')]);
        await repo.applyVerification(
          found: {},
          gone: {},
          otherVideo: {},
          flagOnly: {picked},
        );
        clock.advance(_minute);

        await repo.applyVerification(found: {picked}, gone: {}, otherVideo: {});

        final row = await rowOf(picked);
        expect((row.missing, row.lastVerifiedAt), (false, clock.now()));
        expect((await inboxRows()).single.clipId, picked);
      });

      test(
        'a clip in flagOnly and another set throws and writes nothing',
        () async {
          final [a, b] = await detect([10, 11]);
          final before = await snapshot();
          for (final call in <Future<int> Function()>[
            () => repo.applyVerification(
              found: {a},
              gone: {},
              otherVideo: {},
              flagOnly: {a},
            ),
            () => repo.applyVerification(
              found: {},
              gone: {a},
              otherVideo: {},
              flagOnly: {a},
            ),
            () => repo.applyVerification(
              found: {b},
              gone: {},
              otherVideo: {a},
              flagOnly: {a},
            ),
          ]) {
            await expectLater(call(), throwsArgumentError);
          }
          expect(await snapshot(), before);
        },
      );

      test('detaching twice keeps the negative id', () async {
        final [a] = await detect([10]);
        final goa = (await reels.create('Goa')).id;
        await repo.tagClip(a, {goa});

        await repo.applyVerification(found: {}, gone: {}, otherVideo: {a});
        clock.advance(_minute);
        await repo.applyVerification(found: {}, gone: {}, otherVideo: {a});

        expect((await rowOf(a)).mediaStoreId, -a);
      });

      test('gone clips: inbox-only and skipped ones are deleted, one in a '
          'reel stays flagged', () async {
        final [pending, skipped, inReel] = await detect([10, 11, 12]);
        final goa = (await reels.create('Goa')).id;
        await repo.tagClip(inReel, {goa});
        await repo.skipClips([skipped]);

        final deleted = await repo.applyVerification(
          found: {},
          gone: {pending, skipped, inReel},
          otherVideo: {},
        );

        expect(deleted, 2);
        expect(await clipIds(), [inReel]);
        expect(await inboxRows(), isEmpty);
        expect(await reelIdsOf(inReel), {goa});
        expect((await rowOf(inReel)).missing, isTrue);
      });

      test('a clip in both the inbox and a reel keeps its link and row; '
          'only the inbox row goes', () async {
        final [both, gone] = await detect([10, 11]);
        final goa = (await reels.create('Goa')).id;
        await repo.tagClip(both, {goa});
        // The database allows an inbox row beside a link (a backup drops
        // them, the repository never writes them).
        await db
            .into(db.inbox)
            .insert(
              InboxCompanion.insert(
                clipId: Value(both),
                state: InboxState.pending,
                addedAt: _t0,
              ),
            );
        final updatedBefore = await updatedAt(goa);

        final deleted = await repo.applyVerification(
          found: {},
          gone: {both, gone},
          otherVideo: {},
        );

        expect(deleted, 1);
        expect(await clipIds(), [both]);
        expect(await inboxRows(), isEmpty);
        expect(await reelIdsOf(both), {goa});
        expect(await updatedAt(goa), updatedBefore);
      });

      test('a found clip that was flagged missing is flagged back and keeps '
          'its inbox row; the gone one leaves', () async {
        // A stale picture: `stale` was missing, and is found now.
        final [stale, gone] = await detect([10, 11]);
        await flagClips(db, {stale, gone}, missing: true, at: clock.now());

        final deleted = await repo.applyVerification(
          found: {stale},
          gone: {gone},
          otherVideo: {},
        );

        expect(deleted, 1);
        expect(await clipIds(), [stale]);
        expect((await inboxRows()).single.clipId, stale);
        expect((await rowOf(stale)).missing, isFalse);
      });

      test(
        'a clip that was never missing keeps its inbox row when found',
        () async {
          final [a] = await detect([10]);

          expect(
            await repo.applyVerification(found: {a}, gone: {}, otherVideo: {}),
            0,
          );

          expect(await clipIds(), [a]);
          expect(await inboxRows(), hasLength(1));
        },
      );

      test('gone is flagged and found is flagged back, with the time; a clip '
          'not mentioned is untouched', () async {
        final ids = await detect([10, 11, 12]);
        final goa = (await reels.create('Goa')).id;
        // In a reel, so the flagged ones keep their rows to look at.
        await repo.addClipsToReel(goa, ids);
        await repo.applyVerification(
          found: {ids[0]},
          gone: {ids[1]},
          otherVideo: {},
        );
        clock.advance(_minute);

        // The first one goes missing, the second comes back.
        await repo.applyVerification(
          found: {ids[1]},
          gone: {ids[0]},
          otherVideo: {},
        );

        final first = await rowOf(ids[0]);
        expect((first.missing, first.lastVerifiedAt), (true, _t0.add(_minute)));
        final second = await rowOf(ids[1]);
        expect(
          (second.missing, second.lastVerifiedAt),
          (false, _t0.add(_minute)),
        );
        final third = await rowOf(ids[2]);
        expect((third.missing, third.lastVerifiedAt), (false, null));
      });

      test('with nothing to apply an orphan clip is not swept', () async {
        final [a] = await detect([10]);
        await (db.delete(db.inbox)..where((i) => i.clipId.equals(a))).go();
        final before = await snapshot();

        expect(
          await repo.applyVerification(found: {}, gone: {}, otherVideo: {}),
          0,
        );

        expect(await snapshot(), before);
        expect(await clipIds(), [a]);
      });

      test('a failing step changes nothing', () async {
        final [_, gone, other] = await detect([10, 11, 12]);
        await db.customStatement(
          'CREATE TRIGGER no_delete BEFORE DELETE ON inbox '
          "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
        final before = await snapshot();

        await expectLater(
          repo.applyVerification(found: {}, gone: {gone}, otherVideo: {other}),
          throwsA(anything),
        );

        expect(await snapshot(), before);
      });

      test(
        'a clip in two sets is refused before anything is written',
        () async {
          final [a] = await detect([10]);
          final before = await snapshot();

          expect(
            () => repo.applyVerification(found: {a}, gone: {a}, otherVideo: {}),
            throwsArgumentError,
          );
          expect(
            () => repo.applyVerification(found: {}, gone: {a}, otherVideo: {a}),
            throwsArgumentError,
          );
          expect(await snapshot(), before);
        },
      );

      test('nothing to apply writes nothing', () async {
        await detect([10]);
        final before = await snapshot();

        expect(
          await repo.applyVerification(found: {}, gone: {}, otherVideo: {}),
          0,
        );
        expect(await snapshot(), before);
      });
    });

    group('clipsByIds and allClipIds', () {
      test('return the clips that exist, by id', () async {
        final [a, b] = await detect([10, 11]);
        await repo.saveDetected([pickerClip('content://p/1')]);
        final all = await repo.allClipIds();

        expect(all, hasLength(3));
        expect(all, containsAll([a, b]));
        final clips = await repo.clipsByIds([b, a, 999]);
        expect([for (final c in clips) c.id], [a, b]);
        expect(clips.first.mediaStoreId, 10);
        expect(await repo.clipsByIds([]), isEmpty);
      });

      test('clipsByIds works past one batch of ids', () async {
        final ids = await detect([for (var i = 1; i <= 1201; i++) i]);

        final clips = await repo.clipsByIds(ids);

        expect([for (final c in clips) c.id], ids);
        expect(await repo.allClipIds(), ids.toSet());
      });
    });

    group('mediaStoreClipsOn', () {
      test('excludes detached clips and other volumes', () async {
        final [a, b] = await detect([10, 11]);
        final [onCard] = await detect([10], volume: '1234-ABCD');
        await repo.saveDetected([pickerClip('content://p/1')]);
        await detachClips(db, {b}, at: clock.now());

        final clips = await repo.mediaStoreClipsOn('external_primary');

        expect(clips.map((c) => c.id), [a]);
        expect(clips.single.mediaStoreId, 10);
        expect(clips.single.volumeName, 'external_primary');
        expect((await repo.mediaStoreClipsOn('1234-ABCD')).map((c) => c.id), [
          onCard,
        ]);
      });

      test('excludes a picked clip that carries a volume and an id', () async {
        final [a] = await detect([10]);
        await pickerWithVolume(55);

        final clips = await repo.mediaStoreClipsOn('external_primary');

        expect(clips.map((c) => c.id), [a]);
      });

      test('an unknown volume is empty', () async {
        await detect([10]);

        expect(await repo.mediaStoreClipsOn('nope'), isEmpty);
        expect(await repo.mediaStoreClipsOn(''), isEmpty);
      });

      test('keeps clips flagged missing that still hold their id', () async {
        final [a] = await detect([10]);
        await flagClips(db, {a}, missing: true, at: clock.now());

        final clips = await repo.mediaStoreClipsOn('external_primary');

        expect(clips.single.missing, isTrue);
      });
    });

    group('applyRebuildMatch', () {
      test('swaps two ids without a unique clash', () async {
        final [a, b] = await detect([10, 20]);
        clock.advance(_minute);

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 20, b: 10}, lost: {}),
        );

        final rowA = await rowOf(a);
        final rowB = await rowOf(b);
        expect(rowA.mediaStoreId, 20);
        expect(rowB.mediaStoreId, 10);
        expect(rowA.missing, isFalse);
        expect(rowA.lastVerifiedAt, _t0.add(_minute));
        expect(rowB.lastVerifiedAt, _t0.add(_minute));
        // The fingerprint and the identity rest of the row are untouched.
        expect(rowA.displayName, 'VID_10.mp4');
        expect(rowA.volumeName, 'external_primary');
        expect(rowA.firstSeenAt, _t0);
      });

      test('a three-way rotation works', () async {
        final [a, b, c] = await detect([10, 20, 30]);

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 20, b: 30, c: 10}, lost: {}),
        );

        expect(
          [
            for (final id in [a, b, c]) (await rowOf(id)).mediaStoreId,
          ],
          [20, 30, 10],
        );
      });

      test("a remap to the clip's own current id works", () async {
        final [a, b] = await detect([10, 20]);
        clock.advance(_minute);

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 10}, lost: {b}),
        );

        final rowA = await rowOf(a);
        expect(rowA.mediaStoreId, 10);
        expect(rowA.lastVerifiedAt, _t0.add(_minute));
      });

      test('found clips are no longer missing', () async {
        final [a] = await detect([10]);
        await flagClips(db, {a}, missing: true, at: clock.now());

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 77}, lost: {}),
        );

        final row = await rowOf(a);
        expect(row.missing, isFalse);
        expect(row.mediaStoreId, 77);
      });

      test('a detached clip in remap stays detached and missing', () async {
        final [a, b] = await detect([10, 11]);
        await detachClips(db, {a}, at: clock.now());
        clock.advance(_minute);
        final before = await snapshot();

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 50, b: 51}, lost: {}),
        );

        final rowA = await rowOf(a);
        expect(rowA.mediaStoreId, -a);
        expect(rowA.missing, isTrue);
        expect(rowA.lastVerifiedAt, _t0, reason: 'not verified again');
        expect((await rowOf(b)).mediaStoreId, 51);
        expect(before, isNot(await snapshot()), reason: 'b did move');
      });

      test('a detached clip in lost is left as it is', () async {
        final [a] = await detect([10]);
        await detachClips(db, {a}, at: clock.now());
        clock.advance(_minute);
        final before = await snapshot();

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {}, lost: {a}),
        );

        expect(await snapshot(), before);
      });

      test('a picked clip with a volume and an id is left unchanged '
          'by remap and by lost', () async {
        final [a, b] = await detect([10, 11]);
        final picked = await pickerWithVolume(55);
        // Give both a reel, so the orphan sweep that follows a loss (Ruling
        // Y) keeps their rows to be looked at.
        final goa = (await reels.create('Goa')).id;
        await repo.addClipsToReel(goa, [picked, b]);
        clock.advance(_minute);
        final before = await snapshot();

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {picked: 60}, lost: {}),
        );
        expect(await snapshot(), before);

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {}, lost: {picked}),
        );
        expect(await snapshot(), before);

        // Mixed with real clips: only the real ones move.
        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 70, picked: 61}, lost: {b}),
        );
        final row = await rowOf(picked);
        expect(row.mediaStoreId, 55);
        expect(row.missing, isFalse);
        expect(row.lastVerifiedAt, isNull);
        expect((await rowOf(a)).mediaStoreId, 70);
        expect((await rowOf(b)).mediaStoreId, -b);
      });

      test(
        'a picked clip holding a new id is still an outside clash',
        () async {
          final [a] = await detect([10]);
          await pickerWithVolume(55);
          final before = await snapshot();

          await expectLater(
            repo.applyRebuildMatch(
              'external_primary',
              RebuildMatch(remap: {a: 55}, lost: {}),
            ),
            throwsStateError,
          );

          expect(await snapshot(), before);
        },
      );

      test('an empty match changes nothing', () async {
        final [a] = await detect([10]);
        await repo.tagClip(a, {(await reels.create('Goa')).id});
        await detect([11]);
        clock.advance(_minute);
        final before = await snapshot();

        await repo.applyRebuildMatch(
          'external_primary',
          const RebuildMatch(remap: {}, lost: {}),
        );

        expect(await snapshot(), before);
      });

      test('lost clips become missing with a negative id', () async {
        final [a, b, c] = await detect([10, 11, 12]);
        final goa = (await reels.create('Goa')).id;
        await repo.tagClip(a, {goa});
        await repo.skipClips([c]);
        clock.advance(_minute);

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {b: 99}, lost: {a, c}),
        );

        final rowA = await rowOf(a);
        expect(rowA.mediaStoreId, -a);
        expect(rowA.missing, isTrue);
        expect(rowA.lastVerifiedAt, _t0.add(_minute));
        expect(rowA.volumeName, 'external_primary');
        expect(rowA.displayName, 'VID_10.mp4', reason: 'the fingerprint stays');
        expect((await rowOf(b)).mediaStoreId, 99);
        // A lost clip in a reel stays there; one only in Skipped leaves it
        // and, in no other place, is swept (Ruling Y).
        expect(await reelIdsOf(a), {goa});
        expect((await inboxRows()).map((r) => (r.clipId, r.state)), [
          (b, InboxState.pending),
        ]);
        expect(await clipIds(), isNot(contains(c)));
      });

      test('a lost inbox-only clip leaves To tag and Skipped; a lost clip in a '
          'reel stays there, flagged (Ruling Y)', () async {
        final [inToTag, inSkipped, inReel, found] = await detect([
          10,
          11,
          12,
          13,
        ]);
        await repo.skipClips([inSkipped]);
        final goa = (await reels.create('Goa')).id;
        await repo.tagClip(inReel, {goa});

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {found: 99}, lost: {inToTag, inSkipped, inReel}),
        );

        final ids = [for (final c in await db.select(db.clips).get()) c.id];
        expect(ids, unorderedEquals([inReel, found]));
        expect((await inboxRows()).map((r) => r.clipId), [found]);
        final kept = await rowOf(inReel);
        expect((kept.mediaStoreId, kept.missing), (-inReel, true));
        expect(await reelIdsOf(inReel), {goa});
      });

      test('a failing list removal rolls the whole rebuild back', () async {
        final [a, b] = await detect([10, 11]);
        await db.customStatement(
          'CREATE TRIGGER no_delete BEFORE DELETE ON inbox '
          "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
        final before = await snapshot();

        await expectLater(
          repo.applyRebuildMatch(
            'external_primary',
            RebuildMatch(remap: {a: 20}, lost: {b}),
          ),
          throwsA(anything),
        );

        expect(await snapshot(), before);
      });

      test('a remap onto the old id of a lost clip works', () async {
        final [a, lost] = await detect([10, 20]);
        await repo.tagClip(lost, {(await reels.create('Goa')).id});

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 20}, lost: {lost}),
        );

        expect((await rowOf(a)).mediaStoreId, 20);
        expect((await rowOf(lost)).mediaStoreId, -lost);
      });

      test(
        "a detached clip's old id can be detected again as a new clip",
        () async {
          final [a] = await detect([10]);
          // In a reel, so the lost clip keeps its row (Ruling Y).
          final goa = (await reels.create('Goa')).id;
          await repo.tagClip(a, {goa});
          await repo.applyRebuildMatch(
            'external_primary',
            RebuildMatch(remap: {}, lost: {a}),
          );

          final again = await detect([10]);

          expect(again.single, isNot(a));
          expect(await clipIds(), [a, again.single]);
          expect((await rowOf(again.single)).mediaStoreId, 10);
          expect((await rowOf(a)).mediaStoreId, -a);
          expect(await reelIdsOf(a), {goa});
          expect((await inboxRows()).map((r) => r.clipId), [again.single]);
        },
      );

      test('fails atomically on an outside clash', () async {
        // A swaps with B, C moves to 30, and an outside clip D holds 30.
        final [a, b, c, d] = await detect([10, 20, 21, 30]);
        final goa = (await reels.create('Goa')).id;
        await repo.tagClip(b, {goa});
        await flagClips(db, {a}, missing: true, at: clock.now());
        clock.advance(_minute);
        final before = await snapshot();

        await expectLater(
          repo.applyRebuildMatch(
            'external_primary',
            RebuildMatch(remap: {a: 20, b: 10, c: 30}, lost: {}),
          ),
          throwsStateError,
        );

        // Every row of every table is as it was, not just the throw.
        expect(await snapshot(), before);
        expect((await rowOf(a)).mediaStoreId, 10);
        expect((await rowOf(d)).mediaStoreId, 30);
      });

      test('an outside clash with a clip that is not in the match', () async {
        final [a, outside] = await detect([10, 20]);

        await expectLater(
          repo.applyRebuildMatch(
            'external_primary',
            RebuildMatch(remap: {a: 20}, lost: {}),
          ),
          throwsStateError,
        );

        expect((await rowOf(a)).mediaStoreId, 10);
        expect((await rowOf(outside)).mediaStoreId, 20);
      });

      test('the same id on another volume is not a clash', () async {
        final [a] = await detect([10]);
        final [onCard] = await detect([20], volume: '1234-ABCD');

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 20}, lost: {}),
        );

        expect((await rowOf(a)).mediaStoreId, 20);
        expect((await rowOf(onCard)).mediaStoreId, 20);
      });

      test('clips on another volume or unknown ids are left alone', () async {
        final [a] = await detect([10]);
        final [onCard] = await detect([11], volume: '1234-ABCD');
        final [picked] = await repo.saveDetected([pickerClip('content://p/1')]);
        final before = await snapshot();

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {onCard: 50, 9999: 51}, lost: {picked, 8888}),
        );

        expect(await snapshot(), before);
        expect((await rowOf(a)).mediaStoreId, 10);
      });

      test(
        'a clip in both remap and lost throws and changes nothing',
        () async {
          final [a, b] = await detect([10, 11]);
          final before = await snapshot();

          await expectLater(
            repo.applyRebuildMatch(
              'external_primary',
              RebuildMatch(remap: {a: 50, b: 51}, lost: {a}),
            ),
            throwsArgumentError,
          );

          expect(await snapshot(), before);
        },
      );

      test('two clips mapped to one id throws and changes nothing', () async {
        final [a, b] = await detect([10, 11]);
        final before = await snapshot();

        await expectLater(
          repo.applyRebuildMatch(
            'external_primary',
            RebuildMatch(remap: {a: 50, b: 50}, lost: {}),
          ),
          throwsArgumentError,
        );

        expect(await snapshot(), before);
      });

      test('a target that is not a MediaStore id throws', () async {
        final [a] = await detect([10]);
        final before = await snapshot();

        for (final target in [0, -1, -a]) {
          await expectLater(
            repo.applyRebuildMatch(
              'external_primary',
              RebuildMatch(remap: {a: target}, lost: {}),
            ),
            throwsArgumentError,
            reason: 'target $target',
          );
        }

        expect(await snapshot(), before);
      });

      test('logs counts only', () async {
        final records = <LogRecord>[];
        final sub = Logger.root.onRecord.listen(records.add);
        addTearDown(sub.cancel);
        final [a, b] = await detect([10, 11]);

        await repo.applyRebuildMatch(
          'external_primary',
          RebuildMatch(remap: {a: 50}, lost: {b}),
        );

        final lines = records.map((r) => r.message).join('\n');
        expect(lines, contains('1 found'));
        expect(lines, contains('1 lost'));
        expect(lines, isNot(contains('VID_')));
        expect(lines, isNot(contains('external_primary')));
      });
    });

    group('undoEarlierAdd', () {
      test(
        'removes exactly the added ids and keeps older To tag clips',
        () async {
          final [older1, older2] = await detect([10, 11]);
          final [added1, added2] = await detect([20, 21]);

          final removed = await repo.undoEarlierAdd({added1, added2});

          expect(removed, 2);
          expect(await clipIds(), [older1, older2]);
          expect((await inboxRows()).map((r) => r.clipId), [older1, older2]);
        },
      );

      test(
        'a clip tagged into a reel in between keeps its row and link',
        () async {
          final [added, tagged] = await detect([20, 21]);
          final goa = (await reels.create('Goa')).id;
          await repo.tagClip(tagged, {goa});

          final removed = await repo.undoEarlierAdd({added, tagged});

          expect(removed, 1);
          expect(await clipIds(), [tagged]);
          expect(await reelIdsOf(tagged), {goa});
          expect(await inboxRows(), isEmpty);
        },
      );

      test('a clip skipped in between survives, still skipped', () async {
        final [added, skipped] = await detect([20, 21]);
        await repo.skipClips([skipped]);

        final removed = await repo.undoEarlierAdd({added, skipped});

        expect(removed, 1);
        expect(await clipIds(), [skipped]);
        final row = (await inboxRows()).single;
        expect(row.clipId, skipped);
        expect(row.state, InboxState.skipped);
      });

      test('an empty set returns 0 and changes nothing', () async {
        await detect([10]);
        final before = await snapshot();

        expect(await repo.undoEarlierAdd({}), 0);

        expect(await snapshot(), before);
      });

      test('undoing twice removes nothing the second time', () async {
        final [keep] = await detect([10]);
        final [added] = await detect([20]);

        expect(await repo.undoEarlierAdd({added}), 1);
        expect(await repo.undoEarlierAdd({added}), 0);

        expect(await clipIds(), [keep]);
      });

      test(
        'a pending inbox row beside a reel link is kept, with the link',
        () async {
          final [keep, both] = await detect([10, 20]);
          final goa = (await reels.create('Goa')).id;
          await repo.tagClip(both, {goa});
          // The database allows an inbox row beside a link (a backup drops
          // them, the repository never writes them): the clause "in no reel"
          // is what keeps this clip's row.
          await db
              .into(db.inbox)
              .insert(
                InboxCompanion.insert(
                  clipId: Value(both),
                  state: InboxState.pending,
                  addedAt: _t0,
                ),
              );

          final removed = await repo.undoEarlierAdd({both});

          expect(removed, 0);
          expect(await clipIds(), [keep, both]);
          expect(await reelIdsOf(both), {goa});
          expect((await inboxRows()).map((r) => r.clipId), contains(both));
        },
      );

      test('more ids than one batch (500) are all handled', () async {
        final [keep] = await detect([5]);
        final many = await detect([for (var i = 0; i < 1203; i++) 1000 + i]);
        expect(many.length, greaterThan(ClipsRepository.idBatch * 2));

        final removed = await repo.undoEarlierAdd(many.toSet());

        expect(removed, 1203);
        expect(await clipIds(), [keep]);
        expect((await inboxRows()).map((r) => r.clipId), [keep]);
      });

      test('unknown ids are ignored', () async {
        final [keep] = await detect([10]);

        expect(await repo.undoEarlierAdd({9999}), 0);

        expect(await clipIds(), [keep]);
      });

      test('the orphan sweep runs: an unlisted clip goes too', () async {
        final [added] = await detect([20]);
        // A clip in no reel and no list (only a hand-made backup can leave it).
        final orphan = await db
            .into(db.clips)
            .insert(
              ClipsCompanion.insert(
                source: ClipSource.mediaStore,
                mediaStoreId: const Value(50),
                volumeName: const Value('external_primary'),
                sizeBytes: 1,
                durationMs: 1,
                dateTakenUtc: _t0,
                displayName: 'x.mp4',
                width: 1,
                height: 1,
                mimeType: 'video/mp4',
                firstSeenAt: _t0,
              ),
            );

        final removed = await repo.undoEarlierAdd({added});

        expect(removed, 2);
        expect(await clipIds(), isNot(contains(orphan)));
      });
    });
  });

  group('addByHand (phase 7, D-113)', () {
    bool same(Clip stored, NewClip incoming) =>
        stored.fingerprint.sizeBytes == incoming.fingerprint.sizeBytes;

    test('to To tag: new clips pending at now, one transaction with their '
        'rows', () async {
      clock.advance(_minute);
      final add = await repo.addByHand([
        mediaStoreClip(10),
        pickerClip('content://p/1'),
      ], sameVideo: same);

      expect((add.added, add.alreadyThere), (2, 0));
      final rows = await inboxRows();
      expect(rows.map((r) => r.state).toSet(), {InboxState.pending});
      expect(rows.map((r) => r.addedAt).toSet(), {_t0.add(_minute)});
      expect(rows.map((r) => r.clipId).toSet(), (await clipIds()).toSet());
      expect(await db.select(db.clipReels).get(), isEmpty);
    });

    test('to a reel: a link, no inbox row, the reel touched', () async {
      final reel = await reels.create('Goa');
      clock.advance(_minute);

      final add = await repo.addByHand(
        [mediaStoreClip(10)],
        reelId: reel.id,
        sameVideo: same,
      );

      expect(add.added, 1);
      final [id] = await clipIds();
      expect(await reelIdsOf(id), {reel.id});
      expect(await inboxRows(), isEmpty);
      expect(await updatedAt(reel.id), _t0.add(_minute));
    });

    test('a reel that does not exist: StateError, nothing saved', () async {
      await expectLater(
        repo.addByHand([mediaStoreClip(10)], reelId: 404, sameVideo: same),
        throwsStateError,
      );
      expect(await clipIds(), isEmpty);
    });

    test('a known clip that is another video is detached in the same '
        'transaction as the insert', () async {
      final [old] = await repo.saveDetected([mediaStoreClip(10)]);
      final other = mediaStoreClip(10).copyWith(
        fingerprint: mediaStoreClip(10).fingerprint.copyWith(sizeBytes: 9),
      );

      final add = await repo.addByHand([other], sameVideo: same);

      expect(add.added, 1);
      final ids = await clipIds();
      expect(ids, isNot(contains(old)), reason: 'detached, only in To tag');
      final row = await db.select(db.clips).getSingle();
      expect((row.mediaStoreId, row.sizeBytes), (10, 9));
    });

    for (final toReel in [false, true]) {
      test('a known clip with no place (a backup can leave one) gets its '
          'place, ${toReel ? 'in the reel' : 'in To tag'}, and is not '
          'reported already there', () async {
        final reel = await reels.create('Goa');
        final [orphan] = await repo.saveDetected([mediaStoreClip(10)]);
        await db.delete(db.inbox).go();
        expect(await inboxRows(), isEmpty);
        expect(await reelIdsOf(orphan), isEmpty);
        clock.advance(_minute);

        final add = await repo.addByHand(
          [mediaStoreClip(10)],
          reelId: toReel ? reel.id : null,
          sameVideo: same,
        );

        expect((add.added, add.alreadyThere), (1, 0));
        expect(await clipIds(), [orphan], reason: 'the same clip, no copy');
        if (toReel) {
          expect(await reelIdsOf(orphan), {reel.id});
          expect(await inboxRows(), isEmpty);
        } else {
          final [row] = await inboxRows();
          expect((row.clipId, row.state), (orphan, InboxState.pending));
          expect(row.addedAt, _t0.add(_minute));
        }

        // Undo takes the place away again, so the sweep removes the clip.
        await repo.undoHandAdd(add.undo);

        expect(await clipIds(), isEmpty);
      });
    }

    test('undoHandAdd removes the new clips and is idempotent', () async {
      final [keep] = await repo.saveDetected([mediaStoreClip(5)]);
      final add = await repo.addByHand([
        mediaStoreClip(5),
        mediaStoreClip(10),
      ], sameVideo: same);
      expect((add.added, add.alreadyThere), (1, 1));

      await repo.undoHandAdd(add.undo);
      await repo.undoHandAdd(add.undo);

      expect(await clipIds(), [keep]);
    });

    test('placesOf: inbox state and reels per number, attached and not '
        'missing only, in batches', () async {
      final reel = await reels.create('Goa');
      final [pending, skipped, tagged, missing] = await repo.saveDetected([
        mediaStoreClip(1),
        mediaStoreClip(2),
        mediaStoreClip(3),
        mediaStoreClip(4),
      ]);
      await repo.skipClips([skipped]);
      await repo.tagClip(tagged, {reel.id});
      await repo.tagClip(missing, {reel.id});
      await flagClips(db, {missing}, missing: true, at: _t0);
      final many = [
        for (var i = 0; i < ClipsRepository.idBatch + 3; i++) 9000 + i,
      ];

      final places = await repo.placesOf('external_primary', [
        1,
        2,
        3,
        4,
        77,
        ...many,
      ]);

      expect(places.keys.toSet(), {1, 2, 3});
      expect(places[1]!.inbox, InboxState.pending);
      expect(places[1]!.reelIds, isEmpty);
      expect(places[2]!.inbox, InboxState.skipped);
      expect(places[3]!.inbox, isNull);
      expect(places[3]!.reelIds, {reel.id});
      expect(pending, isNot(skipped));
      expect(await repo.placesOf('other_volume', [1, 2, 3]), isEmpty);
    });

    group('a sweep while clips are being added cannot delete them (R6b)', () {
      test('to To tag', () async {
        final sweeping = _SweepingClock(_t0, db)..arm();

        await ClipsRepository(
          db,
          sweeping,
        ).addByHand([mediaStoreClip(10)], sameVideo: same);

        expect(sweeping.sweep, isNotNull, reason: 'the sweep was started');
        expect(await sweeping.sweep, 0);
        expect(await clipIds(), hasLength(1));
        expect(await inboxRows(), hasLength(1));
      });

      test('to a reel', () async {
        final reel = await reels.create('Goa');
        final sweeping = _SweepingClock(_t0, db)..arm();

        await ClipsRepository(db, sweeping).addByHand(
          [mediaStoreClip(10), pickerClip('content://p/1')],
          reelId: reel.id,
          sameVideo: same,
        );

        expect(sweeping.sweep, isNotNull, reason: 'the sweep was started');
        expect(await sweeping.sweep, 0);
        expect(await clipIds(), hasLength(2));
      });

      test(
        'undo and a reel delete at once: the undo removes only its clip',
        () async {
          final goa = await reels.create('Goa');
          final paris = await reels.create('Paris');
          final add = await repo.addByHand(
            [mediaStoreClip(10)],
            reelId: goa.id,
            sameVideo: same,
          );
          await repo.addClipsToReel(paris.id, await clipIds());
          final [other] = await repo.saveDetected([mediaStoreClip(11)]);

          await (repo.undoHandAdd(add.undo), reels.delete(paris.id)).wait;

          expect(await clipIds(), [other]);
        },
      );
    });
  });

  group('watching', () {
    test(
      'watchFirstShowableClip is the lowest-id clip with a picture',
      () async {
        expect(await repo.watchFirstShowableClip().first, isNull);

        final reel = await reels.create('Goa');
        final picked = await repo.addNewClipsToReel(reel.id, [
          pickerClip('content://p/1'),
        ]);
        // A missing picked clip has no picture: it is not offered.
        await flagClips(db, picked.toSet(), missing: true, at: clock.now());
        expect(await repo.watchFirstShowableClip().first, isNull);

        final ids = await repo.saveDetected([
          mediaStoreClip(10),
          mediaStoreClip(11),
        ]);
        expect(picked, isNotEmpty);
        expect((await repo.watchFirstShowableClip().first)!.id, ids[0]);
      },
    );

    test('watchFirstShowableClip offers a picked clip that is not missing '
        '(Phase 7: the Shooting mode backdrop)', () async {
      final reel = await reels.create('Goa');
      final picked = await repo.addNewClipsToReel(reel.id, [
        pickerClip('content://p/1'),
      ]);

      final shown = await repo.watchFirstShowableClip().first;

      expect(shown?.id, picked.single);
      expect(shown?.source, ClipSource.picker);
    });

    test('watchFirstShowableClip skips a picked clip with an empty address '
        '(it has no picture to ask for)', () async {
      final reel = await reels.create('Goa');
      await repo.addNewClipsToReel(reel.id, [pickerClip('')]);
      expect(await repo.watchFirstShowableClip().first, isNull);

      final ids = await repo.saveDetected([mediaStoreClip(10)]);

      expect((await repo.watchFirstShowableClip().first)!.id, ids.single);
    });

    test('watchFirstShowableClip skips a clip that is missing', () async {
      final ids = await repo.saveDetected([
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);
      await flagClips(db, {ids[0]}, missing: true, at: clock.now());
      await flagClips(db, {ids[1]}, missing: false, at: clock.now());

      expect((await repo.watchFirstShowableClip().first)!.id, ids[1]);

      await flagClips(db, {ids[1]}, missing: true, at: clock.now());
      expect(await repo.watchFirstShowableClip().first, isNull);
    });

    test(
      'watchFirstShowableClip finds a clip that is in a reel, too',
      () async {
        final ids = await repo.saveDetected([mediaStoreClip(10)]);
        await repo.tagClip(ids.single, {(await reels.create('Goa')).id});

        expect((await repo.watchFirstShowableClip().first)!.id, ids.single);
      },
    );

    test('watchFirstShowableClip follows changes', () async {
      final seen = <int?>[];
      final sub = repo.watchFirstShowableClip().listen((c) => seen.add(c?.id));
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);
      final ids = await repo.saveDetected([mediaStoreClip(10)]);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [null, ids.single]);
    });

    test('watchInbox is sorted by shooting time, ties by id', () async {
      final lateShot = _t0.add(const Duration(hours: 2));
      final earlyShot = _t0.subtract(const Duration(hours: 2));
      final ids = await repo.saveDetected([
        mediaStoreClip(10, shotAt: lateShot),
        mediaStoreClip(11, shotAt: _t0),
        mediaStoreClip(12, shotAt: earlyShot),
        mediaStoreClip(13, shotAt: _t0),
      ]);

      final pending = await repo.watchInbox(InboxState.pending).first;

      expect(pending.map((c) => c.id), [ids[2], ids[1], ids[3], ids[0]]);
    });

    test('watchInbox maps every field of the clip', () async {
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
      await flagClips(db, {id}, missing: false, at: clock.now());

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
      final ids = await repo.saveDetected([
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);
      await repo.skipClips([ids[1]]);

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

      final ids = await repo.saveDetected([
        mediaStoreClip(10),
        mediaStoreClip(11),
      ]);
      await pumpEventQueue();
      await repo.skipClips([ids[0]]);
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

      expect(clips.map((c) => c.clip.id), [ids[1], ids[2], ids[0]]);
    });

    test(
      'watchReelClips emits again when a clip is added or removed',
      () async {
        final reel = await reels.create('Goa');
        final seen = <List<int>>[];
        final sub = repo
            .watchReelClips(reel.id)
            .listen((clips) => seen.add([for (final c in clips) c.clip.id]));
        addTearDown(sub.cancel);
        await pumpEventQueue();

        final ids = await repo.addNewClipsToReel(reel.id, [mediaStoreClip(10)]);
        await pumpEventQueue();
        await repo.removeClipsFromReel(reel.id, ids);
        await pumpEventQueue();

        expect(seen, [<int>[], ids, <int>[]]);
      },
    );

    test('reel clips carry reelCount and addedAt', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final lisbon = await reels.create('Lisbon');
      final ids = await repo.addNewClipsToReel(goa.id, [
        mediaStoreClip(10, shotAt: _t0.add(_minute)),
        mediaStoreClip(11, shotAt: _t0),
      ]);
      clock.advance(_minute * 5);
      await repo.addClipsToReel(paris.id, [ids[0]]);
      clock.advance(_minute * 5);
      await repo.addClipsToReel(lisbon.id, [ids[0]]);

      final inGoa = await repo.watchReelClips(goa.id).first;
      final inParis = await repo.watchReelClips(paris.id).first;

      expect(
        [for (final c in inGoa) (c.clip.id, c.reelCount, c.addedAt)],
        [(ids[1], 1, _t0), (ids[0], 3, _t0)],
      );
      expect(
        [for (final c in inParis) (c.clip.id, c.reelCount, c.addedAt)],
        [(ids[0], 3, _t0.add(_minute * 5))],
      );
      expect(inGoa.last.clip, (await repo.clipsByIds([ids[0]])).single);
    });

    test('reelCount follows a link change', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await repo.addNewClipsToReel(goa.id, [
        mediaStoreClip(10),
      ])).single;
      final counts = <List<int>>[];
      final sub = repo
          .watchReelClips(goa.id)
          .listen((all) => counts.add([for (final c in all) c.reelCount]));
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await repo.addClipsToReel(paris.id, [id]);
      await pumpEventQueue();
      await repo.removeClipsFromReel(paris.id, [id]);
      await pumpEventQueue();

      expect(counts, [
        [1],
        [2],
        [1],
      ]);
    });

    test('watchReelIdsOf follows tag and Undo', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await repo.saveDetected([mediaStoreClip(10)])).single;
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
