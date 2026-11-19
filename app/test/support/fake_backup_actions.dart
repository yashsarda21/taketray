import 'dart:async';

import 'package:taketray/data/backup/backup_actions.dart';
import 'package:taketray/data/backup/backup_service.dart';

/// The summary of the clips a [FakeBackupActions] "imports" by default.
const fakeImportSummary = ImportSummary(
  reels: 2,
  clips: 4,
  references: 1,
  inboxPending: 0,
  inboxSkipped: 0,
);

/// A [BackupActions] with no database, for the backup screen and its
/// controller.
///
/// - Settable answers: [exportText] (what `exportJson` gives), [importAnswer]
///   (what `importJson` gives) and [copies] (`hasCopies`).
/// - Failures: [exportError], [recordError], [importError] and [copiesError]
///   are thrown by their method when set.
/// - Recorded: [log] (every method's name, in order), [imported] (the text
///   each `importJson` was given) and [records] (how many `recordExport`
///   calls ended well).
/// - [onRecord] runs inside a `recordExport` that ends well: a test can move
///   its stored date, or see what had happened by then.
/// - [holdImport] makes `importJson` wait, after it is logged, until
///   [releaseImport]; [holdCopies] and [releaseCopies] do the same for
///   `hasCopies`.
class FakeBackupActions implements BackupActions {
  String exportText = '{"backup":"fake"}';
  ImportResult importAnswer = const ImportDone(fakeImportSummary, 3, 4);
  bool copies = false;

  Error? exportError;
  Error? recordError;
  Error? importError;
  Error? copiesError;

  void Function()? onRecord;

  final List<String> log = [];
  final List<String> imported = [];
  int records = 0;

  Completer<void>? _importHold;
  Completer<void>? _copiesHold;

  /// Makes `importJson` wait until [releaseImport].
  void holdImport() => _importHold = Completer<void>();

  /// Lets a held `importJson` go on.
  void releaseImport() {
    _importHold?.complete();
    _importHold = null;
  }

  /// Makes `hasCopies` wait until [releaseCopies].
  void holdCopies() => _copiesHold = Completer<void>();

  /// Lets a held `hasCopies` go on.
  void releaseCopies() {
    _copiesHold?.complete();
    _copiesHold = null;
  }

  @override
  Future<String> exportJson() async {
    log.add('exportJson');
    final error = exportError;
    if (error != null) throw error;
    return exportText;
  }

  @override
  Future<void> recordExport() async {
    log.add('recordExport');
    final error = recordError;
    if (error != null) throw error;
    records++;
    onRecord?.call();
  }

  @override
  Future<ImportResult> importJson(String json) async {
    log.add('importJson');
    imported.add(json);
    await _importHold?.future;
    final error = importError;
    if (error != null) throw error;
    return importAnswer;
  }

  @override
  Future<bool> hasCopies() async {
    log.add('hasCopies');
    await _copiesHold?.future;
    final error = copiesError;
    if (error != null) throw error;
    return copies;
  }
}
