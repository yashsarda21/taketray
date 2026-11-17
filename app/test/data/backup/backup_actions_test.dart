import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/backup/backup_actions.dart';
import 'package:taketray/data/backup/backup_format.dart';
import 'package:taketray/data/backup/backup_service.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/copy_job_plan.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../support/fake_media_bridge.dart';
import '../media/media_harness.dart';

String _fixture() =>
    File('test/data/backup/fixtures/backup_v1.json').readAsStringSync();

/// Logs `importDecoded`, the point where the import's transaction starts.
class _LoggedService extends BackupService {
  // The service's own parameters are private (`_db`), so they cannot be
  // named alike here.
  // ignore: matching_super_parameters
  _LoggedService(super.db, super.clock, this.events);

  final List<String> events;

  @override
  Future<ImportSummary> importDecoded(BackupData data) {
    events.add('import');
    return super.importDecoded(data);
  }
}

/// An import that fails with something other than a bad file.
class _FailingService extends BackupService {
  // The service's own parameters are private (`_db`), so they cannot be
  // named alike here.
  // ignore: matching_super_parameters
  _FailingService(super.db, super.clock);

  @override
  Future<ImportSummary> importDecoded(BackupData data) =>
      Future.error(StateError('disk full'));
}

/// A verifier that logs, then answers [found].
class _LoggedVerifier extends MediaVerifier {
  _LoggedVerifier(MediaHarness h, this.events, {this.found = const {}})
    : super(h.bridge, h.clips, h.phoneState, h.queue, h.clock);

  final List<String> events;
  final Set<int> found;

  @override
  Future<VerifyOutcome> verifyAll() {
    events.add('verify');
    return Future.value(
      VerifyOutcome(found: found, missing: const {}, skipped: const {}),
    );
  }
}

/// Every row of every table, as text: the database "byte for byte".
Future<String> _everyRow(AppDatabase db) async => [
  for (final table in db.allTables)
    '${table.actualTableName}: ${await db.select(table).get()}',
].join('\n');

CopyJobPlan _plan() => CopyJobPlan(
  jobId: 'job-1',
  reelId: 1,
  editor: EditorApp.capcut,
  folderName: 'Goa',
  startedSession: true,
  items: const [(clipId: 1, fileName: 'a.mp4', sizeBytes: 10)],
);

Matcher _refused(BackupProblem problem) =>
    isA<ImportRefused>().having((r) => r.problem, 'problem', problem);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MediaHarness h;
  late List<String> events;
  late List<String> decoded;
  late BackupActions actions;

  /// The actions on [h]; [decode] replaces the isolate decoder.
  BackupActions build({
    MediaVerifier? verifier,
    BackupService? service,
    BackupDecoder? decode,
  }) => BackupActions(
    service ?? BackupService(h.db, h.clock),
    h.phoneState,
    h.queue,
    verifier ?? h.verifier,
    h.clock,
    h.db,
    decode ??
        (json) {
          decoded.add('decode');
          return decodeBackupInIsolate(json);
        },
  );

  setUp(() {
    h = MediaHarness(now: DateTime.utc(2026, 11, 17, 9));
    events = [];
    decoded = [];
    actions = build();
  });

  group('importJson', () {
    test('a good file: ImportDone with the summary, found and total', () async {
      final result = await build(
        verifier: _LoggedVerifier(h, events, found: {10, 11}),
      ).importJson(_fixture());

      expect(
        result,
        isA<ImportDone>()
            .having(
              (r) => r.summary,
              'summary',
              const ImportSummary(
                reels: 3,
                clips: 4,
                references: 4,
                inboxPending: 1,
                inboxSkipped: 1,
              ),
            )
            .having((r) => r.found, 'found', 2)
            .having((r) => r.total, 'total', 4),
      );
      expect(await h.db.select(h.db.clips).get(), hasLength(4));
    });

    test('a copy plan is saved: ImportBusyCopying, nothing read, database '
        'unchanged', () async {
      await ReelsRepository(h.db, h.clock).create('Goa');
      await h.phoneState.saveCopyJobPlan(_plan());
      final before = await _everyRow(h.db);
      final a = build(verifier: _LoggedVerifier(h, events));

      final result = await a.importJson(_fixture());

      expect(result, isA<ImportBusyCopying>());
      expect(decoded, isEmpty, reason: 'the file is not even read');
      expect(events, isEmpty, reason: 'no verify');
      expect(await _everyRow(h.db), before);
    });

    test(
      'not JSON: ImportRefused(notJson), database unchanged, no verify',
      () async {
        await ReelsRepository(h.db, h.clock).create('Goa');
        final before = await _everyRow(h.db);
        final a = build(verifier: _LoggedVerifier(h, events));

        expect(
          await a.importJson('this is not json'),
          _refused(BackupProblem.notJson),
        );

        expect(await _everyRow(h.db), before);
        expect(events, isEmpty);
      },
    );

    test('not a TakeTray file: ImportRefused(notTakeTray)', () async {
      expect(
        await actions.importJson('{"app":"Other","schemaVersion":1}'),
        _refused(BackupProblem.notTakeTray),
      );
    });

    test(
      'a newer version: ImportRefused(newerVersion), database unchanged',
      () async {
        await ReelsRepository(h.db, h.clock).create('Goa');
        final before = await _everyRow(h.db);
        final file = jsonDecode(_fixture()) as Map<String, dynamic>;
        file['schemaVersion'] = backupSchemaVersion + 1;

        expect(
          await actions.importJson(jsonEncode(file)),
          _refused(BackupProblem.newerVersion),
        );

        expect(await _everyRow(h.db), before);
      },
    );

    test('a constraint the checks missed: ImportRefused(invalidData), nothing '
        'changed, no verify', () async {
      await ReelsRepository(h.db, h.clock).create('Goa');
      await h.db.customStatement(
        'CREATE TRIGGER refuse_reels BEFORE INSERT ON reels '
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
      final before = await _everyRow(h.db);
      final a = build(verifier: _LoggedVerifier(h, events));

      expect(
        await a.importJson(_fixture()),
        _refused(BackupProblem.invalidData),
      );

      expect(await _everyRow(h.db), before);
      expect(events, isEmpty);
    });

    test('over 20 MB: ImportTooLarge, and the file is not decoded', () async {
      final before = await _everyRow(h.db);

      final result = await actions.importJson('x' * (maxImportCodeUnits + 1));

      expect(result, isA<ImportTooLarge>());
      expect(decoded, isEmpty);
      expect(await _everyRow(h.db), before);
    });

    test('exactly 20 MB is still read', () async {
      final result = await actions.importJson('x' * maxImportCodeUnits);

      expect(decoded, ['decode']);
      expect(result, _refused(BackupProblem.notJson));
    });

    test('the limit counts UTF-16 code units, not characters', () async {
      // Each emoji is two code units: half the limit of them is over it by 2.
      final text = '😀' * (maxImportCodeUnits ~/ 2 + 1);

      expect(await actions.importJson(text), isA<ImportTooLarge>());
      expect(decoded, isEmpty);
    });

    test('a scan queued first finishes before the import starts', () async {
      final gate = Completer<void>();
      final decodedGate = Completer<void>();
      final a = build(
        service: _LoggedService(h.db, h.clock, events),
        verifier: _LoggedVerifier(h, events),
        decode: (json) async {
          final data = await decodeBackupInIsolate(json);
          events.add('decoded');
          decodedGate.complete();
          return data;
        },
      );
      unawaited(
        h.queue.run(() async {
          events.add('scan start');
          await gate.future;
          events.add('scan end');
        }),
      );

      final result = a.importJson(_fixture());
      await decodedGate.future;
      await settle();
      // Decoded, and waiting: nothing of the import has touched the data.
      expect(events, ['scan start', 'decoded']);
      expect(await h.db.select(h.db.reels).get(), isEmpty);

      gate.complete();
      expect(await result, isA<ImportDone>());

      expect(events, ['scan start', 'decoded', 'scan end', 'import', 'verify']);
    });

    test(
      'the verify fails: ImportDone with found 0, the type is logged',
      () async {
        final logs = captureLogs();
        h.bridge.failNext('accessReport');

        final result = await actions.importJson(_fixture());

        expect(
          result,
          isA<ImportDone>()
              .having((r) => r.found, 'found', 0)
              .having((r) => r.total, 'total', 4),
        );
        final text = logs
            .map((r) => '${r.loggerName}: ${r.message}')
            .join('\n');
        expect(text, contains('PlatformException'));
        expect(text, isNot(contains('failed on purpose')));
        expect(await h.db.select(h.db.clips).get(), hasLength(4));
      },
    );

    test('a failure that is not a bad file reaches the caller, and no verify '
        'runs', () async {
      final a = build(
        service: _FailingService(h.db, h.clock),
        verifier: _LoggedVerifier(h, events),
      );

      await expectLater(a.importJson(_fixture()), throwsStateError);

      expect(events, isEmpty);
    });

    test(
      'imports through the real isolate decoder with no injected one',
      () async {
        final a = BackupActions(
          BackupService(h.db, h.clock),
          h.phoneState,
          h.queue,
          h.verifier,
          h.clock,
          h.db,
        );

        expect(await a.importJson(_fixture()), isA<ImportDone>());
      },
    );
  });

  group('exportJson and recordExport (ruling R1)', () {
    test('exportJson records nothing; recordExport records once', () async {
      final json = await actions.exportJson();

      expect(jsonDecode(json), isA<Map<String, dynamic>>());
      expect(await h.phoneState.lastExport(), isNull);

      await actions.recordExport();

      expect(await h.phoneState.lastExport(), h.clock.now());
    });

    test(
      'exportJson does not write the lastExport key into the file',
      () async {
        await actions.recordExport();

        final file = jsonDecode(await actions.exportJson()) as Map;

        expect((file['settings'] as Map).keys, isNot(contains('lastExport')));
      },
    );
  });

  group('hasCopies', () {
    test('false with no copy rows', () async {
      expect(await actions.hasCopies(), isFalse);
    });

    test('false with a session but no copy', () async {
      final reels = ReelsRepository(h.db, h.clock);
      final reel = await reels.create('Goa');
      await EditSessionsRepository(
        h.db,
        h.clock,
      ).startSession(reel.id, EditorApp.capcut, 'Goa');

      expect(await actions.hasCopies(), isFalse);
    });

    test('true with any copy row', () async {
      final reels = ReelsRepository(h.db, h.clock);
      final reel = await reels.create('Goa');
      final sessions = EditSessionsRepository(h.db, h.clock);
      await sessions.startSession(reel.id, EditorApp.capcut, 'Goa');
      await sessions.recordCopies([
        EditCopy(
          reelId: reel.id,
          clipId: 1,
          copyMediaStoreId: 9001,
          fileName: 'a.mp4',
          sizeBytes: 1,
          copiedAt: h.clock.now(),
        ),
      ]);

      expect(await actions.hasCopies(), isTrue);
    });
  });

  test('backupActionsProvider builds on the app providers', () async {
    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(h.db),
        clockProvider.overrideWithValue(h.clock),
        mediaBridgeProvider.overrideWithValue(FakeMediaBridge()),
      ],
    );

    expect(await container.read(backupActionsProvider).hasCopies(), isFalse);
  });
}
