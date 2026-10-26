import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/backup/backup_format.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/enums.dart';

part 'backup_service.g.dart';

// Counts only: never a reel name, link, label or file name (D-10).
final Logger _log = Logger('backup');

/// What an import brought in.
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
  /// time), so the same data always gives the same text. Left out: VN
  /// sessions and their copies, and every setting outside
  /// `SettingsRepository.exportedKeys` (this phone's own state). The settings
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

  /// Replaces everything in the database with the backup in [json].
  ///
  /// The whole file is checked first (`decodeBackup`); a file that fails
  /// throws [BackupException] and the database is not touched. Then, in one
  /// transaction, every row of every table is deleted (VN sessions and
  /// phone-state settings too) and the backup's rows are inserted with their
  /// ids. If anything fails in there, the transaction rolls back and the old
  /// data stays.
  ///
  /// SQLite's `AUTOINCREMENT` counters only ever go up: inserting an id moves
  /// the counter to it when it is higher, and deleting rows does not lower
  /// it. So a row added after the import never gets an imported id, or an id
  /// used before the import (D-54).
  Future<ImportSummary> importJson(String json) async {
    final BackupData data;
    try {
      data = decodeBackup(json);
    } on BackupException catch (e) {
      _log.warning('Import refused: $e');
      rethrow;
    }

    await _db.transaction(() async {
      // Children before parents, so no foreign key is ever left dangling.
      await _db.delete(_db.vnCopies).go();
      await _db.delete(_db.vnSessions).go();
      await _db.delete(_db.clipReels).go();
      await _db.delete(_db.inbox).go();
      await _db.delete(_db.reelReferences).go();
      await _db.delete(_db.clips).go();
      await _db.delete(_db.reels).go();
      await _db.delete(_db.settings).go();
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
    _log.info('Imported ${_counts(data)}');
    return summary;
  }

  /// The three settings rows, each value JSON as `SettingsRepository.save`
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
