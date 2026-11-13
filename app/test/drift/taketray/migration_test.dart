// dart format width=80
// Generated once by `drift_dev make-migrations` (schema v2), then filled in by
// hand: make-migrations never rewrites this file once it exists, and
// tool/check_generated keeps it (D-120). The schema helpers in generated/ are
// regenerated.
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

// Times as the database stores them: UTC milliseconds.
final int _t = DateTime.utc(
  2026,
  10,
  26,
  9,
  30,
  15,
  123,
).millisecondsSinceEpoch;
final int _t2 = DateTime.utc(2026, 11, 2, 18, 5).millisecondsSinceEpoch;
const int _hour = 3600 * 1000;

/// Wraps the database's opener so that "the process dies" right after the
/// migrations ran and `beforeOpen` finished, before Drift writes the new
/// `user_version` (it does that after `beforeOpen`, outside any transaction).
class _DieBeforeVersionWrite extends QueryInterceptor {
  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      executor.ensureOpen(_DyingUser(user));
}

class _DyingUser implements QueryExecutorUser {
  _DyingUser(this._inner);

  final QueryExecutorUser _inner;

  @override
  int get schemaVersion => _inner.schemaVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    await _inner.beforeOpen(executor, details);
    throw StateError('killed before the version was written');
  }
}

Future<List<String>> _sortedRows(
  AppDatabase db,
  TableInfo<Table, Object?> table,
) async => [for (final row in await db.select(table).get()) '$row']..sort();

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // A phone at v1: two reels, each with a VN session (Goa at T, Lisbon at
  // T2), clips detected and picked, To tag and Skipped rows, a reference,
  // copies (one of a clip that was deleted since, D-54), settings and the
  // zone timeline.
  final oldReels = [
    v1.ReelsData(
      id: 3,
      name: 'Goa 🌴',
      description: 'Beach week',
      status: 'collecting',
      createdAt: _t - 48 * _hour,
      updatedAt: _t - _hour,
    ),
    v1.ReelsData(
      id: 7,
      name: 'Lisbon',
      status: 'ready',
      createdAt: _t - 24 * _hour,
      updatedAt: _t2,
    ),
  ];
  final oldClips = [
    v1.ClipsData(
      id: 10,
      source: 'mediaStore',
      mediaStoreId: 1000000041,
      volumeName: 'external_primary',
      sizeBytes: 3000000000,
      durationMs: 61500,
      dateTakenUtc: _t - 50 * _hour,
      displayName: 'VID_20261024_073015.mp4',
      width: 3840,
      height: 2160,
      mimeType: 'video/mp4',
      timeZoneId: 'Asia/Kolkata',
      generationAdded: 52311,
      firstSeenAt: _t - 49 * _hour,
      missing: 0,
      lastVerifiedAt: _t - _hour,
    ),
    v1.ClipsData(
      id: 11,
      source: 'picker',
      pickerUri: 'content://media/picker/0/com.android.providers.media/42',
      sizeBytes: 8123456,
      durationMs: 4000,
      dateTakenUtc: _t - 30 * _hour,
      displayName: 'friend.mp4',
      width: 1080,
      height: 1920,
      mimeType: 'video/quicktime',
      firstSeenAt: _t - 29 * _hour,
      missing: 1,
    ),
    v1.ClipsData(
      id: 12,
      source: 'mediaStore',
      mediaStoreId: 77,
      volumeName: '1234-abcd',
      sizeBytes: 0,
      durationMs: 0,
      dateTakenUtc: _t - 2 * _hour,
      displayName: 'VID_2.mp4',
      width: 0,
      height: 0,
      mimeType: 'video/mp4',
      firstSeenAt: _t - _hour,
      missing: 0,
    ),
  ];
  final oldLinks = [
    v1.ClipReelsData(clipId: 10, reelId: 3, addedAt: _t - 48 * _hour),
    v1.ClipReelsData(clipId: 10, reelId: 7, addedAt: _t - 20 * _hour),
    v1.ClipReelsData(clipId: 11, reelId: 7, addedAt: _t - 20 * _hour),
  ];
  final oldInbox = [
    v1.InboxData(clipId: 12, state: 'pending', addedAt: _t - _hour),
  ];
  final oldReferences = [
    v1.ReelReferencesData(
      id: 1,
      reelId: 3,
      url: 'https://www.instagram.com/p/ABC123/',
      source: 'instagram',
      label: 'Slow pans',
      createdAt: _t - 40 * _hour,
    ),
  ];
  final oldSessions = [
    v1.VnSessionsData(reelId: 3, folderName: 'Goa', createdAt: _t),
    v1.VnSessionsData(reelId: 7, folderName: 'Lisbon (2)', createdAt: _t2),
  ];
  final oldCopies = [
    const v1.VnCopiesData(
      reelId: 3,
      clipId: 10,
      copyMediaStoreId: 1000000500,
      fileName: '2026-10-24_13-00-15.mp4',
      sizeBytes: 3000000000,
    ),
    // Clip 9 was removed from its last reel and deleted; the copy stays.
    const v1.VnCopiesData(
      reelId: 3,
      clipId: 9,
      copyMediaStoreId: 1000000501,
      fileName: '2026-10-24_13-00-15_2.mp4',
      sizeBytes: 5000,
    ),
    const v1.VnCopiesData(
      reelId: 7,
      clipId: 11,
      copyMediaStoreId: 1000000502,
      fileName: '2026-10-25_03-30-15.mov',
      sizeBytes: 8123456,
    ),
  ];
  final oldSettings = [
    const v1.SettingsData(
      key: 'watchedFolders',
      value: '["DCIM/Camera","Movies/WhatsApp"]',
    ),
    const v1.SettingsData(key: 'shootingMode', value: '{"on":false}'),
  ];
  final oldZones = [
    v1.ZoneTimelineData(at: _t - 100 * _hour, zoneId: 'Asia/Kolkata'),
    v1.ZoneTimelineData(at: _t - 10 * _hour, zoneId: 'Europe/Lisbon'),
  ];

  void insertV1(Batch batch, v1.DatabaseAtV1 oldDb) {
    batch
      ..insertAll(oldDb.reels, oldReels)
      ..insertAll(oldDb.clips, oldClips)
      ..insertAll(oldDb.clipReels, oldLinks)
      ..insertAll(oldDb.inbox, oldInbox)
      ..insertAll(oldDb.reelReferences, oldReferences)
      ..insertAll(oldDb.vnSessions, oldSessions)
      ..insertAll(oldDb.vnCopies, oldCopies)
      ..insertAll(oldDb.settings, oldSettings)
      ..insertAll(oldDb.zoneTimeline, oldZones);
  }

  /// Fills a v1 database the way a phone left it.
  Future<InitializedSchema> phoneAtV1() async {
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.batch((b) => insertV1(b, oldDb));
    await oldDb.close();
    return schema;
  }

  /// Every row of every table, as text, sorted.
  Future<String> everyRow(AppDatabase db) async => [
    for (final table in db.allTables)
      '${table.actualTableName}: ${await _sortedRows(db, table)}',
  ].join('\n');

  test('migration from v1 to v2 does not corrupt data', () async {
    // Every v1 row comes through unchanged; the new columns are filled.
    final expectedReels = [
      for (final r in oldReels)
        v2.ReelsData(
          id: r.id,
          name: r.name,
          description: r.description,
          status: r.status,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        ),
    ];
    final expectedClips = [
      for (final c in oldClips)
        v2.ClipsData(
          id: c.id,
          source: c.source,
          mediaStoreId: c.mediaStoreId,
          volumeName: c.volumeName,
          pickerUri: c.pickerUri,
          sizeBytes: c.sizeBytes,
          durationMs: c.durationMs,
          dateTakenUtc: c.dateTakenUtc,
          displayName: c.displayName,
          width: c.width,
          height: c.height,
          mimeType: c.mimeType,
          timeZoneId: c.timeZoneId,
          generationAdded: c.generationAdded,
          firstSeenAt: c.firstSeenAt,
          missing: c.missing,
          lastVerifiedAt: c.lastVerifiedAt,
        ),
    ];
    final expectedLinks = [
      for (final l in oldLinks)
        v2.ClipReelsData(
          clipId: l.clipId,
          reelId: l.reelId,
          addedAt: l.addedAt,
        ),
    ];
    final expectedInbox = [
      for (final i in oldInbox)
        v2.InboxData(clipId: i.clipId, state: i.state, addedAt: i.addedAt),
    ];
    final expectedReferences = [
      for (final r in oldReferences)
        v2.ReelReferencesData(
          id: r.id,
          reelId: r.reelId,
          url: r.url,
          source: r.source,
          label: r.label,
          createdAt: r.createdAt,
        ),
    ];
    // Every v1 session was a VN one.
    final expectedSessions = [
      v2.VnSessionsData(
        reelId: 3,
        editor: 'vn',
        folderName: 'Goa',
        createdAt: _t,
      ),
      v2.VnSessionsData(
        reelId: 7,
        editor: 'vn',
        folderName: 'Lisbon (2)',
        createdAt: _t2,
      ),
    ];
    // Each copy's time is its own session's start: the best v1 knows.
    final sessionStart = {3: _t, 7: _t2};
    final expectedCopies = [
      for (final c in oldCopies)
        v2.VnCopiesData(
          reelId: c.reelId,
          clipId: c.clipId,
          copyMediaStoreId: c.copyMediaStoreId,
          fileName: c.fileName,
          sizeBytes: c.sizeBytes,
          copiedAt: sessionStart[c.reelId]!,
        ),
    ];
    final expectedSettings = [
      for (final s in oldSettings) v2.SettingsData(key: s.key, value: s.value),
    ];
    final expectedZones = [
      for (final z in oldZones) v2.ZoneTimelineData(at: z.at, zoneId: z.zoneId),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: insertV1,
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.reels).get(), expectedReels);
        expect(await newDb.select(newDb.clips).get(), expectedClips);
        expect(await newDb.select(newDb.clipReels).get(), expectedLinks);
        expect(await newDb.select(newDb.inbox).get(), expectedInbox);
        expect(
          await newDb.select(newDb.reelReferences).get(),
          expectedReferences,
        );
        expect(await newDb.select(newDb.vnSessions).get(), expectedSessions);
        expect(await newDb.select(newDb.vnCopies).get(), expectedCopies);
        expect(await newDb.select(newDb.sentClips).get(), isEmpty);
        expect(await newDb.select(newDb.settings).get(), expectedSettings);
        expect(await newDb.select(newDb.zoneTimeline).get(), expectedZones);
      },
    );
  });

  test('after the upgrade, foreign keys are on and deleting a reel still '
      'cascades its session, copies and sent rows', () async {
    final schema = await phoneAtV1();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.read<int>('foreign_keys'), 1);
    await db
        .into(db.sentClips)
        .insert(
          SentClipsCompanion.insert(
            reelId: 3,
            clipId: 10,
            sentAt: DateTime.utc(2026, 11, 12),
          ),
        );
    await db
        .into(db.sentClips)
        .insert(
          SentClipsCompanion.insert(
            reelId: 7,
            clipId: 10,
            sentAt: DateTime.utc(2026, 11, 12),
          ),
        );
    // A sent row needs its session: the foreign key holds.
    await expectLater(
      db
          .into(db.sentClips)
          .insert(
            SentClipsCompanion.insert(
              reelId: 99,
              clipId: 10,
              sentAt: DateTime.utc(2026, 11, 12),
            ),
          ),
      throwsA(anything),
    );

    await (db.delete(db.reels)..where((r) => r.id.equals(3))).go();

    expect(
      [for (final s in await db.select(db.editSessions).get()) s.reelId],
      [7],
    );
    expect(
      {for (final c in await db.select(db.editCopies).get()) c.reelId},
      {7},
    );
    expect(
      [for (final s in await db.select(db.sentClips).get()) s.reelId],
      [7],
    );
    expect(schema.rawDatabase.userVersion, 2);
  });

  test('a step that fails half way leaves the v1 file exactly as it was, and '
      'the next open migrates it', () async {
    final schema = await phoneAtV1();
    // The copy-time UPDATE fails after both columns were added.
    schema.rawDatabase.execute(
      'CREATE TRIGGER p8_task3_fail BEFORE UPDATE ON vn_copies '
      "BEGIN SELECT RAISE(ABORT, 'injected'); END",
    );
    List<String> columns(String table) => [
      for (final row in schema.rawDatabase.select('PRAGMA table_info($table)'))
        row['name'] as String,
    ];
    final sessionColumns = columns('vn_sessions');
    final copyColumns = columns('vn_copies');

    final failing = AppDatabase(schema.newConnection());
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(anything),
    );
    await failing.close();

    expect(schema.rawDatabase.userVersion, 1);
    expect(columns('vn_sessions'), sessionColumns);
    expect(columns('vn_copies'), copyColumns);
    expect(
      schema.rawDatabase.select(
        "SELECT name FROM sqlite_master WHERE name LIKE 'sent_clips%'",
      ),
      isEmpty,
    );

    schema.rawDatabase.execute('DROP TRIGGER p8_task3_fail');
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await db.validateDatabaseSchema(
      options: const ValidationOptions(validateDropped: true),
    );
    final copies = await db.select(db.editCopies).get();
    expect(copies, hasLength(3));
    expect(
      {for (final c in copies) c.copiedAt.millisecondsSinceEpoch},
      {_t, _t2},
    );
  });

  test('a phone killed after the step but before Drift writes the version '
      'opens normally next time', () async {
    final schema = await phoneAtV1();

    final dying = AppDatabase(
      schema.newConnection().interceptWith(_DieBeforeVersionWrite()),
    );
    await expectLater(dying.customSelect('SELECT 1').get(), throwsStateError);
    await dying.close();

    // Drift's runMigrationSteps wrote the version after the step, inside the
    // step's transaction, so the next open does not run it again on the v2
    // tables.
    expect(schema.rawDatabase.userVersion, 2);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    final before = await everyRow(db);
    await db.validateDatabaseSchema(
      options: const ValidationOptions(validateDropped: true),
    );
    expect(await db.select(db.editSessions).get(), hasLength(2));
    expect(await everyRow(db), before);
  });

  test('a v1 copy row whose session is gone (foreign keys were off) does not '
      'stop the upgrade: it keeps copied_at 0', () async {
    final schema = await phoneAtV1();
    schema.rawDatabase
      ..execute('PRAGMA foreign_keys = OFF')
      ..execute(
        'INSERT INTO vn_copies '
        '(reel_id, clip_id, copy_media_store_id, file_name, size_bytes) '
        "VALUES (55, 1, 2, 'x.mp4', 3)",
      );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    final orphan = await (db.select(
      db.editCopies,
    )..where((c) => c.reelId.equals(55))).getSingle();

    expect(orphan.copiedAt.millisecondsSinceEpoch, 0);
    expect(await db.select(db.editCopies).get(), hasLength(4));
  });
}
