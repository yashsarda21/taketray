import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/backup/backup_format.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/enums.dart';

part 'backup_service.g.dart';

// Counts only: never a reel name, link, label or file name (D-10).
final Logger _log = Logger('backup');

/// SQLite's primary result code for a broken constraint (`SQLITE_CONSTRAINT`):
/// a unique key, foreign key, `CHECK` or trigger `RAISE`.
const _sqliteConstraint = 19;

/// What an import stored.
@immutable
final class ImportSummary {
  const new({
    required this.reels,
    required this.clips,
    required this.references,
    required this.inboxPending,
    required this.inboxSkipped,
  });

  final int reels;
  final int clips;
  final int references;

  /// Clips in To tag.
  final int inboxPending;

  /// Clips in Skipped.
  final int inboxSkipped;

  @override
  bool operator ==(Object other) =>
      other is ImportSummary &&
      other.reels == reels &&
      other.clips == clips &&
      other.references == references &&
      other.inboxPending == inboxPending &&
      other.inboxSkipped == inboxSkipped;

  @override
  int get hashCode =>
      Object.hash(reels, clips, references, inboxPending, inboxSkipped);

  @override
  String toString() =>
      'ImportSummary(reels: $reels, clips: $clips, references: $references, '
      'inboxPending: $inboxPending, inboxSkipped: $inboxSkipped)';
}

/// Turns the whole database into a backup file and back (spec §8.6, D-59).
///
/// The file format is in `backup_format.dart`. Choosing where the file goes
/// (the Storage Access Framework) is the Settings screen's job (phase 10).
class BackupService {
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// The whole database as a backup file, `exportedAt` now.
  ///
  /// Rows are sorted by id (links by clip, then reel; the zone timeline by
  /// time), so the same data always gives the same text. Left out: editing
  /// sessions with their copies and sent clips (D-120), and every setting
  /// outside `SettingsRepository.exportedKeys` (this phone's own state). The
  /// settings
  /// are written as `SettingsRepository.load` reads them, so a missing or
  /// corrupt one is written as its default.
  Future<String> exportJson() async {
    final data = await _db.transaction(
      () async => BackupData(
        reels: await (_db.select(
          _db.reels,
        )..orderBy([(r) => OrderingTerm.asc(r.id)])).get(),
        references: await (_db.select(
          _db.reelReferences,
        )..orderBy([(r) => OrderingTerm.asc(r.id)])).get(),
        clips: await (_db.select(
          _db.clips,
        )..orderBy([(c) => OrderingTerm.asc(c.id)])).get(),
        clipReels:
            await (_db.select(_db.clipReels)..orderBy([
                  (l) => OrderingTerm.asc(l.clipId),
                  (l) => OrderingTerm.asc(l.reelId),
                ]))
                .get(),
        inbox: await (_db.select(
          _db.inbox,
        )..orderBy([(i) => OrderingTerm.asc(i.clipId)])).get(),
        settings: await SettingsRepository(_db, _clock).load(),
        zoneTimeline: await (_db.select(
          _db.zoneTimeline,
        )..orderBy([(z) => OrderingTerm.asc(z.at)])).get(),
      ),
    );
    final json = encodeBackup(data, _clock.now());
    _log.info('Exported ${_counts(data)}');
    return json;
  }

  /// Replaces the database's data with the backup in [json].
  ///
  /// The whole file is checked first (`decodeBackup`); a file that fails
  /// throws [BackupException] and the database is not touched. Then
  /// [importDecoded] stores it.
  ///
  /// This does not wait for the media work queue and does not look for a
  /// running copy job: `BackupActions.importJson` is the entry point the app
  /// uses, and does both (D-146).
  Future<ImportSummary> importJson(String json) async {
    final BackupData data;
    try {
      data = decodeBackup(json);
    } on BackupException catch (e) {
      _log.warning('Import refused: $e');
      rethrow;
    }
    return await importDecoded(data);
  }

  /// Stores a backup that [decodeBackup] already accepted.
  ///
  /// In one transaction, every row of every table is deleted, except the
  /// `settings` rows this phone owns (D-146): only the keys in
  /// `SettingsRepository.exportedKeys`, `shootingMode` and `copyJobPlan` go,
  /// so the first-launch flags, the last-export time, the volume versions
  /// and the rest of the phone's state survive. Editing sessions with their
  /// copy and sent rows go too. Then the backup's rows are inserted with
  /// their ids. If anything fails in there, the transaction rolls back and
  /// the old data stays; a constraint the checks missed is still reported as
  /// [BackupProblem.invalidData], never as a raw database error.
  ///
  /// Imported ids may be ids the database used before the import, for other
  /// rows: that is safe only because this same transaction deletes every row
  /// that could still hold an old clip id (`vn_copies` and `sent_clips`,
  /// D-54, D-120). SQLite's
  /// `AUTOINCREMENT` counters only ever go up (inserting a higher id moves
  /// the counter to it, deleting rows never lowers it), so rows added after
  /// the import get ids above every imported one.
  Future<ImportSummary> importDecoded(BackupData data) async {
    try {
      await _replaceAll(data);
    } on Object catch (e) {
      final cause = e is DriftRemoteException ? e.remoteCause : e;
      if (cause is! SqliteException || cause.resultCode != _sqliteConstraint) {
        rethrow;
      }
      // The exception's text holds the statement's values: log only the code.
      _log.warning(
        'Import refused by the database (code ${cause.extendedResultCode}); '
        'nothing changed',
      );
      throw const BackupException(BackupProblem.invalidData);
    }

    final summary = ImportSummary(
      reels: data.reels.length,
      clips: data.clips.length,
      references: data.references.length,
      inboxPending: data.inbox
          .where((i) => i.state == InboxState.pending)
          .length,
      inboxSkipped: data.inbox
          .where((i) => i.state == InboxState.skipped)
          .length,
    );
    _log.info(
      'Imported ${_counts(data)}; left out ${data.inboxRowsDropped} inbox '
      'rows of clips in a reel, ${data.orphanClipsDropped} orphan clips '
      'and ${data.referencesDropped} duplicate references',
    );
    return summary;
  }

  /// The `settings` keys an import removes before it writes the backup's:
  /// the five it restores, and the two phone-state rows that must not outlive
  /// it, Shooting mode (its baselines belong to the old library, D-71) and
  /// the copy plan (it names clip ids the import replaces, D-54, D-123).
  static final Set<String> _removedSettingKeys = {
    ...SettingsRepository.exportedKeys,
    PhoneStateRepository.shootingModeKey,
    PhoneStateRepository.copyJobPlanKey,
  };

  /// Deletes the data rows and inserts [data], in one transaction.
  Future<void> _replaceAll(BackupData data) async {
    await _db.transaction(() async {
      // Children before parents, so no foreign key is ever left dangling.
      // The editing rows (sessions, copies, sent clips) are never exported
      // (D-59, D-120), and the copy and sent rows hold clip ids that must not
      // outlive the import (D-54).
      await _db.delete(_db.sentClips).go();
      await _db.delete(_db.editCopies).go();
      await _db.delete(_db.editSessions).go();
      await _db.delete(_db.clipReels).go();
      await _db.delete(_db.inbox).go();
      await _db.delete(_db.reelReferences).go();
      await _db.delete(_db.clips).go();
      await _db.delete(_db.reels).go();
      // Not the whole table: every other key is this phone's own state.
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.isIn(_removedSettingKeys))).go();
      await _db.delete(_db.zoneTimeline).go();

      await _db.batch((b) {
        b
          ..insertAll(_db.reels, data.reels)
          ..insertAll(_db.clips, data.clips)
          ..insertAll(_db.clipReels, data.clipReels)
          ..insertAll(_db.inbox, data.inbox)
          ..insertAll(_db.reelReferences, data.references)
          ..insertAll(_db.settings, _settingRows(data))
          ..insertAll(_db.zoneTimeline, data.zoneTimeline);
      });
    });
  }

  /// The five settings rows, each value JSON as `SettingsRepository.save`
  /// writes it.
  List<SettingsCompanion> _settingRows(BackupData data) => [
    for (final (key, value) in [
      (SettingsRepository.watchedFoldersKey, data.settings.watchedFolders),
      (
        SettingsRepository.eveningReminderEnabledKey,
        data.settings.eveningReminderEnabled,
      ),
      (
        SettingsRepository.eveningReminderMinutesKey,
        data.settings.eveningReminderMinutes,
      ),
      (
        SettingsRepository.stillReminderEnabledKey,
        data.settings.stillReminderEnabled,
      ),
      (
        SettingsRepository.copiesReminderEnabledKey,
        data.settings.copiesReminderEnabled,
      ),
    ])
      SettingsCompanion.insert(key: key, value: jsonEncode(value)),
  ];

  String _counts(BackupData data) =>
      '${data.reels.length} reels, ${data.clips.length} clips, '
      '${data.references.length} references, '
      '${data.clipReels.length} links, ${data.inbox.length} inbox rows, '
      '${data.zoneTimeline.length} zone entries';
}

@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) =>
    BackupService(ref.watch(appDatabaseProvider), ref.watch(clockProvider));
