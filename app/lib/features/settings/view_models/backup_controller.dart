import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/backup/backup_actions.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/platform/files_bridge.dart';

part 'backup_controller.g.dart';

// Outcomes and error types only: never the file's name, its address or what
// is in it (D-10).
final Logger _log = Logger('backupScreen');

/// The type a backup file is saved as.
const backupMimeType = 'application/json';

/// The types the import's file picker offers: a backup, a backup some app
/// saved as text, and anything else (some file managers name no type).
const List<String> importMimeTypes = ['application/json', 'text/plain', '*/*'];

/// The largest file the import's picker reads, in bytes: 20 MB. A real
/// backup is a few hundred KB; `BackupActions` also refuses over 20 MB of
/// text.
const int maxImportBytes = 20 * 1024 * 1024;

/// The name a backup file is offered under: `taketray-backup-2026-11-17.json`,
/// the day of [now] on the phone (its local date, not UTC's).
String backupFileName(DateTime now) {
  final local = now.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'taketray-backup-${local.year}-${two(local.month)}-'
      '${two(local.day)}.json';
}

/// How an export ended.
enum ExportOutcome {
  /// The file was saved (and the date recorded): "Backup saved".
  saved,

  /// The user left the picker, or another job was running: nothing is
  /// said.
  cancelled,

  /// The backup could not be made or written: "Couldn't save the backup."
  failed,
}

/// The job running on the backup screen.
enum BackupJob { exporting, importing }

/// What the Export and import screen shows: the [lastExport] date (null for
/// none) and the [job] that runs, if any.
@immutable
class BackupState {
  const BackupState({required this.lastExport, this.job});

  final DateTime? lastExport;
  final BackupJob? job;

  /// Whether a job runs: both buttons are off.
  bool get busy => job != null;

  @override
  bool operator ==(Object other) =>
      other is BackupState &&
      other.lastExport == lastExport &&
      other.job == job;

  @override
  int get hashCode => Object.hash(lastExport, job);

  @override
  String toString() => 'BackupState(lastExport: $lastExport, job: $job)';
}

/// The Export and import screen (Phase 10B, D-150).
///
/// - **One job at a time.** [export] and [importFrom] each start a job; a
///   call while one runs does nothing (double taps, or Export tapped while an
///   import runs). The job ends in a `finally`, so a picker that fails (the
///   activity went away) or an import that throws never leaves the buttons
///   off.
/// - **A job outlives the screen.** While it runs the controller is kept
///   alive, so leaving the screen and coming back shows it still busy and
///   cannot start a second one. If Android kills TakeTray while its picker
///   is open, the job dies with the process; the new process starts idle.
/// - **The date** is `lastExportProvider`'s, the one the Settings row shows.
///   A save invalidates it, so the row and this screen show the new date at
///   once.
@Riverpod(retry: noRetry)
class BackupController extends _$BackupController {
  BackupJob? _job;

  @override
  Future<BackupState> build() async {
    final last = await ref.watch(lastExportProvider.future);
    return BackupState(lastExport: last, job: _job);
  }

  /// Saves a backup through Android's file picker
  /// (`taketray-backup-<local date>.json`, JSON) and, only once the picker
  /// says where it was saved, records the date. A cancel records nothing.
  Future<ExportOutcome> export() async {
    if (_job != null) return ExportOutcome.cancelled;
    final actions = ref.read(backupActionsProvider);
    final files = ref.read(filesBridgeProvider);
    final name = backupFileName(ref.read(clockProvider).now());
    final done = _start(BackupJob.exporting);
    try {
      final String? address;
      try {
        final json = await actions.exportJson();
        address = await files.saveDocument(name, backupMimeType, json);
      } on Object catch (error) {
        _log.warning('Saving a backup failed: ${_describe(error)}');
        return ExportOutcome.failed;
      }
      if (address == null) return ExportOutcome.cancelled;
      // The file is saved whatever happens now: a date that could not be
      // recorded only leaves the old one showing.
      await guarded(_log, 'Recording the backup date', actions.recordExport);
      _log.info('A backup was saved');
      if (ref.mounted) ref.invalidate(lastExportProvider);
      return ExportOutcome.saved;
    } finally {
      done();
    }
  }

  /// Opens Android's file picker for a backup (JSON, text or any file, up to
  /// [maxImportBytes]) and imports it (`BackupActions.importJson`).
  ///
  /// Null when the picker was cancelled or another job runs: nothing was
  /// read. A file over the limit at the picker is [ImportTooLarge]. Any other
  /// failure of the picker or the import is thrown, after it is logged.
  Future<ImportResult?> importFrom() async {
    if (_job != null) return null;
    final actions = ref.read(backupActionsProvider);
    final files = ref.read(filesBridgeProvider);
    final done = _start(BackupJob.importing);
    try {
      final String? text;
      try {
        text = await files.openDocument(importMimeTypes, maxImportBytes);
      } on FileBridgeException catch (error) {
        if (error.problem == FilesProblem.tooLarge) {
          _log.warning('Import refused: file over the size limit');
          return const ImportTooLarge();
        }
        _log.warning('Choosing a backup failed: ${error.problem.name}');
        rethrow;
      }
      if (text == null) return null;
      try {
        return await actions.importJson(text);
      } on Object catch (error) {
        _log.warning('Importing a backup failed: ${error.runtimeType}');
        rethrow;
      }
    } finally {
      done();
    }
  }

  /// Whether TakeTray's VN copies are on the phone, for the question before
  /// an import. A failed read says yes: the sentence about them is better
  /// said once too often than left out.
  Future<bool> hasCopies() async =>
      await guarded(
        _log,
        'Checking for VN copies',
        ref.read(backupActionsProvider).hasCopies,
      ) ??
      true;

  /// Marks [job] as running and keeps the controller alive until the
  /// returned callback ends it.
  void Function() _start(BackupJob job) {
    _job = job;
    final link = ref.keepAlive();
    _publish();
    return () {
      _job = null;
      _publish();
      link.close();
    };
  }

  /// Shows the job in the state, keeping the date known so far.
  void _publish() {
    if (!ref.mounted) return;
    state = AsyncData(
      BackupState(lastExport: state.value?.lastExport, job: _job),
    );
  }
}

/// A bridge error by its problem, anything else by its type (D-10).
String _describe(Object error) => error is FileBridgeException
    ? error.problem.name
    : error.runtimeType.toString();
