import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/domain/models/enums.dart';

import '../../support/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);

ReelsCompanion _reel(String name) => ReelsCompanion.insert(
  name: name,
  status: ReelStatus.collecting,
  createdAt: _t0,
  updatedAt: _t0,
);

ClipsCompanion _mediaStoreClip({
  String volumeName = 'external_primary',
  int mediaStoreId = 1001,
}) => ClipsCompanion.insert(
  source: ClipSource.mediaStore,
  mediaStoreId: Value(mediaStoreId),
  volumeName: Value(volumeName),
  sizeBytes: 12000000,
  durationMs: 8000,
  dateTakenUtc: _t0,
  displayName: 'VID_20261026_090000.mp4',
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  firstSeenAt: _t0,
);

ClipsCompanion _pickerClip(String uri) => ClipsCompanion.insert(
  source: ClipSource.picker,
  pickerUri: Value(uri),
  sizeBytes: 5000000,
  durationMs: 4000,
  dateTakenUtc: _t0,
  displayName: 'picked.mp4',
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  firstSeenAt: _t0,
);

void main() {
  group('a new database', () {
    late AppDatabase db;

    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    Future<int> count(String table) async {
      final row = await db
          .customSelect('SELECT COUNT(*) AS n FROM $table')
          .getSingle();
      return row.read<int>('n');
    }

    test('foreign keys are on', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();

      expect(row.read<int>('foreign_keys'), 1);
    });

    test(
      'deleting a reel cascades its links, references and editing session',
      () async {
        final goa = await db.into(db.reels).insert(_reel('Goa'));
        final other = await db.into(db.reels).insert(_reel('Other'));
        final clip = await db.into(db.clips).insert(_mediaStoreClip());
        for (final reelId in [goa, other]) {
          await db
              .into(db.clipReels)
              .insert(
                ClipReelsCompanion.insert(
                  clipId: clip,
                  reelId: reelId,
                  addedAt: _t0,
                ),
              );
        }
        await db
            .into(db.reelReferences)
            .insert(
              ReelReferencesCompanion.insert(
                reelId: goa,
                url: 'https://www.instagram.com/reel/ABC/',
                source: ReferenceSource.instagram,
                createdAt: _t0,
              ),
            );
        await db
            .into(db.editSessions)
            .insert(
              EditSessionsCompanion.insert(
                reelId: Value(goa),
                folderName: 'Goa',
                createdAt: _t0,
              ),
            );
        await db
            .into(db.editCopies)
            .insert(
              EditCopiesCompanion.insert(
                reelId: goa,
                clipId: clip,
                copyMediaStoreId: 2001,
                fileName: '2026-10-26_09-00-00.mp4',
                sizeBytes: 12000000,
              ),
            );
        await db
            .into(db.sentClips)
            .insert(
              SentClipsCompanion.insert(reelId: goa, clipId: clip, sentAt: _t0),
            );

        await (db.delete(db.reels)..where((r) => r.id.equals(goa))).go();

        expect(await count('reels'), 1);
        expect(await count('reel_references'), 0);
        expect(await count('vn_sessions'), 0);
        expect(await count('vn_copies'), 0);
        expect(await count('sent_clips'), 0);
        // Only the link to the other reel is left, and the clip itself stays:
        // deleting clips that are in no reel is the repositories' job.
        final links = await db.select(db.clipReels).get();
        expect(links.map((l) => l.reelId), [other]);
        expect(await count('clips'), 1);
      },
    );

    test('a clip identity is unique', () async {
      await db.into(db.clips).insert(_mediaStoreClip());

      await expectLater(
        db.into(db.clips).insert(_mediaStoreClip()),
        throwsA(isA<SqliteException>()),
      );
      // The same MediaStore id on another volume is another video.
      await db.into(db.clips).insert(_mediaStoreClip(volumeName: '1234-abcd'));
      expect(await count('clips'), 2);
    });

    test('a clip identity is never half empty', () async {
      final noVolume = _mediaStoreClip().copyWith(
        volumeName: const Value(null),
      );
      final noMediaStoreId = _mediaStoreClip().copyWith(
        mediaStoreId: const Value(null),
      );
      final noPickerUri = _pickerClip('content://picker/1')
          .copyWith(pickerUri: const Value(null));

      for (final clip in [noVolume, noMediaStoreId, noPickerUri]) {
        await expectLater(
          db.into(db.clips).insert(clip),
          throwsA(isA<SqliteException>()),
        );
      }
      expect(await count('clips'), 0);
    });

    test('deleting a clip cascades its reel links and To tag row', () async {
      final reel = await db.into(db.reels).insert(_reel('Goa'));
      final clip = await db.into(db.clips).insert(_mediaStoreClip());
      await db
          .into(db.clipReels)
          .insert(
            ClipReelsCompanion.insert(clipId: clip, reelId: reel, addedAt: _t0),
          );
      await db
          .into(db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(clip),
              state: InboxState.pending,
              addedAt: _t0,
            ),
          );

      await (db.delete(db.clips)..where((c) => c.id.equals(clip))).go();

      expect(await count('clip_reels'), 0);
      expect(await count('inbox'), 0);
      expect(await count('reels'), 1);
    });

    test(
      'deleting a clip keeps the record of its copy and that it was sent',
      () async {
        // The copy is a file the app created in Movies/TakeTray/; its row is
        // the only way the editing session can find and delete it later.
        final reel = await db.into(db.reels).insert(_reel('Goa'));
        final clip = await db.into(db.clips).insert(_mediaStoreClip());
        await db
            .into(db.editSessions)
            .insert(
              EditSessionsCompanion.insert(
                reelId: Value(reel),
                folderName: 'Goa',
                createdAt: _t0,
              ),
            );
        await db
            .into(db.editCopies)
            .insert(
              EditCopiesCompanion.insert(
                reelId: reel,
                clipId: clip,
                copyMediaStoreId: 2001,
                fileName: '2026-10-26_09-00-00.mp4',
                sizeBytes: 12000000,
              ),
            );

        await db
            .into(db.sentClips)
            .insert(
              SentClipsCompanion.insert(
                reelId: reel,
                clipId: clip,
                sentAt: _t0,
              ),
            );

        await (db.delete(db.clips)..where((c) => c.id.equals(clip))).go();

        final copies = await db.select(db.editCopies).get();
        expect(copies.map((c) => (c.clipId, c.copyMediaStoreId)), [
          (clip, 2001),
        ]);
        expect(await count('sent_clips'), 1, reason: 'no foreign key to clips');
      },
    );

    test('a picked clip is unique by its URI only', () async {
      // Picked clips have no MediaStore identity; SQLite treats those NULLs as
      // distinct, so two different picked clips do not collide.
      await db.into(db.clips).insert(_pickerClip('content://picker/1'));
      await db.into(db.clips).insert(_pickerClip('content://picker/2'));

      await expectLater(
        db.into(db.clips).insert(_pickerClip('content://picker/1')),
        throwsA(isA<SqliteException>()),
      );
      expect(await count('clips'), 2);
    });

    test('times round-trip in UTC milliseconds', () async {
      final shotAt = DateTime.utc(2026, 10, 26, 9, 30, 15, 123);
      final id = await db
          .into(db.reels)
          .insert(
            ReelsCompanion.insert(
              name: 'Goa',
              status: ReelStatus.collecting,
              createdAt: shotAt,
              updatedAt: shotAt,
            ),
          );

      final reel = await (db.select(
        db.reels,
      )..where((r) => r.id.equals(id))).getSingle();
      expect(reel.createdAt, shotAt);
      expect(reel.createdAt.isUtc, isTrue);

      final raw = await db
          .customSelect(
            'SELECT created_at FROM reels WHERE id = ?',
            variables: [Variable.withInt(id)],
          )
          .getSingle();
      expect(raw.read<int>('created_at'), shotAt.millisecondsSinceEpoch);
    });

    test(
      'a local time is stored as the same instant and read as UTC',
      () async {
        final local = DateTime(2026, 10, 26, 9, 30, 15, 123);
        final id = await db
            .into(db.reels)
            .insert(
              ReelsCompanion.insert(
                name: 'Goa',
                status: ReelStatus.collecting,
                createdAt: local,
                updatedAt: local,
              ),
            );

        final reel = await (db.select(
          db.reels,
        )..where((r) => r.id.equals(id))).getSingle();
        expect(reel.createdAt, local.toUtc());
        expect(reel.createdAt.isUtc, isTrue);
      },
    );

    test('enums are stored by name', () async {
      await db
          .into(db.reels)
          .insert(_reel('Goa').copyWith(status: const Value(ReelStatus.ready)));
      await db.into(db.clips).insert(_mediaStoreClip());

      final reel = await db
          .customSelect('SELECT status FROM reels')
          .getSingle();
      final clip = await db
          .customSelect('SELECT source FROM clips')
          .getSingle();
      expect(reel.read<String>('status'), 'ready');
      expect(clip.read<String>('source'), 'mediaStore');
    });
  });

  test('a database from a newer app version is not opened', () async {
    // A downgrade (say, an older build installed with `adb install -d`) must
    // not stamp a newer schema as the current version.
    late int Function() userVersion;
    late final AppDatabase newer;
    newer = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = ${newer.schemaVersion + 1}');
          userVersion = () => raw.userVersion;
        },
      ),
    );
    addTearDown(newer.close);

    await expectLater(
      newer.customSelect('SELECT 1').get(),
      throwsA(isA<UnsupportedError>()),
    );
    expect(userVersion(), newer.schemaVersion + 1);
  });
}
