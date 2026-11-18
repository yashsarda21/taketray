import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/backup/backup_actions.dart';
import 'package:taketray/data/backup/backup_format.dart';
import 'package:taketray/features/settings/view_models/backup_controller.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/platform/files_bridge.dart';

import '../../../support/fake_backup_actions.dart';
import '../../../support/fake_files_bridge.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/vm_harness.dart';

const List<String> _mimeTypes = ['application/json', 'text/plain', '*/*'];
const int _twentyMb = 20 * 1024 * 1024;

/// A controller on fakes: `actions`, `files`, a clock at `now` and a stored
/// backup date that a successful `recordExport` moves to the clock's time.
class _Rig {
  _Rig({DateTime? now, DateTime? lastExport})
    : clock = FixedClock(now ?? DateTime.utc(2026, 11, 17, 9)),
      stored = lastExport {
    actions.onRecord = () => stored = clock.now();
    container = ProviderContainer.test(
      overrides: [
        backupActionsProvider.overrideWithValue(actions),
        filesBridgeProvider.overrideWithValue(files),
        clockProvider.overrideWithValue(clock),
        lastExportProvider.overrideWith((ref) async {
          lastExportReads++;
          return stored;
        }),
      ],
    );
    // The screen listens while it is open.
    subscription = container.listen(backupControllerProvider, (_, _) {});
  }

  final FakeBackupActions actions = FakeBackupActions();
  final FakeFilesBridge files = FakeFilesBridge();
  final FixedClock clock;
  DateTime? stored;
  int lastExportReads = 0;
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<BackupState>> subscription;

  BackupController get controller =>
      container.read(backupControllerProvider.notifier);

  BackupState? get state => container.read(backupControllerProvider).value;

  Future<BackupState> loaded() =>
      container.read(backupControllerProvider.future);
}

String _fixture() =>
    File('test/data/backup/fixtures/backup_v1.json').readAsStringSync();

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('the state', () {
    test('starts with the stored backup date and not busy', () async {
      final rig = _Rig(lastExport: DateTime.utc(2026, 11, 12, 8));

      final state = await rig.loaded();

      expect(state.lastExport, DateTime.utc(2026, 11, 12, 8));
      expect(state.busy, isFalse);
      expect(state.job, isNull);
    });

    test('no backup yet: lastExport is null', () async {
      final rig = _Rig();

      expect((await rig.loaded()).lastExport, isNull);
    });
  });

  group('export', () {
    test('saved: the backup text is saved as JSON under the dated name, then '
        'recorded once, and the date is read again', () async {
      final rig = _Rig(now: DateTime(2026, 11, 17, 14, 30));
      await rig.loaded();
      var savesWhenRecorded = -1;
      rig.actions.onRecord = () {
        savesWhenRecorded = rig.files.saved.length;
        rig.stored = rig.clock.now();
      };

      final outcome = await rig.controller.export();

      expect(outcome, ExportOutcome.saved);
      expect(rig.actions.log, ['exportJson', 'recordExport']);
      expect(rig.files.methods, ['saveDocument']);
      expect(rig.files.calls.single.args, [
        'taketray-backup-2026-11-17.json',
        'application/json',
        rig.actions.exportText,
      ]);
      expect(savesWhenRecorded, 1, reason: 'recorded only after the save');
      expect(rig.actions.records, 1);
      // The date is read again as Riverpod rebuilds what depends on it.
      await pumpEventQueue();
      await rig.loaded();
      expect(rig.state!.lastExport, rig.clock.now());
      expect(rig.state!.busy, isFalse);
    });

    test('saved: the Settings row is told to read its date again', () async {
      final rig = _Rig();
      // The row listens to the date too.
      final row = rig.container.listen(lastExportProvider, (_, _) {});
      await rig.container.read(lastExportProvider.future);
      final before = rig.lastExportReads;

      await rig.controller.export();

      expect(
        await rig.container.read(lastExportProvider.future),
        rig.clock.now(),
      );
      expect(rig.lastExportReads, greaterThan(before));
      row.close();
    });

    test('cancelled: nothing is recorded and the date stays', () async {
      final rig = _Rig(lastExport: DateTime.utc(2026, 11, 12, 8));
      await rig.loaded();
      rig.files.saveAnswer = null;

      final outcome = await rig.controller.export();

      expect(outcome, ExportOutcome.cancelled);
      expect(rig.actions.log, ['exportJson']);
      expect(rig.actions.records, 0);
      expect(rig.stored, DateTime.utc(2026, 11, 12, 8));
      expect(rig.state!.lastExport, DateTime.utc(2026, 11, 12, 8));
      expect(rig.state!.busy, isFalse);
    });

    test('the save fails: failed, nothing recorded, not busy', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.failNext('saveDocument');

      final outcome = await rig.controller.export();

      expect(outcome, ExportOutcome.failed);
      expect(rig.actions.log, ['exportJson']);
      expect(rig.actions.records, 0);
      expect(rig.state!.busy, isFalse);
    });

    test(
      'the backup text cannot be made: failed, the picker never opens',
      () async {
        final rig = _Rig();
        await rig.loaded();
        rig.actions.exportError = StateError('database closed');

        final outcome = await rig.controller.export();

        expect(outcome, ExportOutcome.failed);
        expect(rig.files.calls, isEmpty);
        expect(rig.actions.records, 0);
        expect(rig.state!.busy, isFalse);
      },
    );

    test(
      'the file is saved but recording the date fails: still saved',
      () async {
        final rig = _Rig();
        await rig.loaded();
        rig.actions.recordError = StateError('database closed');

        final outcome = await rig.controller.export();

        expect(outcome, ExportOutcome.saved);
        expect(rig.files.saved, hasLength(1));
        expect(rig.state!.busy, isFalse);
      },
    );

    test('busy while the picker is open, and only then', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.hold('saveDocument');

      final running = rig.controller.export();
      await pumpEventQueue();
      expect(rig.state!.busy, isTrue);
      expect(rig.state!.job, BackupJob.exporting);

      rig.files.release('saveDocument');
      await running;
      expect(rig.state!.busy, isFalse);
      expect(rig.state!.job, isNull);
    });

    group('the file name is the local date', () {
      for (final (now, name) in [
        (DateTime(2026, 11, 17, 23, 59), 'taketray-backup-2026-11-17.json'),
        (DateTime(2026, 11, 18, 0, 1), 'taketray-backup-2026-11-18.json'),
        (DateTime(2026, 12, 31, 23, 59), 'taketray-backup-2026-12-31.json'),
        (DateTime(2027, 1, 1, 0, 1), 'taketray-backup-2027-01-01.json'),
        (DateTime(2027, 3, 5, 12), 'taketray-backup-2027-03-05.json'),
        // Summer time in London (tool/check runs this file there too): 00:01
        // is 23:01 the day before in UTC.
        (DateTime(2026, 6, 30, 23, 59), 'taketray-backup-2026-06-30.json'),
        (DateTime(2026, 7, 1, 0, 1), 'taketray-backup-2026-07-01.json'),
      ]) {
        test('${now.toIso8601String()} local: $name', () async {
          final rig = _Rig(now: now);
          await rig.loaded();

          await rig.controller.export();

          expect(rig.files.calls.single.args.first, name);
        });
      }

      test('backupFileName reads the instant in the local zone', () {
        // 00:01 local is the day before in UTC east of Greenwich, and 23:59
        // local is the day after west of it: the local date wins either way.
        final early = DateTime(2026, 11, 18, 0, 1).toUtc();
        final late = DateTime(2026, 11, 17, 23, 59).toUtc();
        expect(backupFileName(early), 'taketray-backup-2026-11-18.json');
        expect(backupFileName(late), 'taketray-backup-2026-11-17.json');
      });
    });
  });

  group('importFrom', () {
    test(
      'opens JSON, text or any file up to 20 MB, and imports its text',
      () async {
        final rig = _Rig();
        await rig.loaded();
        rig.files.openAnswer = '{"the":"file"}';

        final result = await rig.controller.importFrom();

        expect(result, same(rig.actions.importAnswer));
        expect(rig.files.methods, ['openDocument']);
        expect(rig.files.calls.single.args, [_mimeTypes, _twentyMb]);
        expect(rig.actions.imported, ['{"the":"file"}']);
        expect(rig.state!.busy, isFalse);
      },
    );

    test('the picker is cancelled: null, nothing imported', () async {
      final rig = _Rig();
      await rig.loaded();

      final result = await rig.controller.importFrom();

      expect(result, isNull);
      expect(rig.actions.log, isEmpty);
      expect(rig.state!.busy, isFalse);
    });

    test('the file is over 20 MB at the picker: ImportTooLarge, nothing '
        'imported', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.failNext('openDocument', FilesProblem.tooLarge);

      final result = await rig.controller.importFrom();

      expect(result, isA<ImportTooLarge>());
      expect(rig.actions.log, isEmpty);
      expect(rig.state!.busy, isFalse);
    });

    for (final answer in <ImportResult>[
      const ImportDone(fakeImportSummary, 0, 4),
      const ImportBusyCopying(),
      const ImportTooLarge(),
      for (final p in BackupProblem.values) ImportRefused(p),
    ]) {
      test(
        'the import answers ${answer.runtimeType}: passed on as it is',
        () async {
          final rig = _Rig();
          await rig.loaded();
          rig.files.openAnswer = '{}';
          rig.actions.importAnswer = answer;

          expect(await rig.controller.importFrom(), same(answer));
        },
      );
    }

    test('the picker fails (Android gone, busy): the error reaches the '
        'caller, nothing imported, not busy', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.failNext('openDocument');

      await expectLater(
        rig.controller.importFrom(),
        throwsA(
          isA<FileBridgeException>().having(
            (e) => e.problem,
            'problem',
            FilesProblem.failed,
          ),
        ),
      );
      expect(rig.actions.log, isEmpty);
      expect(rig.state!.busy, isFalse);
    });

    test('the import fails with something that is not a bad file: the error '
        'reaches the caller, not busy', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.openAnswer = '{}';
      rig.actions.importError = StateError('disk full');

      await expectLater(rig.controller.importFrom(), throwsStateError);
      expect(rig.state!.busy, isFalse);
    });

    test('an import never records a backup', () async {
      final rig = _Rig(lastExport: DateTime.utc(2026, 11, 12, 8));
      await rig.loaded();
      rig.files.openAnswer = '{}';

      await rig.controller.importFrom();

      expect(rig.actions.records, 0);
      expect(rig.state!.lastExport, DateTime.utc(2026, 11, 12, 8));
    });

    test('busy while the picker is open and while the import runs', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.openAnswer = '{}';
      rig.files.hold('openDocument');
      rig.actions.holdImport();

      final running = rig.controller.importFrom();
      await pumpEventQueue();
      expect(rig.state!.job, BackupJob.importing);

      rig.files.release('openDocument');
      await pumpEventQueue();
      expect(rig.actions.log, ['importJson']);
      expect(rig.state!.job, BackupJob.importing);

      rig.actions.releaseImport();
      await running;
      expect(rig.state!.busy, isFalse);
    });
  });

  group('one job at a time', () {
    test('a second export while one runs does nothing', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.hold('saveDocument');

      final first = rig.controller.export();
      final second = rig.controller.export();
      await pumpEventQueue();

      expect(await second, ExportOutcome.cancelled);
      expect(rig.files.methods, ['saveDocument']);
      rig.files.release('saveDocument');
      expect(await first, ExportOutcome.saved);
      expect(rig.actions.log, ['exportJson', 'recordExport']);
    });

    test('a second import while one runs does nothing', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.openAnswer = '{}';
      rig.files.hold('openDocument');

      final first = rig.controller.importFrom();
      final second = rig.controller.importFrom();
      await pumpEventQueue();

      expect(await second, isNull);
      expect(rig.files.methods, ['openDocument']);
      rig.files.release('openDocument');
      await first;
      expect(rig.actions.imported, hasLength(1));
    });

    test('an export while an import runs does nothing, and the other way '
        'round', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.openAnswer = '{}';
      rig.actions.holdImport();

      final import = rig.controller.importFrom();
      await pumpEventQueue();
      expect(await rig.controller.export(), ExportOutcome.cancelled);
      expect(rig.files.methods, ['openDocument']);
      rig.actions.releaseImport();
      await import;

      rig.files.hold('saveDocument');
      final export = rig.controller.export();
      await pumpEventQueue();
      expect(await rig.controller.importFrom(), isNull);
      expect(rig.files.methods, ['openDocument', 'saveDocument']);
      rig.files.release('saveDocument');
      await export;
    });

    test('a job goes on after the screen is left, and coming back while it '
        'runs does not start another', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.hold('saveDocument');

      final first = rig.controller.export();
      await pumpEventQueue();
      rig.subscription.close();
      await pumpEventQueue();

      // The screen is opened again.
      rig.container.listen(backupControllerProvider, (_, _) {});
      await rig.loaded();
      expect(rig.state!.busy, isTrue);
      expect(await rig.controller.export(), ExportOutcome.cancelled);
      expect(rig.files.methods, ['saveDocument']);

      rig.files.release('saveDocument');
      expect(await first, ExportOutcome.saved);
      expect(rig.state!.busy, isFalse);
    });

    test('after a failed job the next one runs', () async {
      final rig = _Rig();
      await rig.loaded();
      rig.files.failNext('saveDocument');
      rig.files.failNext('openDocument');

      expect(await rig.controller.export(), ExportOutcome.failed);
      await expectLater(
        rig.controller.importFrom(),
        throwsA(isA<FileBridgeException>()),
      );
      expect(await rig.controller.export(), ExportOutcome.saved);
    });
  });

  group('hasCopies', () {
    test('passes on the answer', () async {
      final rig = _Rig();
      expect(await rig.controller.hasCopies(), isFalse);
      rig.actions.copies = true;
      expect(await rig.controller.hasCopies(), isTrue);
    });

    test('a failed read says yes, so the warning is not left out', () async {
      final rig = _Rig()..actions.copiesError = StateError('database closed');

      expect(await rig.controller.hasCopies(), isTrue);
    });
  });

  group('on a real database', () {
    test('an export saves a backup of the database and records it', () async {
      final h = VmHarness(now: DateTime.utc(2026, 11, 17, 9));
      final sub = h.container.listen(backupControllerProvider, (_, _) {});
      await h.container.read(backupControllerProvider.future);

      final outcome = await h.container
          .read(backupControllerProvider.notifier)
          .export();

      expect(outcome, ExportOutcome.saved);
      final text = h.files.saved.single.text;
      expect(decodeBackup(text), isA<BackupData>());
      expect(
        (jsonDecode(text) as Map<String, Object?>)['schemaVersion'],
        backupSchemaVersion,
      );
      expect(
        await h.media.phoneState.lastExport(),
        DateTime.utc(2026, 11, 17, 9),
      );
      await h.container.read(backupControllerProvider.future);
      expect(
        h.container.read(backupControllerProvider).value!.lastExport,
        DateTime.utc(2026, 11, 17, 9),
      );
      sub.close();
    });

    test('a cancelled export records nothing', () async {
      final h = VmHarness(now: DateTime.utc(2026, 11, 17, 9));
      h.files.saveAnswer = null;
      final sub = h.container.listen(backupControllerProvider, (_, _) {});

      await h.container.read(backupControllerProvider.notifier).export();

      expect(await h.media.phoneState.lastExport(), isNull);
      sub.close();
    });

    test('an import of a good file: ImportDone with every clip of the '
        'backup', () async {
      final h = VmHarness(now: DateTime.utc(2026, 11, 17, 9));
      h.files.openAnswer = _fixture();
      final sub = h.container.listen(backupControllerProvider, (_, _) {});

      final result = await h.container
          .read(backupControllerProvider.notifier)
          .importFrom();

      expect(result, isA<ImportDone>().having((r) => r.total, 'total', 4));
      sub.close();
    });

    test('an import of a file that is not a backup: refused', () async {
      final h = VmHarness(now: DateTime.utc(2026, 11, 17, 9));
      h.files.openAnswer = 'not json';
      final sub = h.container.listen(backupControllerProvider, (_, _) {});

      final result = await h.container
          .read(backupControllerProvider.notifier)
          .importFrom();

      expect(
        result,
        isA<ImportRefused>().having(
          (r) => r.problem,
          'problem',
          BackupProblem.notJson,
        ),
      );
      sub.close();
    });
  });
}
