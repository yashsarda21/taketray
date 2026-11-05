import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';

import '../../support/clip_setup.dart';
import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

// Re-attaching detached clips (D-108, I-3): a clip Android's rebuild left
// without a number (`mediaStoreId = -id`, missing) takes the number of its
// video once the video can be seen again. The match itself is
// `matchAfterRebuild`; these tests are about what the database does with it.

const String _phone = 'external_primary';
const String _card = '1234-5678';
final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _minute = Duration(minutes: 1);

late AppDatabase db;
late FixedClock clock;
late ClipsRepository repo;
late ReelsRepository reels;

/// A detected clip shot [_t0], numbered [id]. Its size comes from [like] (the
/// video it is a copy of), so two clips with the same [like] are the same
/// video under two numbers.
NewClip _clip(int id, {int? like, String volume = _phone}) =>
    NewClip.mediaStore(
      mediaStoreId: id,
      volumeName: volume,
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

void main() {
  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    repo = ClipsRepository(db, clock);
    reels = ReelsRepository(db, clock);
  });

  /// Saves [clip] (in To tag), returns its id.
  Future<int> save(NewClip clip) async =>
      (await repo.saveDetected([clip])).single;

  /// A clip numbered [id] that Android's rebuild left without a number: it is
  /// in [reel] (when given) and detached, like `applyRebuildMatch` leaves a
  /// lost clip.
  Future<int> detachedIn(int id, {int? reel, String volume = _phone}) async {
    final clipId = await save(_clip(id, volume: volume));
    if (reel != null) await repo.addClipsToReel(reel, [clipId]);
    await detachClips(db, {clipId}, at: clock.now());
    return clipId;
  }

  Future<ClipRow> row(int id) =>
      (db.select(db.clips)..where((c) => c.id.equals(id))).getSingle();

  Future<bool> exists(int id) async => (await (db.select(
    db.clips,
  )..where((c) => c.id.equals(id))).get()).isNotEmpty;

  Future<Map<int, DateTime>> links(int clipId) async => {
    for (final l in await (db.select(
      db.clipReels,
    )..where((l) => l.clipId.equals(clipId))).get())
      l.reelId: l.addedAt,
  };

  Future<InboxRow?> inboxOf(int clipId) => (db.select(
    db.inbox,
  )..where((i) => i.clipId.equals(clipId))).getSingleOrNull();

  Future<int> clipCount() async => (await db.select(db.clips).get()).length;

  group('detachedClipsOn', () {
    test(
      'lists only the detached MediaStore clips of that volume, by id',
      () async {
        final reel = await reels.create('Goa');
        final a = await detachedIn(10, reel: reel.id);
        final attached = await save(_clip(11));
        final b = await detachedIn(12, reel: reel.id);
        final onCard = await detachedIn(13, reel: reel.id, volume: _card);
        final picked = await save(
          NewClip.picker(
            pickerUri: 'content://picker/1',
            fingerprint: ClipFingerprint(
              sizeBytes: 5,
              durationMs: 5,
              dateTakenUtc: _t0,
              displayName: 'picked.mp4',
            ),
            width: 1,
            height: 1,
            mimeType: 'video/mp4',
          ),
        );

        final clips = await repo.detachedClipsOn(_phone);

        expect([for (final c in clips) c.id], [a, b]);
        expect(clips.every((c) => c.missing && c.mediaStoreId! < 0), isTrue);
        expect(clips.map((c) => c.id), isNot(contains(attached)));
        expect(clips.map((c) => c.id), isNot(contains(onCard)));
        expect(clips.map((c) => c.id), isNot(contains(picked)));
        expect(
          [for (final c in await repo.detachedClipsOn(_card)) c.id],
          [onCard],
        );
      },
    );

    test('no detached clips, or an unknown volume, is empty', () async {
      await save(_clip(10));

      expect(await repo.detachedClipsOn(_phone), isEmpty);
      expect(await repo.detachedClipsOn('nope'), isEmpty);
    });
  });

  group('reattachDetached', () {
    test(
      'a detached clip takes the video number and is no longer missing',
      () async {
        final reel = await reels.create('Goa');
        final d = await detachedIn(10, reel: reel.id);
        clock.advance(_minute);

        final result = await repo.reattachDetached(_phone, {d: 110});

        final after = await row(d);
        expect(after.mediaStoreId, 110);
        expect(after.missing, isFalse);
        expect(after.lastVerifiedAt, _t0.add(_minute));
        // Everything else about it is the clip the user knew.
        expect(after.displayName, 'VID_10.mp4');
        expect(after.firstSeenAt, _t0);
        expect(after.timeZoneId, 'Europe/London');
        expect(await links(d), hasLength(1));
        expect((result.reattached, result.merged, result.left), (1, 0, 0));
        // It is found by its new number, so a scan sees "this video is known".
        expect((await repo.mediaStoreClipsHolding(_phone, {110}))[110]?.id, d);
      },
    );

    test('a duplicate in To tag is deleted with its inbox row and the reel '
        'clip takes its number', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(10, reel: reel.id);
      final n = await save(_clip(110, like: 10));
      final bystander = await save(_clip(20));
      expect(await inboxOf(n), isNotNull);

      final result = await repo.reattachDetached(_phone, {d: 110});

      expect(await exists(n), isFalse);
      expect(await inboxOf(n), isNull);
      expect((await row(d)).mediaStoreId, 110);
      expect((await row(d)).missing, isFalse);
      expect(await links(d), {reel.id: isA<DateTime>()});
      // The user's reel clip is in no list but its reel.
      expect(await inboxOf(d), isNull);
      // Another clip in To tag is not touched.
      expect(await inboxOf(bystander), isNotNull);
      expect((result.reattached, result.merged, result.left), (0, 1, 0));
    });

    test('a duplicate that was skipped is deleted too', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(10, reel: reel.id);
      final n = await save(_clip(110, like: 10));
      await repo.skipClips([n]);
      expect((await inboxOf(n))!.state, InboxState.skipped);

      await repo.reattachDetached(_phone, {d: 110});

      expect(await exists(n), isFalse);
      expect(await inboxOf(n), isNull);
      expect((await row(d)).mediaStoreId, 110);
    });

    test('the duplicate is in the same reel: one link, the earliest addedAt '
        'kept (the reel clip is the older)', () async {
      final reel = await reels.create('Goa');
      clock.advance(_minute);
      final d = await detachedIn(10, reel: reel.id); // linked at +1 min
      clock.advance(_minute * 4);
      final n = await save(_clip(110, like: 10));
      await repo.addClipsToReel(reel.id, [n]); // linked at +5 min

      await repo.reattachDetached(_phone, {d: 110});

      expect(await links(d), {reel.id: _t0.add(_minute)});
      expect(await exists(n), isFalse);
      expect(await db.select(db.clipReels).get(), hasLength(1));
    });

    test('the duplicate is in the same reel: one link, the earliest addedAt '
        'kept (the duplicate is the older)', () async {
      final reel = await reels.create('Goa');
      clock.advance(_minute);
      final n = await save(_clip(110, like: 10));
      await repo.addClipsToReel(reel.id, [n]); // linked at +1 min
      clock.advance(_minute * 4);
      final d = await detachedIn(10, reel: reel.id); // linked at +5 min

      await repo.reattachDetached(_phone, {d: 110});

      expect(await links(d), {reel.id: _t0.add(_minute)});
      expect(await exists(n), isFalse);
      expect(await db.select(db.clipReels).get(), hasLength(1));
    });

    test('the duplicate is in a different reel: the union of both', () async {
      final goa = await reels.create('Goa');
      final cafe = await reels.create('Cafe');
      final both = await reels.create('Both');
      clock.advance(_minute);
      final d = await detachedIn(10, reel: goa.id); // goa at +1
      await repo.addClipsToReel(both.id, [d]); // both at +1 (detached ok)
      clock.advance(_minute * 2);
      final n = await save(_clip(110, like: 10));
      await repo.addClipsToReel(cafe.id, [n]); // cafe at +3
      clock.advance(_minute);
      await repo.addClipsToReel(both.id, [n]); // both at +4: D's +1 stays

      await repo.reattachDetached(_phone, {d: 110});

      expect(await links(d), {
        goa.id: _t0.add(_minute),
        cafe.id: _t0.add(_minute * 3),
        both.id: _t0.add(_minute),
      });
      expect(await exists(n), isFalse);
      expect(await db.select(db.clipReels).get(), hasLength(3));
    });

    test('the reels the duplicate was in keep their other clips and their '
        'order', () async {
      final reel = await reels.create('Goa');
      final first = await save(_clip(30));
      final second = await save(_clip(31));
      await repo.addClipsToReel(reel.id, [first]);
      final d = await detachedIn(10, reel: reel.id);
      await repo.addClipsToReel(reel.id, [second]);
      final n = await save(_clip(110, like: 10));
      await repo.addClipsToReel(reel.id, [n]);

      await repo.reattachDetached(_phone, {d: 110});

      final ids = [
        for (final c in await repo.watchReelClips(reel.id).first) c.clip.id,
      ];
      expect(ids.toSet(), {first, second, d});
    });

    test('two detached clips matching two videos', () async {
      final reel = await reels.create('Goa');
      final d1 = await detachedIn(10, reel: reel.id);
      final d2 = await detachedIn(11, reel: reel.id);
      final n2 = await save(_clip(211, like: 11)); // a duplicate of d2 only

      final result = await repo.reattachDetached(_phone, {d1: 110, d2: 211});

      expect((await row(d1)).mediaStoreId, 110);
      expect((await row(d2)).mediaStoreId, 211);
      expect(await exists(n2), isFalse);
      expect((result.reattached, result.merged, result.left), (1, 1, 0));
      expect(await repo.detachedClipsOn(_phone), isEmpty);
    });

    test(
      'a holder that is another video leaves the detached clip alone',
      () async {
        // Clip 110 holds the number of a video this phone gave to something
        // else (its size differs): it is not a copy of the detached clip.
        final reel = await reels.create('Goa');
        final d = await detachedIn(10, reel: reel.id);
        final stale = await save(_clip(110, like: 77));

        final result = await repo.reattachDetached(_phone, {d: 110});

        expect((await row(d)).mediaStoreId, -d);
        expect((await row(d)).missing, isTrue);
        expect(await exists(stale), isTrue);
        expect((await row(stale)).mediaStoreId, 110);
        expect((result.reattached, result.merged, result.left), (0, 0, 1));
      },
    );

    test(
      'a number held by a picked clip leaves the detached clip alone',
      () async {
        final reel = await reels.create('Goa');
        final d = await detachedIn(10, reel: reel.id);
        final picked = await save(
          NewClip.picker(
            pickerUri: 'content://picker/1',
            fingerprint: ClipFingerprint(
              sizeBytes: 1010,
              durationMs: 5000,
              dateTakenUtc: _t0,
              displayName: 'picked.mp4',
            ),
            width: 1,
            height: 1,
            mimeType: 'video/mp4',
          ),
        );
        // A picked clip that also carries a volume and a number.
        await (db.update(db.clips)..where((c) => c.id.equals(picked))).write(
          const ClipsCompanion(
            volumeName: Value(_phone),
            mediaStoreId: Value(110),
          ),
        );

        final result = await repo.reattachDetached(_phone, {d: 110});

        expect((await row(d)).mediaStoreId, -d);
        expect(await exists(picked), isTrue);
        expect((result.reattached, result.merged, result.left), (0, 0, 1));
      },
    );

    test('a clip that is not detached is ignored', () async {
      final attached = await save(_clip(10));
      final other = await save(_clip(20));

      final result = await repo.reattachDetached(_phone, {attached: 20});

      expect((await row(attached)).mediaStoreId, 10);
      expect((await row(other)).mediaStoreId, 20);
      expect(await clipCount(), 2);
      expect((result.reattached, result.merged, result.left), (0, 0, 1));
    });

    test('a detached clip of another volume, a picked clip and an unknown id '
        'are ignored', () async {
      final reel = await reels.create('Goa');
      final onCard = await detachedIn(10, reel: reel.id, volume: _card);

      final result = await repo.reattachDetached(_phone, {onCard: 110, 999: 5});

      expect((await row(onCard)).mediaStoreId, -onCard);
      expect(await clipCount(), 1);
      expect((result.reattached, result.merged, result.left), (0, 0, 2));
    });

    test("a detached clip with no reel and no list takes the duplicate's "
        'place in To tag, so it is not swept', () async {
      final d = await save(_clip(10));
      await repo.skipClips([d]);
      await detachClips(db, {d}, at: clock.now());
      // Bring it to "in no place": a verify would have swept it, but a crash
      // or a manual edit may leave it so.
      await (db.delete(db.inbox)..where((i) => i.clipId.equals(d))).go();
      final n = await save(_clip(110, like: 10));

      await repo.reattachDetached(_phone, {d: 110});

      expect(await exists(n), isFalse);
      final place = await inboxOf(d);
      expect(place, isNotNull);
      expect(place!.state, InboxState.pending);
      expect((await row(d)).mediaStoreId, 110);
    });

    test('an empty match writes nothing', () async {
      final reel = await reels.create('Goa');
      final d = await detachedIn(10, reel: reel.id);
      final before = await row(d);

      final result = await repo.reattachDetached(_phone, const {});

      expect(await row(d), before);
      expect((result.reattached, result.merged, result.left), (0, 0, 0));
    });

    test('two clips for one video, or a number below 1, throw and write '
        'nothing', () async {
      final reel = await reels.create('Goa');
      final d1 = await detachedIn(10, reel: reel.id);
      final d2 = await detachedIn(11, reel: reel.id);

      await expectLater(
        repo.reattachDetached(_phone, {d1: 110, d2: 110}),
        throwsArgumentError,
      );
      await expectLater(
        repo.reattachDetached(_phone, {d1: 0}),
        throwsArgumentError,
      );
      await expectLater(
        repo.reattachDetached(_phone, {d1: -5}),
        throwsArgumentError,
      );

      expect((await row(d1)).mediaStoreId, -d1);
      expect((await row(d2)).mediaStoreId, -d2);
    });

    test('a failure part way rolls the whole volume back', () async {
      final reel = await reels.create('Goa');
      final d1 = await detachedIn(10, reel: reel.id);
      final d2 = await detachedIn(11, reel: reel.id);
      final n1 = await save(_clip(110, like: 10));
      // The second clip cannot be written (a trigger stands in for a full
      // disk), after the first one was merged.
      await db.customStatement(
        'CREATE TRIGGER fail_second BEFORE UPDATE ON clips '
        "WHEN NEW.id = $d2 BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      await expectLater(
        repo.reattachDetached(_phone, {d1: 110, d2: 211}),
        throwsA(anything),
      );

      expect(await exists(n1), isTrue, reason: 'the first merge was undone');
      expect(await inboxOf(n1), isNotNull);
      expect((await row(d1)).mediaStoreId, -d1);
      expect((await row(d1)).missing, isTrue);
      expect((await row(d2)).mediaStoreId, -d2);
    });

    test('the log has ids and counts only', () async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final reel = await reels.create('Secret reel');
      final d = await detachedIn(10, reel: reel.id);
      await save(_clip(110, like: 10));

      await repo.reattachDetached(_phone, {d: 110});

      final text = records.map((r) => '${r.message} ${r.error ?? ''}').join();
      expect(text, contains('Re-attached'));
      for (final secret in ['VID_', '.mp4', 'Secret', 'Europe']) {
        expect(text, isNot(contains(secret)));
      }
    });
  });
}
