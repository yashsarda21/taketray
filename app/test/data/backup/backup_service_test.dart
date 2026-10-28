import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show NativeDatabase, SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/backup/backup_format.dart';
import 'package:taketray/data/backup/backup_service.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/housekeeping.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/data/repositories/vn_repository.dart';
import 'package:taketray/data/repositories/zone_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/vn_copy.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 26, 9);
const Duration _minute = Duration(minutes: 1);

/// The committed, hand-written v1 file (read from the package root, where
/// `flutter test` runs).
String _fixture() =>
    File('test/data/backup/fixtures/backup_v1.json').readAsStringSync();

/// [_fixture] decoded, to be changed by a test and encoded again.
Map<String, dynamic> _fixtureMap() =>
    jsonDecode(_fixture()) as Map<String, dynamic>;

List<Map<String, dynamic>> _section(Map<String, dynamic> file, String key) =>
    (file[key] as List).cast<Map<String, dynamic>>();

/// The file with its `exportedAt` line removed, to compare two exports.
String _withoutExportedAt(String json) => json
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('"exportedAt"'))
    .join('\n');

NewClip _detected(int mediaStoreId, DateTime shotAt) => NewClip.mediaStore(
  mediaStoreId: mediaStoreId,
  volumeName: 'external_primary',
  fingerprint: ClipFingerprint(
    sizeBytes: 1000 + mediaStoreId,
    durationMs: 5000 + mediaStoreId,
    dateTakenUtc: shotAt,
    displayName: 'VID_$mediaStoreId.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  timeZoneId: 'Europe/London',
  generationAdded: mediaStoreId,
);

NewClip _picked(String uri) => NewClip.picker(
  pickerUri: uri,
  fingerprint: ClipFingerprint(
    sizeBytes: 2000,
    durationMs: 8000,
    dateTakenUtc: _t0.subtract(const Duration(days: 3)),
    displayName: 'friend.mp4',
  ),
  width: 0,
  height: 0,
  mimeType: 'video/mp4',
);

/// A database with every kind of row a backup can hold, plus the rows it must
/// leave out (a VN session with a copy, a phone-state setting).
class _Seeded {
  _Seeded(this.db, this.clock);

  final AppDatabase db;
  final FixedClock clock;

  late final ReelsRepository reels = ReelsRepository(db, clock);
  late final ClipsRepository clips = ClipsRepository(db, clock);
  late final ReferencesRepository references = ReferencesRepository(db, clock);
  late final VnRepository vn = VnRepository(db, clock);
  late final SettingsRepository settings = SettingsRepository(db, clock);
  late final ZoneRepository zones = ZoneRepository(db, clock);

  late int goa;
  late int london;

  Future<void> fill() async {
    goa = (await reels.create('  Goa 🌴  ', description: 'Beach week')).id;
    clock.advance(_minute);
    london = (await reels.create('London')).id;
    await reels.setStatus(london, ReelStatus.ready);
    clock.advance(_minute);

    final ids = await clips.addDetectedClips([
      _detected(1, _t0.subtract(const Duration(hours: 2))),
      _detected(2, _t0.subtract(const Duration(hours: 1))),
      _detected(3, _t0.subtract(const Duration(minutes: 30))),
    ]);
    final [shared, pending, skipped] = ids;
    clock.advance(_minute);
    await clips.tagClip(shared, {goa, london});
    await clips.skip([skipped]);
    clock.advance(_minute);
    final [picked] = await clips.addNewClipsToReel(london, [
      _picked('content://media/picker/0/x/media/42'),
    ]);
    clock.advance(_minute);
    await clips.recordVerification(found: {shared, pending}, missing: {picked});

    clock.advance(_minute);
    await references.add(
      goa,
      'https://instagram.com/reel/ABC123/?igsh=xyz',
      label: 'Slow pans',
    );
    clock.advance(_minute);
    await references.add(london, 'https://youtu.be/xyz');

    await vn.startSession(goa, 'Goa');
    await vn.addCopy(
      VnCopy(
        reelId: goa,
        clipId: shared,
        copyMediaStoreId: 9001,
        fileName: '20261026_0700_VID_1.mp4',
        sizeBytes: 1001,
      ),
    );

    await zones.record(_t0.subtract(const Duration(days: 30)), 'Asia/Kolkata');
    await zones.record(_t0.subtract(const Duration(days: 2)), 'Europe/London');

    await settings.save(
      const AppSettings(
        watchedFolders: ['DCIM/Camera', 'Movies/WhatsApp'],
        eveningReminderEnabled: false,
        eveningReminderMinutes: 1200,
      ),
    );
    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: 'shootingMode', value: 'true'));
  }
}

/// Every number, text and flag in a decoded JSON value, at any depth.
List<Object?> _leafValues(Object? json) => switch (json) {
  Map() => [for (final v in json.values) ..._leafValues(v)],
  List() => [for (final v in json) ..._leafValues(v)],
  _ => [json],
};

/// Every row of every table, VN and phone-state rows included, as text.
Future<String> _everyRow(AppDatabase db) async => [
  for (final table in db.allTables)
    '${table.actualTableName}: ${await db.select(table).get()}',
].join('\n');

Future<List<String>> _reelNames(AppDatabase db) async => [
  for (final reel in await ReelsRepository(
    db,
    FixedClock(_t0),
  ).watchAll().first)
    reel.name,
];

/// A [BackupException] with [problem], refused [where] in the file (`null`:
/// no place, as for every problem but `invalidData` and a constraint error).
Matcher _throwsProblem(BackupProblem problem, {String? where}) => throwsA(
  isA<BackupException>()
      .having((e) => e.problem, 'problem', problem)
      .having((e) => e.where, 'where', where),
);

void main() {
  // Some tests import into a second in-memory database. Each has its own
  // connection, so drift's "AppDatabase created more than once" warning (about
  // two databases sharing one connection) does not apply.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late FixedClock clock;
  late BackupService backup;

  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    clock = FixedClock(_t0);
    backup = BackupService(db, clock);
  });

  AppDatabase freshDatabase() {
    final other = testDatabase();
    addTearDown(other.close);
    return other;
  }

  group('export', () {
    test('writes the v1 keys in order, with a 2-space indent', () async {
      final json = await backup.exportJson();

      expect(
        json,
        startsWith('{\n  "app": "TakeTray",\n  "schemaVersion": 1,'),
      );
      final file = jsonDecode(json) as Map<String, dynamic>;
      expect(file.keys, [
        'app',
        'schemaVersion',
        'exportedAt',
        'reels',
        'references',
        'clips',
        'clipReels',
        'inbox',
        'settings',
        'zoneTimeline',
      ]);
      expect(file['exportedAt'], '2026-10-26T09:00:00.000Z');
    });

    test('times are UTC with milliseconds, never microseconds', () async {
      final json = await BackupService(
        db,
        FixedClock(DateTime.utc(2026, 10, 26, 9, 0, 0, 123, 456)),
      ).exportJson();

      expect(
        (jsonDecode(json) as Map)['exportedAt'],
        '2026-10-26T09:00:00.123Z',
      );
    });

    test('an empty database exports the default settings', () async {
      final file = jsonDecode(await backup.exportJson()) as Map;

      expect(file['reels'], isEmpty);
      expect(file['settings'], {
        'watchedFolders': ['DCIM/Camera'],
        'eveningReminderEnabled': true,
        'eveningReminderMinutes': 1260,
      });
    });

    test('leaves out VN sessions and phone-state settings', () async {
      await _Seeded(db, clock).fill();

      final file = jsonDecode(await backup.exportJson()) as Map;

      expect((file['settings'] as Map).keys, SettingsRepository.exportedKeys);
      // No value anywhere in the file comes from the VN session or its copy:
      // its folder ("Goa"), the copy's MediaStore id or its file name.
      final values = _leafValues(file);
      expect(values, isNot(contains(9001)));
      expect(values, isNot(contains('20261026_0700_VID_1.mp4')));
      expect(values, isNot(contains('Goa')));
      expect(values, contains('Goa 🌴'), reason: 'the reel itself is there');
    });
  });

  group('round trip', () {
    test(
      'export, import into a fresh database, export again: the same file',
      () async {
        final seeded = _Seeded(db, clock);
        await seeded.fill();
        final first = await backup.exportJson();

        final other = freshDatabase();
        final summary = await BackupService(other, clock).importJson(first);
        clock.advance(const Duration(hours: 1));
        final second = await BackupService(other, clock).exportJson();

        expect(second, isNot(first), reason: 'exportedAt moved');
        expect(_withoutExportedAt(second), _withoutExportedAt(first));
        expect(
          summary,
          const ImportSummary(
            reels: 2,
            clips: 4,
            references: 2,
            inboxPending: 1,
            inboxSkipped: 1,
          ),
        );
        expect(await other.select(other.vnSessions).get(), isEmpty);
        expect(await other.select(other.vnCopies).get(), isEmpty);
        expect(
          await SettingsRepository(other, clock).load(),
          const AppSettings(
            watchedFolders: ['DCIM/Camera', 'Movies/WhatsApp'],
            eveningReminderEnabled: false,
            eveningReminderMinutes: 1200,
          ),
        );
      },
    );

    test('dates outside 0000–9999 survive export and import', () async {
      // MediaStore dates come from file metadata, and garbage exists there.
      // `toIso8601String` writes such years as `+010001` or `-0001`; the file
      // must read them back, or one odd clip makes the backup unrestorable.
      final clips = ClipsRepository(db, clock);
      final ids = await clips.addDetectedClips([
        _detected(1, DateTime.utc(10001)),
        _detected(2, DateTime.utc(-1)),
        _detected(3, DateTime.utc(1904)),
        // The earliest instant a DateTime can hold.
        _detected(
          4,
          DateTime.fromMillisecondsSinceEpoch(-8640000000000000, isUtc: true),
        ),
      ]);
      // The latest one, as a lastVerifiedAt (a nullable time).
      await ClipsRepository(
        db,
        FixedClock(
          DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true),
        ),
      ).recordVerification(found: {ids[0]}, missing: {});
      final first = await backup.exportJson();

      expect(first, contains('"dateTakenUtc": "+010001-01-01T00:00:00.000Z"'));
      expect(first, contains('"dateTakenUtc": "-0001-01-01T00:00:00.000Z"'));
      expect(first, contains('"dateTakenUtc": "-271821-04-20T00:00:00.000Z"'));
      expect(
        first,
        contains('"lastVerifiedAt": "+275760-09-13T00:00:00.000Z"'),
      );

      final other = freshDatabase();
      final summary = await BackupService(other, clock).importJson(first);
      final second = await BackupService(other, clock).exportJson();

      expect(summary.clips, 4);
      expect(_withoutExportedAt(second), _withoutExportedAt(first));
    });

    test('every row comes back with its id and values', () async {
      await _Seeded(db, clock).fill();
      final json = await backup.exportJson();
      final before = await _everyRow(db);

      await backup.importJson(json);

      // Importing a database's own export changes nothing but the rows the
      // backup leaves out.
      final after = await _everyRow(db);
      String withoutLeftOut(String rows) => rows
          .split('\n')
          .where((l) => !l.startsWith('vn_') && !l.startsWith('settings'))
          .join('\n');
      expect(withoutLeftOut(after), withoutLeftOut(before));
    });
  });

  group('golden fixture (format v1)', () {
    test('uses every value of every stored enum, so each name is pinned', () {
      final file = _fixtureMap();
      Set<Object?> used(String section, String key) => {
        for (final row in _section(file, section)) row[key],
      };

      expect(used('reels', 'status'), {
        for (final v in ReelStatus.values) v.name,
      });
      expect(used('references', 'source'), {
        for (final v in ReferenceSource.values) v.name,
      });
      expect(used('clips', 'source'), {
        for (final v in ClipSource.values) v.name,
      });
      expect(used('inbox', 'state'), {
        for (final v in InboxState.values) v.name,
      });
    });

    test('imports with the expected summary', () async {
      final summary = await backup.importJson(_fixture());

      expect(
        summary,
        const ImportSummary(
          reels: 3,
          clips: 4,
          references: 4,
          inboxPending: 1,
          inboxSkipped: 1,
        ),
      );
    });

    test('exports back to the same file', () async {
      await backup.importJson(_fixture());

      expect(
        _withoutExportedAt(await backup.exportJson()),
        _withoutExportedAt(_fixture().trimRight()),
      );
    });

    test('keeps the ids and stored values', () async {
      await backup.importJson(_fixture());

      final reels = await ReelsRepository(db, clock).watchAll().first;
      expect(
        [for (final r in reels) (r.id, r.name, r.status)],
        [
          (3, 'Goa 🌴', ReelStatus.collecting),
          (7, 'London', ReelStatus.published),
          (9, 'Lisbon', ReelStatus.ready),
        ],
      );
      expect(reels.first.updatedAt, DateTime.utc(2026, 10, 25, 17, 30, 0, 123));
      final pending = await ClipsRepository(
        db,
        clock,
      ).watchInbox(InboxState.pending).first;
      expect([for (final c in pending) c.id], [11]);
      final inLondon = await ClipsRepository(db, clock).watchReelClips(7).first;
      expect([for (final c in inLondon) c.id], [14, 10]);
    });
  });

  group('a rejected file changes nothing (Review Focus 2)', () {
    late _Seeded seeded;
    late String rowsBefore;

    setUp(() async {
      seeded = _Seeded(db, clock);
      await seeded.fill();
      rowsBefore = await _everyRow(db);
    });

    Future<void> expectRejected(
      String json,
      BackupProblem problem, {
      String? where,
    }) async {
      await expectLater(
        backup.importJson(json),
        _throwsProblem(problem, where: where),
      );
      expect(await _reelNames(db), ['London', 'Goa 🌴']);
      expect(await _everyRow(db), rowsBefore);
    }

    test(
      'not JSON: notJson',
      () => expectRejected('nope', BackupProblem.notJson),
    );

    test(
      'an empty file: notJson',
      () => expectRejected('', BackupProblem.notJson),
    );

    test(
      'another app: notTakeTray',
      () => expectRejected('{"app":"Other"}', BackupProblem.notTakeTray),
    );

    for (final (name, json) in [
      ('a JSON list', '[1, 2]'),
      ('a JSON string', '"TakeTray"'),
      ('no app key', '{"schemaVersion": 1}'),
      ('no schemaVersion', '{"app": "TakeTray"}'),
      ('schemaVersion 0', '{"app": "TakeTray", "schemaVersion": 0}'),
      ('schemaVersion as text', '{"app": "TakeTray", "schemaVersion": "1"}'),
      ('schemaVersion 1.5', '{"app": "TakeTray", "schemaVersion": 1.5}'),
    ]) {
      test(
        '$name: notTakeTray',
        () => expectRejected(json, BackupProblem.notTakeTray),
      );
    }

    test('a file from a newer TakeTray: newerVersion', () async {
      final file = _fixtureMap()..['schemaVersion'] = 2;
      await expectRejected(jsonEncode(file), BackupProblem.newerVersion);
    });

    test(
      'newerVersion is reported before the contents are read',
      () => expectRejected(
        '{"app": "TakeTray", "schemaVersion": 7, "reels": "?"}',
        BackupProblem.newerVersion,
      ),
    );

    // Each entry breaks one rule in an otherwise valid file.
    final invalid =
        <String, (void Function(Map<String, dynamic>), {String where})>{
          'a clip–reel link to clip 999': (
            (f) => _section(f, 'clipReels').first['clipId'] = 999,
            where: 'clipReels[0].clipId',
          ),
          'a 41-character reel name': (
            (f) => _section(f, 'reels').first['name'] = 'a' * 41,
            where: 'reels[0].name',
          ),
          'a reel name of only spaces': (
            (f) => _section(f, 'reels').first['name'] = '   ',
            where: 'reels[0].name',
          ),
          'an unknown reel status': (
            (f) => _section(f, 'reels').first['status'] = 'archived',
            where: 'reels[0].status',
          ),
          'a reel id that is text': (
            (f) => _section(f, 'reels').first['id'] = '3',
            where: 'reels[0].id',
          ),
          'a reel id that is not whole': (
            (f) => _section(f, 'reels').first['id'] = 3.5,
            where: 'reels[0].id',
          ),
          'a reel id of 0': (
            (f) {
              _section(f, 'reels').first['id'] = 0;
              _section(f, 'references').first['reelId'] = 0;
              _section(f, 'clipReels').first['reelId'] = 0;
            },
            where: 'reels[0].id',
          ),
          'a clip id of 0': (
            (f) {
              _section(f, 'clips').first['id'] = 0;
              for (final link in _section(f, 'clipReels')) {
                if (link['clipId'] == 10) link['clipId'] = 0;
              }
            },
            where: 'clips[0].id',
          ),
          'a reference id of 0': (
            (f) => _section(f, 'references').first['id'] = 0,
            where: 'references[0].id',
          ),
          'a reel id beyond 2^53': (
            (f) {
              // Past SQLite's last id, every new row of the table would fail.
              _section(f, 'reels').first['id'] = 1 << 60;
              for (final row in [
                ..._section(f, 'references'),
                ..._section(f, 'clipReels'),
              ]) {
                if (row['reelId'] == 3) row['reelId'] = 1 << 60;
              }
            },
            where: 'reels[0].id',
          ),
          'two reels with the same id': (
            (f) => _section(f, 'reels').last['id'] = 3,
            where: 'reels[2].id',
          ),
          'a reel without a description key': (
            (f) => _section(f, 'reels').last.remove('description'),
            where: 'reels[2].description',
          ),
          'a missing section': ((f) => f.remove('clips'), where: 'clips'),
          'a section that is not a list': (
            (f) => f['reels'] = <String, dynamic>{},
            where: 'reels',
          ),
          'a row that is not an object': (
            (f) => (f['inbox'] as List).add(11),
            where: 'inbox[2]',
          ),
          'a reference to reel 999': (
            (f) => _section(f, 'references').first['reelId'] = 999,
            where: 'references[0].reelId',
          ),
          'a link to reel 999': (
            (f) => _section(f, 'clipReels').first['reelId'] = 999,
            where: 'clipReels[0].reelId',
          ),
          'the same link listed twice': (
            (f) => (f['clipReels'] as List).add(_section(f, 'clipReels').first),
            where: 'clipReels[3].reelId',
          ),
          'an inbox row for clip 999': (
            (f) => _section(f, 'inbox').first['clipId'] = 999,
            where: 'inbox[0].clipId',
          ),
          'two inbox rows for one clip': (
            (f) => _section(f, 'inbox').last['clipId'] = 11,
            where: 'inbox[1].clipId',
          ),
          'an unknown inbox state': (
            (f) => _section(f, 'inbox').first['state'] = 'later',
            where: 'inbox[0].state',
          ),
          'two references with the same id': (
            (f) => _section(f, 'references').last['id'] = 2,
            where: 'references[3].id',
          ),
          'a reference link that is not a web link': (
            (f) =>
                _section(f, 'references').first['url'] = 'ftp://example.com/x',
            where: 'references[0].url',
          ),
          'a 61-character label': (
            (f) => _section(f, 'references').first['label'] = 'b' * 61,
            where: 'references[0].label',
          ),
          'an unknown reference source': (
            (f) => _section(f, 'references').first['source'] = 'vimeo',
            where: 'references[0].source',
          ),
          'two clips with the same id': (
            (f) => _section(f, 'clips').last['id'] = 10,
            where: 'clips[3].id',
          ),
          'an unknown clip source': (
            (f) => _section(f, 'clips').first['source'] = 'camera',
            where: 'clips[0].source',
          ),
          'a detected clip without a volume': (
            (f) => _section(f, 'clips').first['volumeName'] = null,
            where: 'clips[0].volumeName',
          ),
          'a detected clip without a MediaStore id': (
            (f) => _section(f, 'clips').first['mediaStoreId'] = null,
            where: 'clips[0].mediaStoreId',
          ),
          'a picked clip without a picker link': (
            (f) => _section(f, 'clips').last['pickerUri'] = null,
            where: 'clips[3].pickerUri',
          ),
          'two clips with the same MediaStore identity': (
            (f) => _section(f, 'clips')[1]['mediaStoreId'] = 1001,
            where: 'clips[1].mediaStoreId',
          ),
          'two clips with the same picker link': (
            (f) {
              final copy = Map<String, dynamic>.of(_section(f, 'clips').last)
                ..['id'] = 15;
              (f['clips'] as List).add(copy);
              (f['clipReels'] as List).add({
                'clipId': 15,
                'reelId': 3,
                'addedAt': '2026-09-12T08:00:00.000Z',
              });
            },
            where: 'clips[4].pickerUri',
          ),
          '"missing" as a number': (
            (f) => _section(f, 'clips').first['missing'] = 0,
            where: 'clips[0].missing',
          ),
          'a size as text': (
            (f) => _section(f, 'clips').first['sizeBytes'] = '52428800',
            where: 'clips[0].sizeBytes',
          ),
          'a time without Z or an offset': (
            (f) => _section(f, 'clips').first['dateTakenUtc'] =
                '2026-10-22T06:10:05.250',
            where: 'clips[0].dateTakenUtc',
          ),
          'a date-only time': (
            (f) => _section(f, 'reels').first['createdAt'] = '2026-10-20',
            where: 'reels[0].createdAt',
          ),
          'a time that is not a real date': (
            (f) => _section(f, 'reels').first['createdAt'] =
                '2026-02-30T08:00:00.000Z',
            where: 'reels[0].createdAt',
          ),
          'a five-digit year': (
            (f) => _section(f, 'reels').first['createdAt'] =
                '+10001-01-01T00:00:00.000Z',
            where: 'reels[0].createdAt',
          ),
          'a year a date cannot hold': (
            (f) => _section(f, 'reels').first['createdAt'] =
                '+999999-01-01T00:00:00.000Z',
            where: 'reels[0].createdAt',
          ),
          'a time past the last instant a date can hold': (
            (f) => _section(f, 'reels').first['createdAt'] =
                '+275760-09-13T00:00:00.000-01:00',
            where: 'reels[0].createdAt',
          ),
          'a time as a number': (
            (f) => _section(f, 'inbox').first['addedAt'] = 1761462000000,
            where: 'inbox[0].addedAt',
          ),
          'no exportedAt': ((f) => f.remove('exportedAt'), where: 'exportedAt'),
          'settings that are not an object': (
            (f) => f['settings'] = <Object?>[],
            where: 'settings',
          ),
          'settings without a key': (
            (f) => (f['settings'] as Map).remove('eveningReminderEnabled'),
            where: 'settings.eveningReminderEnabled',
          ),
          'a watched folder that is not text': (
            (f) =>
                (f['settings'] as Map)['watchedFolders'] = ['DCIM/Camera', 3],
            where: 'settings.watchedFolders',
          ),
          'a reminder minute outside the day': (
            (f) => (f['settings'] as Map)['eveningReminderMinutes'] = 1440,
            where: 'settings.eveningReminderMinutes',
          ),
          'a negative reminder minute': (
            (f) => (f['settings'] as Map)['eveningReminderMinutes'] = -1,
            where: 'settings.eveningReminderMinutes',
          ),
          'two zone entries at the same moment': (
            (f) => (f['zoneTimeline'] as List).add({
              'at': '2026-09-01T01:00:00.000+01:00',
              'zoneId': 'Asia/Kolkata',
            }),
            where: 'zoneTimeline[2].at',
          ),
          'two zone entries in the same millisecond': (
            (f) => (f['zoneTimeline'] as List).add({
              'at': '2026-09-01T00:00:00.000400Z',
              'zoneId': 'Asia/Kolkata',
            }),
            where: 'zoneTimeline[2].at',
          ),
          'a negative size': (
            (f) => _section(f, 'clips').first['sizeBytes'] = -1,
            where: 'clips[0].sizeBytes',
          ),
          'a negative duration': (
            (f) => _section(f, 'clips').first['durationMs'] = -1,
            where: 'clips[0].durationMs',
          ),
          'a negative width': (
            (f) => _section(f, 'clips').first['width'] = -1,
            where: 'clips[0].width',
          ),
          'a negative height': (
            (f) => _section(f, 'clips').first['height'] = -1,
            where: 'clips[0].height',
          ),
          'a negative reel id': (
            (f) => _section(f, 'reels').first['id'] = -3,
            where: 'reels[0].id',
          ),
          'a zone id that is not text': (
            (f) => _section(f, 'zoneTimeline').first['zoneId'] = null,
            where: 'zoneTimeline[0].zoneId',
          ),
        };
    for (final MapEntry(key: name, value: (breakIt, :where))
        in invalid.entries) {
      test('$name: invalidData at $where', () async {
        final file = _fixtureMap();
        breakIt(file);
        await expectRejected(
          jsonEncode(file),
          BackupProblem.invalidData,
          where: where,
        );
      });
    }

    test('the fixture itself is accepted (so each case above breaks one '
        'rule)', () async {
      await backup.importJson(_fixture());
      expect(await _reelNames(db), ['Goa 🌴', 'London', 'Lisbon']);
    });
  });

  group('import', () {
    test("replaces everything: only the backup's rows remain", () async {
      final seeded = _Seeded(db, clock);
      await seeded.fill();

      await backup.importJson(_fixture());

      expect(await _reelNames(db), ['Goa 🌴', 'London', 'Lisbon']);
      final reels = await db.select(db.reels).get();
      expect([for (final r in reels) r.id], unorderedEquals([3, 7, 9]));
      expect(await db.select(db.clips).get(), hasLength(4));
      expect(await db.select(db.vnSessions).get(), isEmpty);
      expect(await db.select(db.vnCopies).get(), isEmpty);
      final keys = [for (final s in await db.select(db.settings).get()) s.key];
      expect(keys, unorderedEquals(SettingsRepository.exportedKeys));
      final zones = await ZoneRepository(db, clock).all();
      expect(
        [for (final z in zones) z.zoneId],
        ['Europe/London', 'Asia/Kolkata'],
      );
    });

    test('watchAll emits the imported reels', () async {
      await _Seeded(db, clock).fill();
      final emitted = <List<int>>[];
      final sub = ReelsRepository(db, clock).watchAll().listen(
        (reels) => emitted.add([for (final r in reels) r.id]),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      final before = emitted.last;

      await backup.importJson(_fixture());
      await pumpEventQueue();

      expect(before, hasLength(2));
      expect(emitted.last, [3, 7, 9], reason: 'newest updatedAt first');
    });

    test('an empty backup empties the database', () async {
      await _Seeded(db, clock).fill();
      final empty = await BackupService(freshDatabase(), clock).exportJson();

      final summary = await backup.importJson(empty);

      expect(
        summary,
        const ImportSummary(
          reels: 0,
          clips: 0,
          references: 0,
          inboxPending: 0,
          inboxSkipped: 0,
        ),
      );
      for (final table in db.allTables) {
        if (table.actualTableName == 'settings') continue;
        expect(
          await db.select(table).get(),
          isEmpty,
          reason: table.actualTableName,
        );
      }
      expect(await SettingsRepository(db, clock).load(), const AppSettings());
    });

    test('new rows after an import never reuse an imported id', () async {
      await backup.importJson(_fixture());

      final reel = await ReelsRepository(db, clock).create('Next');
      final [clip] = await ClipsRepository(
        db,
        clock,
      ).addDetectedClips([_detected(5000, _t0)]);
      final added = await ReferencesRepository(
        db,
        clock,
      ).add(reel.id, 'https://example.com/a');

      expect(reel.id, greaterThan(9));
      expect(clip, greaterThan(14));
      expect((added as ReferenceAdded).reference.id, greaterThan(8));
    });

    test('an id of 2^53 is accepted, and new rows go above it', () async {
      final file = _fixtureMap();
      _section(file, 'clips').first['id'] = 1 << 53;
      for (final link in _section(file, 'clipReels')) {
        if (link['clipId'] == 10) link['clipId'] = 1 << 53;
      }

      await backup.importJson(jsonEncode(file));
      final [clip] = await ClipsRepository(
        db,
        clock,
      ).addDetectedClips([_detected(5000, _t0)]);

      expect(await ClipsRepository(db, clock).watchReelIdsOf(1 << 53).first, {
        3,
        7,
      });
      expect(clip, (1 << 53) + 1);
    });

    test('an import never lowers the id counters', () async {
      // This database has handed out clip ids up to 500. The import itself
      // may reuse lower ids (it deletes every row that could name an old
      // clip, D-54), but rows added afterwards must not go below the counter.
      await db.customStatement(
        "INSERT INTO sqlite_sequence (name, seq) VALUES ('clips', 500)",
      );

      await backup.importJson(_fixture());
      final [clip] = await ClipsRepository(
        db,
        clock,
      ).addDetectedClips([_detected(5000, _t0)]);

      expect(clip, greaterThan(500));
    });

    test(
      'a time with an offset is stored as the same instant in UTC',
      () async {
        final file = _fixtureMap();
        _section(file, 'reels').first['createdAt'] =
            '2026-10-20T13:30:00.000+05:30';

        await backup.importJson(jsonEncode(file));

        final goa = await ReelsRepository(db, clock).getById(3);
        expect(goa!.createdAt, DateTime.utc(2026, 10, 20, 8));
        expect(goa.createdAt.isUtc, isTrue);
      },
    );

    test(
      'unknown keys are ignored, so a later format can add fields',
      () async {
        final file = _fixtureMap()..['addedLater'] = {'anything': true};
        _section(file, 'reels').first['colour'] = 'teal';
        _section(file, 'clips').first['rating'] = 5;
        (file['settings'] as Map)['darkMode'] = true;

        final summary = await backup.importJson(jsonEncode(file));

        expect(summary.reels, 3);
        expect(
          await db.select(db.settings).get(),
          hasLength(SettingsRepository.exportedKeys.length),
        );
      },
    );

    test('text is stored the way the app stores it', () async {
      final file = _fixtureMap();
      _section(file, 'reels').first['name'] = '  Goa 🌴  ';
      _section(file, 'reels').first['description'] = '   ';
      _section(file, 'references').first['url'] =
          'https://instagram.com/reel/ABC123/?igsh=abc';
      _section(file, 'references').first['label'] = '  Slow pans ';
      _section(file, 'references').last['label'] = '  ';

      await backup.importJson(jsonEncode(file));

      final goa = (await ReelsRepository(db, clock).getById(3))!;
      expect(goa.name, 'Goa 🌴');
      expect(goa.description, isNull);
      final refs = await db.select(db.reelReferences).get();
      expect(refs.first.url, 'https://www.instagram.com/p/ABC123/');
      expect(refs.first.label, 'Slow pans');
      expect(refs.last.label, isNull);
    });

    test('a 40-emoji reel name is accepted', () async {
      final file = _fixtureMap();
      _section(file, 'reels').first['name'] = '🌴' * 40;

      await backup.importJson(jsonEncode(file));

      expect((await ReelsRepository(db, clock).getById(3))!.name, '🌴' * 40);
    });
  });

  group('states the app never makes are brought back to its rules', () {
    test('a clip in a reel and in To tag keeps only its link', () async {
      final file = _fixtureMap();
      // Clip 10 is in reels 3 and 7; the file also lists it as pending.
      (file['inbox'] as List).add({
        'clipId': 10,
        'state': 'pending',
        'addedAt': '2026-10-22T06:12:00.000Z',
      });

      final summary = await backup.importJson(jsonEncode(file));

      expect(summary.inboxPending, 1);
      final inbox = await db.select(db.inbox).get();
      expect([for (final i in inbox) i.clipId], unorderedEquals([11, 12]));
      expect(await ClipsRepository(db, clock).watchReelIdsOf(10).first, {3, 7});
    });

    test('a clip in no reel and no list is left out', () async {
      final file = _fixtureMap();
      final orphan = Map<String, dynamic>.of(_section(file, 'clips')[1])
        ..['id'] = 20
        ..['mediaStoreId'] = 2020;
      (file['clips'] as List).add(orphan);

      final summary = await backup.importJson(jsonEncode(file));

      expect(summary.clips, 4);
      final clips = await db.select(db.clips).get();
      expect([for (final c in clips) c.id], unorderedEquals([10, 11, 12, 14]));
      expect(await db.deleteOrphanClips(), 0, reason: 'same rule as D-56');
    });

    test(
      'the same page twice on one reel keeps the reference with the lower id',
      () async {
        // Reference 2 is reel 3's Instagram reel. Two more rows name the same
        // page once the link is cleaned: possible after a later version
        // cleans links differently (D-55), so the file is not refused.
        final file = _fixtureMap();
        Map<String, dynamic> samePage(int id, String url, String label) =>
            Map<String, dynamic>.of(_section(file, 'references').first)
              ..['id'] = id
              ..['url'] = url
              ..['label'] = label;
        (file['references'] as List)
          ..add(
            samePage(9, 'https://instagram.com/reel/ABC123?igsh=x', 'Later'),
          )
          ..add(samePage(1, 'http://instagr.am/p/ABC123', 'Earliest'));
        final records = <LogRecord>[];
        final sub = Logger('backup').onRecord.listen(records.add);
        addTearDown(sub.cancel);

        final summary = await backup.importJson(jsonEncode(file));

        expect(summary.references, 4);
        final refs = await (db.select(
          db.reelReferences,
        )..where((r) => r.reelId.equals(3))).get();
        expect(
          {for (final r in refs) r.id: (r.url, r.label)},
          {
            1: ('https://www.instagram.com/p/ABC123/', 'Earliest'),
            8: ('https://example.com/lighting-guide?part=2', null),
          },
        );
        expect(records.last.message, endsWith('and 2 duplicate references'));
      },
    );

    test('a pending clip that is also in a reel stays, in the reel', () async {
      final file = _fixtureMap();
      // Clip 11 (pending) is also linked to reel 9: the link wins, and the
      // clip is kept.
      (file['clipReels'] as List).add({
        'clipId': 11,
        'reelId': 9,
        'addedAt': '2026-10-22T07:00:00.000Z',
      });

      final summary = await backup.importJson(jsonEncode(file));

      expect(summary.clips, 4);
      expect(summary.inboxPending, 0);
      expect(summary.inboxSkipped, 1);
    });
  });

  test(
    'a constraint the checks missed is invalidData and changes nothing',
    () async {
      await _Seeded(db, clock).fill();
      // Stands in for any rule the Dart checks might miss: the database
      // refuses the backup's reels partway through the replace.
      await db.customStatement(
        'CREATE TRIGGER refuse_reels BEFORE INSERT ON reels '
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
      final rowsBefore = await _everyRow(db);

      await expectLater(
        backup.importJson(_fixture()),
        _throwsProblem(BackupProblem.invalidData),
      );

      expect(await _everyRow(db), rowsBefore);
      expect(await _reelNames(db), ['London', 'Goa 🌴']);
    },
  );

  group('database errors during the replace', () {
    /// A database on drift's background isolate, as on the phone
    /// (drift_flutter), in a file that is deleted after the test.
    AppDatabase backgroundDatabase() {
      final dir = Directory.systemTemp.createTempSync('taketray_backup_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final other = AppDatabase(
        NativeDatabase.createInBackground(File('${dir.path}/t.sqlite')),
      );
      addTearDown(other.close);
      return other;
    }

    Future<void> refuseReels(AppDatabase target) => target.customStatement(
      'CREATE TRIGGER refuse_reels BEFORE INSERT ON reels '
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );

    test('a constraint error from the background isolate is still '
        'invalidData and changes nothing', () async {
      final target = backgroundDatabase();
      await _Seeded(target, clock).fill();
      await refuseReels(target);
      final rowsBefore = await _everyRow(target);

      await expectLater(
        BackupService(target, clock).importJson(_fixture()),
        _throwsProblem(BackupProblem.invalidData),
      );

      expect(await _everyRow(target), rowsBefore);
    });

    test('a non-constraint error is rethrown as it is and changes '
        'nothing', () async {
      await _Seeded(db, clock).fill();
      final rowsBefore = await _everyRow(db);
      await db.customStatement('PRAGMA query_only = ON');

      await expectLater(
        backup.importJson(_fixture()),
        throwsA(isA<SqliteException>().having((e) => e.resultCode, 'code', 8)),
        reason: 'SQLITE_READONLY is not a broken backup',
      );

      expect(await _everyRow(db), rowsBefore);
    });

    test('a non-constraint error from the background isolate is rethrown '
        'as it is and changes nothing', () async {
      final target = backgroundDatabase();
      await _Seeded(target, clock).fill();
      final rowsBefore = await _everyRow(target);
      await target.customStatement('PRAGMA query_only = ON');

      await expectLater(
        BackupService(target, clock).importJson(_fixture()),
        throwsA(
          isA<DriftRemoteException>().having(
            (e) => e.remoteCause,
            'remoteCause',
            isA<SqliteException>().having((e) => e.resultCode, 'code', 8),
          ),
        ),
      );

      expect(await _everyRow(target), rowsBefore);
    });
  });

  test('every repository logs ids and counts only (D-10)', () async {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);
    final seeded = _Seeded(db, clock);

    // Every kind of write, with the user's text in it: the fill (names,
    // descriptions, links, labels, file names, folders, zones), then edits,
    // removals and deletes.
    await seeded.fill();
    await seeded.reels.rename(seeded.london, 'Secret London trip');
    await seeded.reels.setDescription(seeded.goa, 'Secret beach plan');
    final ref = await seeded.references.add(
      seeded.goa,
      'https://secret.example/clip',
      label: 'Secret label',
    );
    final refId = (ref as ReferenceAdded).reference.id;
    await seeded.references.setLabel(refId, 'Secret relabel');
    await seeded.references.delete(refId);
    await seeded.clips.removeClipsFromReel(seeded.london, [
      ...(await db.select(db.clipReels).get()).map((l) => l.clipId),
    ]);
    await seeded.vn.endSession(seeded.goa);
    await expectLater(
      seeded.vn.startSession(seeded.goa, ' \u200B '),
      throwsArgumentError,
    );
    await seeded.vn.startSession(seeded.london, 'Secret folder');
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: SettingsRepository.watchedFoldersKey,
            value: '["DCIM/Secret", 3]',
          ),
        );
    await seeded.settings.load();
    await seeded.reels.delete(seeded.goa);

    expect(
      {for (final r in records) r.loggerName},
      containsAll(['reels', 'clips', 'references', 'vn', 'zones', 'settings']),
      reason: 'every repository logged something',
    );
    // The raw message, not `formatRecord`: that redacts paths and URIs, which
    // would hide a leak instead of catching it.
    final lines = records.map((r) => r.message).join('\n');
    for (final secret in [
      'Goa',
      'London',
      'Secret',
      'Beach',
      'instagram',
      'ABC123',
      'youtu',
      'example',
      'Slow pans',
      'VID_',
      'friend.mp4',
      'content://',
      'DCIM',
      'WhatsApp',
      'Kolkata',
      '20261026_0700',
    ]) {
      expect(lines, isNot(contains(secret)), reason: secret);
    }
  });

  test('logs counts only: no names, links, labels or file names', () async {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);
    await _Seeded(db, clock).fill();
    records.clear();

    final json = await backup.exportJson();
    await backup.importJson(json);
    final broken = _fixtureMap();
    _section(broken, 'reels').first['name'] = 'Secret trip ${'x' * 40}';
    await expectLater(
      backup.importJson(jsonEncode(broken)),
      _throwsProblem(BackupProblem.invalidData, where: 'reels[0].name'),
    );

    final backupLines = [
      for (final r in records)
        if (r.loggerName == 'backup') r.message,
    ];
    expect(backupLines, hasLength(3));
    final lines = backupLines.join('\n');
    for (final secret in [
      'Goa',
      'London',
      'Secret',
      'instagram',
      'youtu',
      'Slow pans',
      'VID_',
      'friend.mp4',
      'content://',
      'DCIM',
    ]) {
      expect(lines, isNot(contains(secret)));
    }
  });
}
