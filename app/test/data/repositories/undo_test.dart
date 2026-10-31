import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/data/repositories/vn_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/models/vn_copy.dart';

import '../../support/clip_setup.dart';
import '../../support/fixed_clock.dart';
import '../../support/statement_log.dart';
import '../../support/test_database.dart';

// Undo records (D-84): every remove, move, add-to-reel and reel delete can be
// put back exactly, with the same ids, without a second row for one video.

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _minute = Duration(minutes: 1);

/// The part of a real clock's time that the database drops: `DateTime.now()`
/// has microseconds, the database keeps milliseconds. The test clock carries
/// it, so a record that held the in-memory time instead of the stored one
/// would not match its own rows (I-2 of the Phase 4 final review). Stored
/// times are still `_t0` plus whole minutes.
const Duration _subMillisecond = Duration(microseconds: 123);

late AppDatabase db;
late FixedClock clock;
late ClipsRepository clips;
late ReelsRepository reels;

/// A detected clip with MediaStore number [number], every optional field set.
NewClip shot(int number, {DateTime? at}) => NewClip.mediaStore(
  mediaStoreId: number,
  volumeName: 'external_primary',
  fingerprint: ClipFingerprint(
    sizeBytes: 1000 + number,
    durationMs: 4000 + number,
    dateTakenUtc: at ?? _t0.subtract(Duration(hours: number)),
    displayName: 'VID_$number.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  timeZoneId: 'Asia/Kolkata',
  generationAdded: 40 + number,
);

NewClip picked(String uri) => NewClip.picker(
  pickerUri: uri,
  fingerprint: ClipFingerprint(
    sizeBytes: 2000,
    durationMs: 8000,
    dateTakenUtc: _t0,
    displayName: 'friend.mp4',
  ),
  width: 720,
  height: 1280,
  mimeType: 'video/mp4',
);

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0.add(_subMillisecond));
    clips = ClipsRepository(db, clock);
    reels = ReelsRepository(db, clock);
  });

  Future<List<int>> clipIds() async =>
      (await clips.allClipIds()).toList()..sort();

  Future<Clip> clipById(int id) async => (await clips.clipsByIds([id])).single;

  Future<Set<int>> reelIdsOf(int clipId) => clips.watchReelIdsOf(clipId).first;

  Future<List<(int, int, DateTime)>> linksOf(int reelId) async => [
    for (final l
        in await (db.select(db.clipReels)
              ..where((l) => l.reelId.equals(reelId))
              ..orderBy([(l) => OrderingTerm.asc(l.clipId)]))
            .get())
      (l.clipId, l.reelId, l.addedAt),
  ];

  Future<Map<int, (InboxState, DateTime)>> inbox() async => {
    for (final row in await db.select(db.inbox).get())
      row.clipId: (row.state, row.addedAt),
  };

  Future<DateTime> updatedAt(int reelId) async =>
      (await reels.getById(reelId))!.updatedAt;

  /// Every row of every table that undo touches, to compare two states.
  Future<String> dump() async {
    String rows(List<Object> all) =>
        (all.map((r) => r.toString()).toList()..sort()).join('\n');
    return [
      rows(await db.select(db.reels).get()),
      rows(await db.select(db.clips).get()),
      rows(await db.select(db.clipReels).get()),
      rows(await db.select(db.inbox).get()),
      rows(await db.select(db.reelReferences).get()),
      rows(await db.select(db.vnSessions).get()),
      rows(await db.select(db.vnCopies).get()),
    ].join('\n---\n');
  }

  /// The warnings logged while [body] runs.
  Future<List<String>> warningsOf(Future<void> Function() body) async {
    final warnings = <String>[];
    final sub = Logger.root.onRecord
        .where((r) => r.level >= Level.WARNING)
        .listen((r) => warnings.add(r.message));
    try {
      await body();
    } finally {
      await sub.cancel();
    }
    return warnings;
  }

  group('remove', () {
    test(
      'undo remove restores an orphan-swept clip with its id and every field',
      () async {
        final goa = await reels.create('Goa');
        final paris = await reels.create('Paris');
        final [flagged, detached, shared] = await clips.addNewClipsToReel(
          goa.id,
          [shot(10), shot(11), shot(12)],
        );
        await clips.addClipsToReel(paris.id, [shared]);
        // Every optional field holds something: missing, verified, and one
        // clip detached (its number is -id, D-71).
        await flagClips(db, {flagged}, missing: true, at: _t0.add(_minute));
        await detachClips(db, {detached}, at: _t0.add(_minute * 2));
        final before = {
          for (final id in [flagged, detached, shared]) id: await clipById(id),
        };
        final reelClipsBefore = await clips.watchReelClips(goa.id).first;
        clock.advance(_minute * 10);

        final record = await clips.removeClipsFromReel(goa.id, [
          flagged,
          detached,
          shared,
        ]);

        expect(record.sweptClips.map((c) => c.id), [flagged, detached]);
        expect(record.sweptClips, [before[flagged], before[detached]]);
        expect(await clipIds(), [shared]);

        await clips.undo(record);

        for (final id in [flagged, detached, shared]) {
          expect(await clipById(id), before[id], reason: 'clip $id');
        }
        expect(await clips.watchReelClips(goa.id).first, reelClipsBefore);
        expect([
          for (final c in reelClipsBefore) (c.clip.id, c.reelCount),
        ], containsAll([(shared, 2), (flagged, 1), (detached, 1)]));
        // A restored id is not given out again.
        final next = (await clips.saveDetected([shot(99)])).single;
        expect(next, greaterThan(shared));
      },
    );

    test('undo remove restores addedAt and updatedAt', () async {
      final goa = await reels.create('Goa');
      final early = (await clips.addNewClipsToReel(goa.id, [shot(10)])).single;
      clock.advance(_minute * 5);
      final late = (await clips.addNewClipsToReel(goa.id, [shot(11)])).single;
      final linksBefore = await linksOf(goa.id);
      final updatedBefore = await updatedAt(goa.id);
      expect(updatedBefore, _t0.add(_minute * 5));
      clock.advance(_minute * 5);

      final record = await clips.removeClipsFromReel(goa.id, [early, late]);
      expect(await updatedAt(goa.id), _t0.add(_minute * 10));
      clock.advance(_minute);
      await clips.undo(record);

      expect(await linksOf(goa.id), linksBefore);
      expect(linksBefore.map((l) => l.$3), [_t0, _t0.add(_minute * 5)]);
      expect(await updatedAt(goa.id), updatedBefore);
    });

    test('undo keeps an updatedAt written after the remove', () async {
      final goa = await reels.create('Goa');
      final id = (await clips.addNewClipsToReel(goa.id, [shot(10)])).single;
      clock.advance(_minute);
      final record = await clips.removeClipsFromReel(goa.id, [id]);
      clock.advance(_minute);
      await reels.rename(goa.id, 'Goa trip');

      await clips.undo(record);

      expect(await reelIdsOf(id), {goa.id});
      expect(await updatedAt(goa.id), _t0.add(_minute * 2));
    });

    test(
      'undo remove links the existing clip when the video came back',
      () async {
        final goa = await reels.create('Goa');
        final [old, oldPicked] = await clips.addNewClipsToReel(goa.id, [
          shot(10),
          picked('content://media/picker/0/7'),
        ]);
        final record = await clips.removeClipsFromReel(goa.id, [
          old,
          oldPicked,
        ]);
        expect(await clipIds(), isEmpty);
        // Add earlier videos finds the same video again: a new row, in To
        // tag. A picked one comes back under its URI.
        final again = (await clips.saveDetected([shot(10)])).single;
        await db
            .into(db.inbox)
            .insert(
              InboxCompanion.insert(
                clipId: Value(
                  await db
                      .into(db.clips)
                      .insert(
                        ClipsCompanion.insert(
                          source: ClipSource.picker,
                          pickerUri: const Value('content://media/picker/0/7'),
                          sizeBytes: 2000,
                          durationMs: 8000,
                          dateTakenUtc: _t0,
                          displayName: 'friend.mp4',
                          width: 720,
                          height: 1280,
                          mimeType: 'video/mp4',
                          firstSeenAt: _t0.add(_minute),
                        ),
                      ),
                ),
                state: InboxState.skipped,
                addedAt: _t0.add(_minute),
              ),
            );
        final pickedAgain = (await clipIds()).last;
        expect(again, isNot(old));

        await clips.undo(record);

        // No second row for either video: the new rows are linked instead,
        // with the old addedAt, and they leave To tag and Skipped.
        expect(await clipIds(), [again, pickedAgain]);
        expect(await linksOf(goa.id), [
          (again, goa.id, _t0),
          (pickedAgain, goa.id, _t0),
        ]);
        expect(await inbox(), isEmpty);
      },
    );

    test('undo remove twice changes nothing', () async {
      final goa = await reels.create('Goa');
      final ids = await clips.addNewClipsToReel(goa.id, [shot(10), shot(11)]);
      final first = await clips.removeClipsFromReel(goa.id, ids);
      await clips.undo(first);
      final restored = await dump();

      await clips.undo(first);
      expect(await dump(), restored);

      // Removed again: the first record must not bring them back a second
      // time; only the new record does.
      final second = await clips.removeClipsFromReel(goa.id, ids);
      final removed = await dump();
      await clips.undo(first);
      expect(await dump(), removed);
      await clips.undo(second);
      expect(await dump(), restored);
    });

    test('two undos at once restore once', () async {
      final goa = await reels.create('Goa');
      final ids = await clips.addNewClipsToReel(goa.id, [shot(10), shot(11)]);
      final before = await dump();
      final record = await clips.removeClipsFromReel(goa.id, ids);

      await Future.wait([clips.undo(record), reels.undo(record)]);

      expect(await dump(), before);
    });

    test('undo remove after its reel was deleted restores nothing and does not '
        'throw', () async {
      final goa = await reels.create('Goa');
      final ids = await clips.addNewClipsToReel(goa.id, [shot(10)]);
      final record = await clips.removeClipsFromReel(goa.id, ids);
      await reels.delete(goa.id);
      final before = await dump();

      final warnings = await warningsOf(() => clips.undo(record));

      expect(await dump(), before);
      expect(await clipIds(), isEmpty);
      expect(warnings, ['Undo remove: reel ${goa.id} is gone']);
    });

    test(
      'undo remove never links a different video that took the number',
      () async {
        final goa = await reels.create('Goa');
        final [id, pickedId] = await clips.addNewClipsToReel(goa.id, [
          shot(10),
          picked('content://media/picker/0/7'),
        ]);
        final before = await clipById(id);
        final record = await clips.removeClipsFromReel(goa.id, [id, pickedId]);
        // After a rebuild, number 10 is another video (same date, other size
        // and length); the picker URI too.
        final other = (await clips.saveDetected([
          NewClip.mediaStore(
            mediaStoreId: 10,
            volumeName: 'external_primary',
            fingerprint: ClipFingerprint(
              sizeBytes: 999999,
              durationMs: 1234,
              dateTakenUtc: before.fingerprint.dateTakenUtc,
              displayName: 'VID_10.mp4',
            ),
            width: 1080,
            height: 1920,
            mimeType: 'video/mp4',
          ),
        ])).single;
        final otherPicked = (await clips.addNewClipsToReel(
          (await reels.create('Paris')).id,
          [
            NewClip.picker(
              pickerUri: 'content://media/picker/0/7',
              fingerprint: ClipFingerprint(
                sizeBytes: 5,
                durationMs: 5,
                dateTakenUtc: _t0,
                displayName: 'friend.mp4',
              ),
              width: 1,
              height: 1,
              mimeType: 'video/mp4',
            ),
          ],
        )).single;
        clock.advance(_minute);

        final warnings = await warningsOf(() => clips.undo(record));

        // The clip is back with its id, detached and missing (D-71): the
        // missing tile, never the other video.
        expect(
          await clipById(id),
          before.copyWith(
            mediaStoreId: -id,
            missing: true,
            lastVerifiedAt: _t0.add(_minute),
          ),
        );
        expect(await linksOf(goa.id), [(id, goa.id, _t0)]);
        expect(await reelIdsOf(other), isEmpty);
        expect(await inbox(), {other: (InboxState.pending, _t0)});
        // The picked clip has nothing else to be found by: left out.
        expect(await reelIdsOf(otherPicked), isNot(contains(goa.id)));
        expect(await clipIds(), [id, other, otherPicked]);
        final pickedWarning =
            'Undo: clip $pickedId: clip $otherPicked is another video with '
            'its identity, not restored';
        expect(warnings, [pickedWarning, 'Undo: 1 links could not come back']);
      },
    );

    test('undo never links a different clip that holds the old id', () async {
      final goa = await reels.create('Goa');
      final id = (await clips.addNewClipsToReel(goa.id, [shot(10)])).single;
      final record = await clips.removeClipsFromReel(goa.id, [id]);
      // Only a backup import can do this: another video under the old id.
      await db
          .into(db.clips)
          .insert(
            ClipsCompanion.insert(
              id: Value(id),
              source: ClipSource.mediaStore,
              mediaStoreId: const Value(500),
              volumeName: const Value('external_primary'),
              sizeBytes: 77,
              durationMs: 77,
              dateTakenUtc: _t0,
              displayName: 'other.mp4',
              width: 1,
              height: 1,
              mimeType: 'video/mp4',
              firstSeenAt: _t0,
            ),
          );
      await db
          .into(db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(id),
              state: InboxState.pending,
              addedAt: _t0,
            ),
          );

      final warnings = await warningsOf(() => clips.undo(record));

      expect(await linksOf(goa.id), isEmpty);
      expect((await clipById(id)).mediaStoreId, 500);
      expect(
        warnings,
        contains(
          'Undo: clip id $id holds another clip, not '
          'restored',
        ),
      );
    });

    test('a remove that removed nothing has an empty record', () async {
      final goa = await reels.create('Goa');
      final record = await clips.removeClipsFromReel(goa.id, [42]);
      final before = await dump();

      expect(record.isEmpty, isTrue);
      expect(record.touch, isNull);
      await clips.undo(record);
      expect(await dump(), before);
    });
  });

  group('move', () {
    test('move keeps the clip when it is only in the source', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await clips.addNewClipsToReel(goa.id, [shot(10)])).single;
      final before = await clipById(id);
      clock.advance(_minute);

      final record = await clips.moveClips(goa.id, paris.id, [id]);

      expect(await clipById(id), before);
      expect(await reelIdsOf(id), {paris.id});
      expect(await linksOf(paris.id), [(id, paris.id, _t0.add(_minute))]);
      expect(await updatedAt(goa.id), _t0.add(_minute));
      expect(await updatedAt(paris.id), _t0.add(_minute));
      expect(record.createdLinks, [
        ClipLink(clipId: id, reelId: paris.id, addedAt: _t0.add(_minute)),
      ]);
      expect(record.removedLinks, [
        ClipLink(clipId: id, reelId: goa.id, addedAt: _t0),
      ]);
    });

    test('move to a reel that already has the clip', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await clips.addNewClipsToReel(paris.id, [shot(10)])).single;
      clock.advance(_minute);
      await clips.addClipsToReel(goa.id, [id]);
      clock.advance(_minute);

      final record = await clips.moveClips(goa.id, paris.id, [id]);

      expect(await reelIdsOf(id), {paris.id});
      // The target's link was there first and keeps its addedAt; the target
      // did not change, so it does not move up.
      expect(await linksOf(paris.id), [(id, paris.id, _t0)]);
      expect(await updatedAt(paris.id), _t0);
      expect(await updatedAt(goa.id), _t0.add(_minute * 2));
      expect(record.createdLinks, isEmpty);
      expect(record.removedLinks, hasLength(1));
    });

    test('undo move deletes only the created links', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final [moved, both] = await clips.addNewClipsToReel(goa.id, [
        shot(10),
        shot(11),
      ]);
      clock.advance(_minute);
      await clips.addClipsToReel(paris.id, [both]);
      final goaBefore = await linksOf(goa.id);
      final parisBefore = await linksOf(paris.id);
      final updatedBefore = (
        await updatedAt(goa.id),
        await updatedAt(paris.id),
      );
      final clipsBefore = await dump();
      // No time passes: Paris's own link to `both` has the same addedAt as
      // the links the move creates, so only the record tells them apart.

      final record = await clips.moveClips(goa.id, paris.id, [moved, both]);
      expect(record.createdLinks.map((l) => l.clipId), [moved]);
      clock.advance(_minute);
      await clips.undo(record);

      expect(await linksOf(goa.id), goaBefore);
      expect(await linksOf(paris.id), parisBefore);
      expect(await reelIdsOf(both), {goa.id, paris.id});
      expect((
        await updatedAt(goa.id),
        await updatedAt(paris.id),
      ), updatedBefore);
      expect(await dump(), clipsBefore);
    });

    test('move to the same reel throws', () async {
      final goa = await reels.create('Goa');
      final id = (await clips.addNewClipsToReel(goa.id, [shot(10)])).single;
      final before = await dump();

      await expectLater(
        clips.moveClips(goa.id, goa.id, [id]),
        throwsArgumentError,
      );
      expect(await dump(), before);
    });

    test(
      'move from or to an unknown reel throws and changes nothing',
      () async {
        final goa = await reels.create('Goa');
        final id = (await clips.addNewClipsToReel(goa.id, [shot(10)])).single;
        final before = await dump();

        await expectLater(clips.moveClips(goa.id, 99, [id]), throwsStateError);
        await expectLater(clips.moveClips(99, goa.id, [id]), throwsStateError);
        expect(await dump(), before);
      },
    );

    test('move ignores clips the source does not have', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final lisbon = await reels.create('Lisbon');
      final id = (await clips.addNewClipsToReel(lisbon.id, [shot(10)])).single;
      final before = await dump();

      final record = await clips.moveClips(goa.id, paris.id, [id, 99]);

      expect(record.isEmpty, isTrue);
      expect(await dump(), before);
    });

    test(
      'undo move after the source reel was deleted keeps the clip',
      () async {
        final goa = await reels.create('Goa');
        final paris = await reels.create('Paris');
        final id = (await clips.addNewClipsToReel(goa.id, [shot(10)])).single;
        final record = await clips.moveClips(goa.id, paris.id, [id]);
        await reels.delete(goa.id);

        final warnings = await warningsOf(() => clips.undo(record));

        expect(await clipIds(), [id]);
        expect(await reelIdsOf(id), {paris.id});
        expect(warnings, contains('Undo move: reel ${goa.id} is gone'));
      },
    );
  });

  group('add', () {
    test('add undo restores inbox rows', () async {
      final goa = await reels.create('Goa');
      final [pending, skipped] = await clips.saveDetected([shot(10), shot(11)]);
      clock.advance(_minute);
      final inReel = (await clips.addNewClipsToReel(goa.id, [shot(12)])).single;
      await clips.skip([skipped]);
      final inboxBefore = await inbox();
      final linksBefore = await linksOf(goa.id);
      final updatedBefore = await updatedAt(goa.id);
      clock.advance(_minute);

      final record = await clips.addClipsToReel(goa.id, [
        pending,
        skipped,
        inReel,
      ]);
      expect(await inbox(), isEmpty);
      expect(record.createdLinks.map((l) => l.clipId), [pending, skipped]);
      clock.advance(_minute);
      await clips.undo(record);

      expect(await inbox(), inboxBefore);
      expect(inboxBefore, {
        pending: (InboxState.pending, _t0),
        skipped: (InboxState.skipped, _t0),
      });
      expect(await linksOf(goa.id), linksBefore);
      expect(await updatedAt(goa.id), updatedBefore);
      expect(await clipIds(), [pending, skipped, inReel]);
    });

    test('add undo never deletes a clip: one whose only place is the added '
        'link keeps it', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await clips.addNewClipsToReel(goa.id, [shot(10)])).single;
      final before = await clipById(id);
      clock.advance(_minute);
      final record = await clips.addClipsToReel(paris.id, [id]);
      // Removed from Goa meanwhile: Paris is its only place now.
      await clips.removeClipsFromReel(goa.id, [id]);
      expect(await clipIds(), [id]);

      final warnings = await warningsOf(() => clips.undo(record));

      expect(await clipById(id), before);
      expect(await linksOf(paris.id), [(id, paris.id, _t0.add(_minute))]);
      expect(
        warnings,
        contains('Undo: kept 1 links of clips with no other place'),
      );
    });

    test('add undo puts a clip back in To tag before its link goes', () async {
      final goa = await reels.create('Goa');
      final id = (await clips.saveDetected([shot(10)])).single;
      final record = await clips.addClipsToReel(goa.id, [id]);

      await clips.undo(record);

      expect(await clipIds(), [id]);
      expect(await linksOf(goa.id), isEmpty);
      expect(await inbox(), {id: (InboxState.pending, _t0)});
    });

    test(
      'add undo puts a To tag clip back with a real clock (microseconds)',
      () async {
        // The reviewer's probe: the clock is a minute and 123 µs on, as
        // `DateTime.now()` would be, and the clip comes from To tag.
        final goa = await reels.create('Goa');
        final id = (await clips.saveDetected([shot(10)])).single;
        clock.advance(_minute + _subMillisecond);
        final record = await clips.addClipsToReel(goa.id, [id]);
        expect(await inbox(), isEmpty);
        expect(await linksOf(goa.id), [(id, goa.id, _t0.add(_minute))]);
        // The record holds the time as the database stores it.
        expect(record.createdLinks.single.addedAt, _t0.add(_minute));
        expect(record.touch!.after, _t0.add(_minute));

        await clips.undo(record);

        expect(await inbox(), {id: (InboxState.pending, _t0)});
        expect(await linksOf(goa.id), isEmpty);
        expect(await clipIds(), [id]);
      },
    );

    test('add undo leaves a clip put in another reel since', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await clips.saveDetected([shot(10)])).single;
      final record = await clips.addClipsToReel(goa.id, [id]);
      await clips.addClipsToReel(paris.id, [id]);

      await clips.undo(record);

      expect(await reelIdsOf(id), {paris.id});
      expect(await inbox(), isEmpty);
    });

    test('add undo after its reel was deleted restores nothing', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final id = (await clips.addNewClipsToReel(paris.id, [shot(10)])).single;
      final record = await clips.addClipsToReel(goa.id, [id]);
      await reels.delete(goa.id);
      final before = await dump();

      final warnings = await warningsOf(() => clips.undo(record));

      expect(await dump(), before);
      expect(warnings, ['Undo add: reel ${goa.id} is gone']);
    });
  });

  group('delete', () {
    test('delete undo restores the reel with its id, links, references and '
        'swept clips', () async {
      final goa = await reels.create('Goa', description: 'Beach week');
      final paris = await reels.create('Paris');
      await reels.setStatus(goa.id, ReelStatus.ready);
      final [only, shared] = await clips.addNewClipsToReel(goa.id, [
        shot(10),
        shot(11),
      ]);
      clock.advance(_minute);
      await clips.addClipsToReel(paris.id, [shared]);
      final references = ReferencesRepository(db, clock);
      await references.add(
        goa.id,
        'https://www.instagram.com/reel/abc',
        label: 'Hook',
      );
      await references.add(goa.id, 'https://youtu.be/xyz');
      final vn = VnRepository(db, clock);
      await vn.startSession(goa.id, 'Goa');
      await vn.addCopy(
        VnCopy(
          reelId: goa.id,
          clipId: only,
          copyMediaStoreId: 900,
          fileName: 'copy.mp4',
          sizeBytes: 1010,
        ),
      );
      clock.advance(_minute);
      final before = await dump();

      final record = await reels.delete(goa.id);

      expect(await reels.getById(goa.id), isNull);
      expect(await clipIds(), [shared]);
      expect(record.sweptClips.map((c) => c.id), [only]);
      expect(record.references, hasLength(2));
      expect(record.vnCopies, hasLength(1));

      clock.advance(_minute);
      await reels.undo(record);

      expect(await dump(), before);
      expect((await reels.getById(goa.id))!.description, 'Beach week');
    });

    test('undo after the reel was deleted again restores nothing and does not '
        'throw', () async {
      final goa = await reels.create('Goa');
      final ids = await clips.addNewClipsToReel(goa.id, [shot(10)]);
      final first = await reels.delete(goa.id);
      await reels.undo(first);
      final second = await reels.delete(goa.id);
      final deletedAgain = await dump();

      await reels.undo(first);

      expect(await dump(), deletedAgain);
      expect(await reels.getById(goa.id), isNull);
      // The newer record still works.
      await reels.undo(second);
      expect(await reels.getById(goa.id), isNotNull);
      expect(await linksOf(goa.id), [(ids.single, goa.id, _t0)]);
    });

    test(
      'undo delete restores even when the name was reused meanwhile',
      () async {
        final goa = await reels.create('Goa');
        final record = await reels.delete(goa.id);
        final reused = await reels.create('GOA');

        await reels.undo(record);

        expect(await reels.getById(goa.id), goa);
        expect(await reels.getById(reused.id), reused);
      },
    );

    test('undo delete keeps every VN copy row, also one whose clip cannot come '
        'back (D-54)', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final [kept, lost] = await clips.addNewClipsToReel(goa.id, [
        shot(10),
        picked('content://picker/1'),
      ]);
      final vn = VnRepository(db, clock);
      await vn.startSession(goa.id, 'Goa');
      for (final (clipId, number) in [(kept, 900), (lost, 901)]) {
        await vn.addCopy(
          VnCopy(
            reelId: goa.id,
            clipId: clipId,
            copyMediaStoreId: number,
            fileName: 'copy$number.mp4',
            sizeBytes: 1000,
          ),
        );
      }
      final record = await reels.delete(goa.id);
      expect(record.sweptClips.map((c) => c.id), [kept, lost]);
      // The picker address now belongs to another video (another
      // fingerprint), so the picked clip cannot come back (D-84 point 7).
      final other = (await clips.addNewClipsToReel(paris.id, [
        NewClip.picker(
          pickerUri: 'content://picker/1',
          fingerprint: ClipFingerprint(
            sizeBytes: 3000,
            durationMs: 9000,
            dateTakenUtc: _t0.add(_minute),
            displayName: 'other.mp4',
          ),
          width: 720,
          height: 1280,
          mimeType: 'video/mp4',
        ),
      ])).single;

      final warnings = await warningsOf(() => reels.undo(record));

      expect(await reels.getById(goa.id), isNotNull);
      expect(await reelIdsOf(kept), {goa.id});
      expect(await reelIdsOf(other), {paris.id});
      expect(await clipIds(), [kept, other]);
      // Both copy rows are back: they are the app's only record of the copy
      // files (D-54). The lost clip's row keeps its old id, which no clip
      // holds and none ever will (ids are never reused), so it never
      // points at another clip.
      expect([
        for (final c in await db.select(db.vnCopies).get())
          (c.clipId, c.copyMediaStoreId),
      ], unorderedEquals([(kept, 900), (lost, 901)]));
      expect(other, isNot(lost));
      expect(await clips.clipsByIds([lost]), isEmpty);
      expect(await db.select(db.vnSessions).get(), hasLength(1));
      expect(warnings.where((w) => w.contains('VN copy')), isEmpty);
    });

    test('an unknown id gives a record that restores nothing', () async {
      await reels.create('Goa');
      final record = await reels.delete(99);
      final before = await dump();

      expect(record.isEmpty, isTrue);
      await reels.undo(record);
      expect(await dump(), before);
    });
  });

  group('atomicity', () {
    late StatementLog log;

    setUp(() {
      log = StatementLog();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      db = loggedTestDatabase(log);
      addTearDown(db.close);
      clips = ClipsRepository(db, clock);
      reels = ReelsRepository(db, clock);
    });

    test('a failing step rolls back everything', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final ids = await clips.addNewClipsToReel(goa.id, [shot(10), shot(11)]);
      clock.advance(_minute);
      final start = await dump();

      // Remove: the links are deleted and the reel touched, then the sweep
      // fails.
      log.failWhen = (sql) => sql.startsWith('DELETE FROM "clips"');
      await expectLater(
        clips.removeClipsFromReel(goa.id, ids),
        throwsA(isA<StateError>()),
      );
      expect(await dump(), start);

      // Move: the target links are inserted, then removing the source fails.
      log.failWhen = (sql) => sql.startsWith('DELETE FROM "clip_reels"');
      await expectLater(
        clips.moveClips(goa.id, paris.id, ids),
        throwsA(isA<StateError>()),
      );
      expect(await dump(), start);

      // Delete: the reel goes, then the sweep fails.
      log.failWhen = (sql) => sql.startsWith('DELETE FROM "clips"');
      await expectLater(reels.delete(goa.id), throwsA(isA<StateError>()));
      expect(await dump(), start);

      // Undo: the first clip comes back, then its link fails. Nothing stays,
      // and the record can be undone again.
      final record = await clips.removeClipsFromReel(goa.id, ids);
      final removed = await dump();
      log.failWhen = (sql) => sql.startsWith('INSERT INTO "clip_reels"');
      await expectLater(clips.undo(record), throwsA(isA<StateError>()));
      expect(await dump(), removed);
      await clips.undo(record);
      expect(await dump(), start);
    });

    test('undoing several records is one transaction: a failure part way '
        'leaves nothing undone, and the retry works', () async {
      final goa = await reels.create('Goa');
      final paris = await reels.create('Paris');
      final ids = await clips.saveDetected([shot(10), shot(11)]);
      await clips.skip([ids.last]);
      clock.advance(_minute);
      final start = await dump();
      final records = await clips.addClipsToReels({goa.id, paris.id}, ids);
      final added = await dump();

      // Last to first: Paris's links go, then Goa's first step (its To tag
      // and Skipped rows back) fails.
      log.failWhen = (sql) => sql.startsWith('INSERT INTO "inbox"');
      await expectLater(clips.undoAll(records), throwsA(isA<StateError>()));
      expect(await dump(), added);

      // Nothing was marked undone, so the same list can be undone again.
      await reels.undoAll(records);
      expect(await dump(), start);
      // And once only.
      await clips.undoAll(records);
      expect(await dump(), start);
    });
  });
}
