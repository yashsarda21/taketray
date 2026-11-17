import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/backup/backup_format.dart';
import 'package:taketray/data/backup/backup_service.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';

part 'backup_actions.g.dart';

// Counts and types only: never a file name, a path or a reel name (D-10).
final Logger _log = Logger('backup');

/// The largest backup file an import reads, in UTF-16 code units of its text
/// (a Dart `String.length`): 20 MiB. A real backup is a few hundred KB.
const int maxImportCodeUnits = 20 * 1024 * 1024;

/// How [BackupActions.importJson] turns a file into data. The default
/// decodes off the main isolate.
typedef BackupDecoder = Future<BackupData> Function(String json);

/// Decodes [json] on a background isolate, so a large file never freezes
/// the screen. Throws [BackupException] as `decodeBackup` does.
Future<BackupData> decodeBackupInIsolate(String json) =>
    Isolate.run(() => decodeBackup(json));

/// How an import ended (D-146).
sealed class ImportResult {
  const ImportResult();
}

/// The backup was stored. [found] of [total] clips were found on this phone
/// by the verify that follows (0 when that verify failed).
@immutable
final class ImportDone extends ImportResult {
  const ImportDone(this.summary, this.found, this.total);

  final ImportSummary summary;
  final int found;
  final int total;
}

/// The file is not a backup this app can read; nothing changed.
@immutable
final class ImportRefused extends ImportResult {
  const ImportRefused(this.problem);

  final BackupProblem problem;
}

/// A copy job is saved (running or waiting): its files are tied to clip ids
/// the import would replace. Nothing was read or changed.
@immutable
final class ImportBusyCopying extends ImportResult {
  const ImportBusyCopying();
}

/// The file is over [maxImportCodeUnits]; it was not decoded.
@immutable
final class ImportTooLarge extends ImportResult {
  const ImportTooLarge();
}

/// What the Settings screen does with backups (D-146): the checks around
/// `BackupService` that keep an import safe.
class BackupActions {
  new(
    this._service,
    this._phone,
    this._queue,
    this._verifier,
    this._clock,
    this._db, [
    this._decode = decodeBackupInIsolate,
  ]);

  final BackupService _service;
  final PhoneStateRepository _phone;
  final MediaWorkQueue _queue;
  final MediaVerifier _verifier;
  final Clock _clock;
  final AppDatabase _db;
  final BackupDecoder _decode;

  /// The whole database as backup text. It records nothing: the screen calls
  /// [recordExport] once the file is saved, so a cancelled picker or a failed
  /// save never counts as a backup.
  Future<String> exportJson() => _service.exportJson();

  /// Remembers that a backup file was just saved (`lastExport`, D-145).
  Future<void> recordExport() => _phone.recordExport(_clock.now());

  /// Replaces the user's data with the backup in [json], or says why not.
  ///
  /// 1. Over [maxImportCodeUnits]: [ImportTooLarge], nothing decoded.
  /// 2. A copy plan is saved: [ImportBusyCopying], nothing read.
  /// 3. The file is decoded on a background isolate; a bad file is
  ///    [ImportRefused].
  /// 4. The data is stored as one job on the media work queue, so no scan,
  ///    verify or grant clean-up runs in the middle of it (D-72). A database
  ///    constraint the checks missed is [ImportRefused] too.
  /// 5. Every clip is verified, through [guarded]: when that fails the
  ///    import still stands, with 0 found.
  Future<ImportResult> importJson(String json) async {
    if (json.length > maxImportCodeUnits) {
      _log.warning('Import refused: file over the size limit');
      return const ImportTooLarge();
    }
    if (await _phone.copyJobPlan() != null) {
      _log.warning('Import refused: a copy job is saved');
      return const ImportBusyCopying();
    }

    final ImportSummary summary;
    try {
      final data = await _decode(json);
      summary = await _queue.run(() => _service.importDecoded(data));
    } on BackupException catch (e) {
      _log.warning('Import refused: $e');
      return ImportRefused(e.problem);
    }

    final outcome = await guarded(
      _log,
      'Verifying after the import',
      _verifier.verifyAll,
    );
    return ImportDone(summary, outcome?.found.length ?? 0, summary.clips);
  }

  /// Whether any copy of a clip exists in `Movies/TakeTray/`, so the screen
  /// can warn that an import forgets them (the editing rows are not backed
  /// up).
  Future<bool> hasCopies() async =>
      (await (_db.select(_db.editCopies)..limit(1)).get()).isNotEmpty;
}

@Riverpod(keepAlive: true)
BackupActions backupActions(Ref ref) => BackupActions(
  ref.watch(backupServiceProvider),
  ref.watch(phoneStateRepositoryProvider),
  ref.watch(mediaWorkQueueProvider),
  ref.watch(mediaVerifierProvider),
  ref.watch(clockProvider),
  ref.watch(appDatabaseProvider),
);
