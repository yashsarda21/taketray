import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/housekeeping.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';

import '../../support/clip_setup.dart';
import '../../support/fixed_clock.dart';
import '../../support/statement_log.dart';
import '../../support/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);

late AppDatabase db;
late FixedClock clock;
late ReelsRepository repo;

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    repo = ReelsRepository(db, clock);
  });

  Future<int> insertClip(int mediaStoreId) => db
      .into(db.clips)
      .insert(
        ClipsCompanion.insert(
          source: ClipSource.mediaStore,
          mediaStoreId: Value(mediaStoreId),
          volumeName: const Value('external_primary'),
          sizeBytes: 1000,
          durationMs: 5000,
          dateTakenUtc: _t0,
          displayName: 'VID_$mediaStoreId.mp4',
          width: 1080,
          height: 1920,
          mimeType: 'video/mp4',
          firstSeenAt: _t0,
        ),
      );

  Future<void> link(int clipId, int reelId) => db
      .into(db.clipReels)
      .insert(
        ClipReelsCompanion.insert(clipId: clipId, reelId: reelId, addedAt: _t0),
      );

  Future<List<int>> clipIds() async =>
      (await db.select(db.clips).get()).map((c) => c.id).toList()..sort();

  group('create', () {
    test('trims the name and starts collecting at the current time', () async {
      final reel = await repo.create('  Goa  ', description: 'Beach trip');

      expect(reel.name, 'Goa');
      expect(reel.description, 'Beach trip');
      expect(reel.status, ReelStatus.collecting);
      expect(reel.createdAt, _t0);
      expect(reel.updatedAt, _t0);
      expect(await repo.getById(reel.id), reel);
    });

    test('stores an empty or blank description as null', () async {
      final none = await repo.create('A');
      final empty = await repo.create('B', description: '');
      final blank = await repo.create('C', description: '   ');

      expect(none.description, isNull);
      expect(empty.description, isNull);
      expect(blank.description, isNull);
    });

    test('accepts 40 emoji and rejects 41', () async {
      final reel = await repo.create('🎬' * 40);
      expect(reel.name, '🎬' * 40);

      await expectLater(
        repo.create('🎬' * 41),
        throwsA(
          isA<InvalidInputException>().having(
            (e) => e.problem,
            'problem',
            ReelNameProblem.tooLong,
          ),
        ),
      );
    });

    test('rejects an empty or space-only name and saves nothing', () async {
      for (final name in ['', '   ']) {
        await expectLater(
          repo.create(name),
          throwsA(
            isA<InvalidInputException>().having(
              (e) => e.problem,
              'problem',
              ReelNameProblem.empty,
            ),
          ),
        );
      }
      expect(await db.select(db.reels).get(), isEmpty);
    });

    test('duplicate name is rejected ignoring case and edge spaces', () async {
      final goa = await repo.create('Goa');
      final cafe = await repo.create('Café');
      final paris = await repo.create('Paris');
      clock.advance(const Duration(minutes: 1));

      for (final name in ['Goa', 'GOA', '  goa ', '\u200Bgoa\uFEFF', 'CAFÉ']) {
        await expectLater(
          repo.create(name),
          throwsA(
            isA<InvalidInputException>().having(
              (e) => e.problem,
              'problem',
              ReelNameProblem.duplicate,
            ),
          ),
          reason: name,
        );
        await expectLater(
          repo.rename(paris.id, name),
          throwsA(
            isA<InvalidInputException>().having(
              (e) => e.problem,
              'problem',
              ReelNameProblem.duplicate,
            ),
          ),
          reason: name,
        );
      }

      // Nothing was saved: still three reels, Paris unchanged.
      expect(await repo.watchAll().first, hasLength(3));
      expect((await repo.getById(paris.id))!.name, 'Paris');
      expect((await repo.getById(paris.id))!.updatedAt, _t0);
      // Different names, also ones that only look alike, are fine.
      expect((await repo.create('Goa 2')).name, 'Goa 2');
      expect((await repo.create('Cafe')).name, 'Cafe');
      expect(await repo.getById(goa.id), goa);
      expect(await repo.getById(cafe.id), cafe);
    });

    test('rename to its own name in another case is fine', () async {
      final reel = await repo.create('Goa');
      await repo.create('Paris');
      clock.advance(const Duration(minutes: 1));

      await repo.rename(reel.id, '  GOA ');

      final after = (await repo.getById(reel.id))!;
      expect(after.name, 'GOA');
      expect(after.updatedAt, _t0.add(const Duration(minutes: 1)));
    });

    test(
      'rename to its own name is fine while an imported duplicate exists',
      () async {
        final goa = await repo.create('Goa');
        await repo.create('Paris');
        // A backup import (or Undo of a delete) can bring a second "goa".
        await db
            .into(db.reels)
            .insert(
              ReelsCompanion.insert(
                name: 'goa',
                status: ReelStatus.collecting,
                createdAt: _t0,
                updatedAt: _t0,
              ),
            );
        clock.advance(const Duration(minutes: 1));

        await repo.rename(goa.id, 'Goa');
        await repo.rename(goa.id, ' GOA ');

        expect((await repo.getById(goa.id))!.name, 'GOA');
        // Another reel's name is still refused.
        await expectLater(
          repo.rename(goa.id, 'paris'),
          throwsA(
            isA<InvalidInputException>().having(
              (e) => e.problem,
              'problem',
              ReelNameProblem.duplicate,
            ),
          ),
        );
      },
    );

    test('description over 1000 is rejected and saves nothing', () async {
      await expectLater(
        repo.create('Goa', description: 'a' * 1001),
        throwsA(
          isA<InvalidInputException>().having(
            (e) => e.problem,
            'problem',
            ReelDescriptionProblem.tooLong,
          ),
        ),
      );
      expect(await db.select(db.reels).get(), isEmpty);

      final reel = await repo.create('Goa', description: 'Beach');
      clock.advance(const Duration(minutes: 1));
      await expectLater(
        repo.setDescription(reel.id, 'b' * 1001),
        throwsA(
          isA<InvalidInputException>().having(
            (e) => e.problem,
            'problem',
            ReelDescriptionProblem.tooLong,
          ),
        ),
      );
      expect(await repo.getById(reel.id), reel);

      // Exactly 1,000 is fine, and the spaces around it do not count.
      await repo.setDescription(reel.id, ' ${'c' * 1000} ');
      expect((await repo.getById(reel.id))!.description, 'c' * 1000);
      expect(
        (await repo.create('Paris', description: 'd' * 1000)).description,
        'd' * 1000,
      );
    });

    test('1000 emoji description is accepted', () async {
      // 2,000 UTF-16 units, 1,000 characters.
      final reel = await repo.create('Goa', description: '🌴' * 1000);
      expect(reel.description, '🌴' * 1000);

      await repo.setDescription(reel.id, '🇮🇳' * 1000);
      expect((await repo.getById(reel.id))!.description, '🇮🇳' * 1000);

      await expectLater(
        repo.setDescription(reel.id, '🌴' * 1001),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('two saves of one name at once create one reel', () async {
      final results = await Future.wait([
        repo.create('Goa').then<Object>((r) => r, onError: (Object e) => e),
        repo.create('goa').then<Object>((r) => r, onError: (Object e) => e),
      ]);

      expect(results.whereType<Reel>(), hasLength(1));
      expect(results.whereType<InvalidInputException>(), hasLength(1));
      expect(await db.select(db.reels).get(), hasLength(1));
    });
  });

  group('edits', () {
    test('rename trims, saves and bumps updatedAt', () async {
      final reel = await repo.create('Goa');
      clock.advance(const Duration(minutes: 5));

      await repo.rename(reel.id, '  Goa 2026 ');

      final after = (await repo.getById(reel.id))!;
      expect(after.name, 'Goa 2026');
      expect(after.createdAt, _t0);
      expect(after.updatedAt, _t0.add(const Duration(minutes: 5)));
    });

    test('rename validates the name and leaves the reel unchanged', () async {
      final reel = await repo.create('Goa');
      clock.advance(const Duration(minutes: 5));

      await expectLater(
        repo.rename(reel.id, 'x' * 41),
        throwsA(isA<InvalidInputException>()),
      );
      await expectLater(
        repo.rename(reel.id, ' '),
        throwsA(isA<InvalidInputException>()),
      );

      expect(await repo.getById(reel.id), reel);
    });

    test('setDescription sets, clears and bumps updatedAt', () async {
      final reel = await repo.create('Goa');
      clock.advance(const Duration(minutes: 1));

      await repo.setDescription(reel.id, 'Day 1');
      var after = (await repo.getById(reel.id))!;
      expect(after.description, 'Day 1');
      expect(after.updatedAt, _t0.add(const Duration(minutes: 1)));

      clock.advance(const Duration(minutes: 1));
      await repo.setDescription(reel.id, '  ');
      after = (await repo.getById(reel.id))!;
      expect(after.description, isNull);
      expect(after.updatedAt, _t0.add(const Duration(minutes: 2)));

      await repo.setDescription(reel.id, 'Again');
      await repo.setDescription(reel.id, null);
      expect((await repo.getById(reel.id))!.description, isNull);
    });

    test('setStatus saves the status and bumps updatedAt', () async {
      final reel = await repo.create('Goa');
      clock.advance(const Duration(hours: 1));

      await repo.setStatus(reel.id, ReelStatus.published);

      final after = (await repo.getById(reel.id))!;
      expect(after.status, ReelStatus.published);
      expect(after.updatedAt, _t0.add(const Duration(hours: 1)));
    });

    test('an unknown id throws StateError', () async {
      await expectLater(repo.rename(99, 'x'), throwsStateError);
      await expectLater(repo.setDescription(99, 'x'), throwsStateError);
      await expectLater(repo.setStatus(99, ReelStatus.ready), throwsStateError);
    });
  });

  group('reading', () {
    test('getById and watchById return null for an unknown id', () async {
      expect(await repo.getById(1), isNull);
      expect(await repo.watchById(1).first, isNull);
    });

    test('watchById emits the reel again after an edit', () async {
      final reel = await repo.create('Goa');
      final emitted = <String?>[];
      final sub = repo.watchById(reel.id).listen((r) => emitted.add(r?.name));
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await repo.rename(reel.id, 'Goa 2');
      await pumpEventQueue();
      await repo.delete(reel.id);
      await pumpEventQueue();

      expect(emitted, ['Goa', 'Goa 2', null]);
    });

    test('watchAll sorts by updatedAt, newest first, ties by id', () async {
      final a = await repo.create('A');
      final b = await repo.create('B');
      clock.advance(const Duration(minutes: 1));
      final c = await repo.create('C');
      final d = await repo.create('D');

      // a and b share one time, c and d another: ties fall back to id.
      expect((await repo.watchAll().first).map((r) => r.id), [
        d.id,
        c.id,
        b.id,
        a.id,
      ]);
    });

    test('watchAll emits in the new order after an edit', () async {
      final a = await repo.create('A');
      clock.advance(const Duration(minutes: 1));
      final b = await repo.create('B');
      final orders = <List<int>>[];
      final sub = repo.watchAll().listen(
        (reels) => orders.add([for (final r in reels) r.id]),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();

      clock.advance(const Duration(minutes: 1));
      await repo.rename(a.id, 'A2');
      await pumpEventQueue();

      expect(orders, [
        [b.id, a.id],
        [a.id, b.id],
      ]);
    });
  });

  group('delete', () {
    test('removes the reel with its links, references and VN rows', () async {
      final reel = await repo.create('Goa');
      final other = await repo.create('Other');
      final clip = await insertClip(1);
      await link(clip, reel.id);
      await link(clip, other.id);
      await db
          .into(db.reelReferences)
          .insert(
            ReelReferencesCompanion.insert(
              reelId: reel.id,
              url: 'https://example.com/a',
              source: ReferenceSource.link,
              createdAt: _t0,
            ),
          );
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
              clipId: clip,
              copyMediaStoreId: 500,
              fileName: 'VID_1.mp4',
              sizeBytes: 1000,
            ),
          );

      await repo.delete(reel.id);

      expect(await repo.getById(reel.id), isNull);
      expect(await repo.getById(other.id), isNotNull);
      expect(await db.select(db.reelReferences).get(), isEmpty);
      expect(await db.select(db.vnSessions).get(), isEmpty);
      expect(await db.select(db.vnCopies).get(), isEmpty);
      final links = await db.select(db.clipReels).get();
      expect(links.map((l) => l.reelId), [other.id]);
    });

    test('keeps a clip still in another reel, drops one only here', () async {
      final goa = await repo.create('Goa');
      final other = await repo.create('Other');
      final shared = await insertClip(1);
      final onlyHere = await insertClip(2);
      await link(shared, goa.id);
      await link(shared, other.id);
      await link(onlyHere, goa.id);

      await repo.delete(goa.id);

      expect(await clipIds(), [shared]);
    });

    test('keeps a clip that is in To tag or Skipped', () async {
      final goa = await repo.create('Goa');
      final pending = await insertClip(1);
      final skipped = await insertClip(2);
      await link(pending, goa.id);
      await link(skipped, goa.id);
      await db
          .into(db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(pending),
              state: InboxState.pending,
              addedAt: _t0,
            ),
          );
      await db
          .into(db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(skipped),
              state: InboxState.skipped,
              addedAt: _t0,
            ),
          );

      await repo.delete(goa.id);

      expect(await clipIds(), [pending, skipped]);
    });

    test('keeps the VN copy row of a clip it removes', () async {
      final other = await repo.create('Other');
      final goa = await repo.create('Goa');
      final clip = await insertClip(1);
      await link(clip, other.id);
      await db
          .into(db.vnSessions)
          .insert(
            VnSessionsCompanion.insert(
              reelId: Value(other.id),
              folderName: 'Other',
              createdAt: _t0,
            ),
          );
      await db
          .into(db.vnCopies)
          .insert(
            VnCopiesCompanion.insert(
              reelId: other.id,
              clipId: clip,
              copyMediaStoreId: 500,
              fileName: 'VID_1.mp4',
              sizeBytes: 1000,
            ),
          );
      await db.delete(db.clipReels).go();

      await repo.delete(goa.id);

      expect(await clipIds(), isEmpty);
      expect(await db.select(db.vnCopies).get(), hasLength(1));
    });

    test('deleting a reel updates every stream that showed it', () async {
      // The links and references go by ON DELETE CASCADE, which drift only
      // reports to watchers through its generated stream-update rules.
      final clips = ClipsRepository(db, clock);
      final references = ReferencesRepository(db, clock);
      final goa = await repo.create('Goa');
      NewClip clip(int id) => NewClip.mediaStore(
        mediaStoreId: id,
        volumeName: 'external_primary',
        fingerprint: ClipFingerprint(
          sizeBytes: id,
          durationMs: 1000,
          dateTakenUtc: _t0,
          displayName: 'VID_$id.mp4',
        ),
        width: 1080,
        height: 1920,
        mimeType: 'video/mp4',
      );
      final [first, _] = await clips.addNewClipsToReel(goa.id, [
        clip(1),
        clip(2),
      ]);
      await references.add(goa.id, 'https://example.com/a');
      await clips.saveDetected([clip(3)]);

      final counts = <Map<int, int>>[];
      final refs = <int>[];
      final reelClips = <int>[];
      final reelIdsOfFirst = <Set<int>>[];
      final pending = <int>[];
      final subs = [
        references.watchCounts().listen(counts.add),
        references.watchForReel(goa.id).listen((r) => refs.add(r.length)),
        clips.watchReelClips(goa.id).listen((c) => reelClips.add(c.length)),
        clips.watchReelIdsOf(first).listen(reelIdsOfFirst.add),
        clips.watchPendingCount().listen(pending.add),
      ];
      for (final sub in subs) {
        addTearDown(sub.cancel);
      }
      await pumpEventQueue();
      // Before the delete, every stream shows the reel.
      expect(counts.last, {goa.id: 1});
      expect(refs.last, 1);
      expect(reelClips.last, 2);
      expect(reelIdsOfFirst.last, {goa.id});
      expect(pending.last, 1);

      await repo.delete(goa.id);
      await pumpEventQueue();

      expect(counts.last, isEmpty);
      expect(refs.last, 0);
      expect(reelClips.last, 0);
      expect(reelIdsOfFirst.last, isEmpty);
      expect(pending.last, 1, reason: 'the clip in To tag is not affected');
    });

    test('an unknown id deletes no reel but still sweeps orphans', () async {
      final reel = await repo.create('Goa');
      final inReel = await insertClip(1);
      await link(inReel, reel.id);
      await insertClip(2); // an orphan: in no reel, not in To tag

      await repo.delete(99);

      expect(await repo.getById(reel.id), reel);
      expect(await clipIds(), [inReel]);
    });
  });

  group('deleteOrphanClips', () {
    test('deletes only clips with no reel and no inbox row', () async {
      final reel = await repo.create('Goa');
      final inReel = await insertClip(1);
      final inInbox = await insertClip(2);
      await insertClip(3);
      await link(inReel, reel.id);
      await db
          .into(db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(inInbox),
              state: InboxState.pending,
              addedAt: _t0,
            ),
          );

      final deleted = await db.deleteOrphanClips();

      expect(deleted, 1);
      expect(await clipIds(), [inReel, inInbox]);
      expect(await db.deleteOrphanClips(), 0);
    });
  });

  group('watchReelSummaries', () {
    late ClipsRepository clips;

    setUp(() => clips = ClipsRepository(db, clock));

    NewClip shot(int mediaStoreId, {DateTime? at, int durationMs = 5000}) =>
        NewClip.mediaStore(
          mediaStoreId: mediaStoreId,
          volumeName: 'external_primary',
          fingerprint: ClipFingerprint(
            sizeBytes: 1000 + mediaStoreId,
            durationMs: durationMs,
            dateTakenUtc: at ?? _t0,
            displayName: 'VID_$mediaStoreId.mp4',
          ),
          width: 1080,
          height: 1920,
          mimeType: 'video/mp4',
          timeZoneId: 'Europe/London',
          generationAdded: 3,
        );

    NewClip picked(String uri, DateTime at) => NewClip.picker(
      pickerUri: uri,
      fingerprint: ClipFingerprint(
        sizeBytes: 2000,
        durationMs: 8000,
        dateTakenUtc: at,
        displayName: 'picked.mp4',
      ),
      width: 0,
      height: 0,
      mimeType: 'video/mp4',
    );

    test('summaries count clips, missing and live duration', () async {
      final goa = await repo.create('Goa');
      final paris = await repo.create('Paris');
      final ids = await clips.addNewClipsToReel(goa.id, [
        shot(10),
        shot(11, durationMs: 7000),
        shot(12, durationMs: 9000),
      ]);
      await clips.addClipsToReel(paris.id, [ids[2]]);
      await flagClips(db, {ids[1]}, missing: true, at: _t0);

      final summaries = {
        for (final s in await repo.watchReelSummaries().first) s.reel.id: s,
      };

      expect(summaries[goa.id]!.clipCount, 3);
      expect(summaries[goa.id]!.missingCount, 1);
      expect(summaries[goa.id]!.liveDurationMs, 14000);
      expect(summaries[paris.id]!.clipCount, 1);
      expect(summaries[paris.id]!.missingCount, 0);
      expect(summaries[paris.id]!.liveDurationMs, 9000);
      expect(summaries[goa.id]!.reel, await repo.getById(goa.id));
    });

    test('cover is the oldest showable clip', () async {
      final goa = await repo.create('Goa');
      final other = await repo.create('Other');
      const hour = Duration(hours: 1);
      // Older than every Goa clip, but in another reel.
      await clips.addNewClipsToReel(other.id, [
        shot(1, at: _t0.subtract(hour * 9)),
      ]);
      // Saved newest first, so a lower id does not mean an older clip.
      final ids = await clips.addNewClipsToReel(goa.id, [
        shot(12, at: _t0), // the newest, lowest id
        shot(10, at: _t0.subtract(hour * 6)), // missing
        shot(11, at: _t0.subtract(hour * 5)), // detached
        shot(15, at: _t0.subtract(hour * 4)), // number below 1, not missing
        picked('content://picked/1', _t0.subtract(hour * 3)), // no picture
        shot(13, at: _t0.subtract(hour * 2)), // the cover: oldest left
        shot(14, at: _t0.subtract(hour * 2)), // the same time, higher id
      ]);
      await flagClips(db, {ids[1]}, missing: true, at: _t0);
      await detachClips(db, {ids[2]}, at: _t0);
      // A state the app never makes (a detached clip that is not missing),
      // written by hand: it still has no picture to ask for.
      await detachClips(db, {ids[3]}, at: _t0);
      await flagClips(db, {ids[3]}, missing: false, at: _t0);

      final cover = (await repo.watchReelSummaries().first)
          .singleWhere((s) => s.reel.id == goa.id)
          .cover;

      expect(cover, (await clips.clipsByIds([ids[5]])).single);
      expect(ids[6], greaterThan(ids[5]));
    });

    test('a reel with no clips has a null cover and zeros', () async {
      final goa = await repo.create('Goa');
      final missingOnly = await repo.create('Gone');
      final id = (await clips.addNewClipsToReel(missingOnly.id, [
        shot(10),
      ])).single;
      await flagClips(db, {id}, missing: true, at: _t0);

      final summaries = await repo.watchReelSummaries().first;
      final empty = summaries.singleWhere((s) => s.reel.id == goa.id);
      final gone = summaries.singleWhere((s) => s.reel.id == missingOnly.id);

      expect(empty.clipCount, 0);
      expect(empty.missingCount, 0);
      expect(empty.liveDurationMs, 0);
      expect(empty.cover, isNull);
      expect(
        (gone.clipCount, gone.missingCount, gone.liveDurationMs),
        (1, 1, 0),
      );
      expect(gone.cover, isNull);
    });

    test('summaries order by createdAt desc then id desc', () async {
      final oldest = await repo.create('Oldest');
      clock.advance(const Duration(minutes: 1));
      final twinA = await repo.create('Twin A');
      final twinB = await repo.create('Twin B');
      clock.advance(const Duration(minutes: 1));
      final newest = await repo.create('Newest');
      // Edited last: the order is by creation, not by the last update.
      clock.advance(const Duration(minutes: 1));
      await repo.rename(oldest.id, 'Oldest, renamed');

      final order = [
        for (final s in await repo.watchReelSummaries().first) s.reel.id,
      ];

      expect(order, [newest.id, twinB.id, twinA.id, oldest.id]);
    });

    test('summaries update after a link change', () async {
      final goa = await repo.create('Goa');
      final paris = await repo.create('Paris');
      final seen = <(int, int, int?)>[];
      final sub = repo.watchReelSummaries().listen((all) {
        final s = all.singleWhere((s) => s.reel.id == goa.id);
        seen.add((s.clipCount, s.liveDurationMs, s.cover?.mediaStoreId));
      });
      addTearDown(sub.cancel);
      await pumpEventQueue();

      final ids = await clips.addNewClipsToReel(paris.id, [
        shot(10, durationMs: 4000),
      ]);
      await pumpEventQueue();
      await clips.addClipsToReel(goa.id, ids);
      await pumpEventQueue();
      await flagClips(db, {ids.single}, missing: true, at: _t0);
      await pumpEventQueue();
      await clips.removeClipsFromReel(goa.id, ids);
      await pumpEventQueue();

      expect(seen.first, (0, 0, null));
      expect(seen, contains((1, 4000, 10)));
      expect(seen, contains((1, 0, null)));
      expect(seen.last, (0, 0, null));
    });

    test('one query per emission', () async {
      final log = StatementLog();
      // A second database next to setUp's, on purpose: its own executor.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final logged = loggedTestDatabase(log);
      addTearDown(logged.close);
      final reels = ReelsRepository(logged, clock);
      final loggedClips = ClipsRepository(logged, clock);

      /// The SELECTs one emission costs, with [count] reels of 3 clips each.
      Future<int> selectsPerEmission(int count) async {
        for (var i = 0; i < count; i++) {
          final reel = await reels.create('Reel $count.$i');
          await loggedClips.addNewClipsToReel(reel.id, [
            shot(100 * count + 3 * i),
            shot(100 * count + 3 * i + 1),
            shot(100 * count + 3 * i + 2),
          ]);
        }
        final emissions = <int>[];
        final sub = reels.watchReelSummaries().listen(
          (all) => emissions.add(all.length),
        );
        await pumpEventQueue();
        log.clear();
        // A change straight in the table: no repository reads in between.
        await logged
            .into(logged.reels)
            .insert(
              ReelsCompanion.insert(
                name: 'Trigger $count',
                status: ReelStatus.collecting,
                createdAt: _t0,
                updatedAt: _t0,
              ),
            );
        await pumpEventQueue();
        await sub.cancel();
        expect(emissions, hasLength(2));
        return log.selects.length;
      }

      final withOne = await selectsPerEmission(1);
      final withTwelve = await selectsPerEmission(12);

      expect(withOne, 1);
      expect(withTwelve, withOne);
    });
  });
}
