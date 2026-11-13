import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/clip_rules.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/clip_leave_hook.dart';
import 'package:taketray/data/repositories/undo_writer.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/text_limits.dart';

part 'reels_repository.g.dart';

// Never log a reel name (D-10): ids and counts only.
final Logger _log = Logger('reels');

/// Creates, edits, watches and deletes reels.
///
/// Screens use this instead of the database: it checks the rules (a name is 1
/// to 40 characters and no other reel has it; a description is at most 1,000
/// characters) and keeps `updatedAt` honest. A reel's clips, references and
/// VN session live in other tables and are handled by their own repositories;
/// this one only removes them when the reel goes, and puts them back on Undo.
///
/// Two reels cannot share a name, ignoring case and the spaces at either end
/// (D-80, D-84, amending D-56). Backup import and Undo of a delete still
/// bring back a reel whose name another reel has taken meanwhile: they do not
/// go through [create].
class ReelsRepository {
  new(this._db, this._clock, {BeforeClipsLeave? beforeLeave})
    : _undo = UndoWriter(_db, _clock, beforeLeave: beforeLeave);

  final AppDatabase _db;
  final Clock _clock;
  final UndoWriter _undo;

  /// The clean-up the undo of an add or a move runs before it takes a clip
  /// out of a reel (R8; null: none). The editing service's provider sets it
  /// when it is built.
  BeforeClipsLeave? get beforeLeave => _undo.beforeLeave;
  set beforeLeave(BeforeClipsLeave? hook) => _undo.beforeLeave = hook;

  /// Saves a new reel, `collecting`, created and updated now.
  ///
  /// [name] is trimmed and must be 1 to 40 characters and not the name of
  /// another reel (ignoring case), otherwise this throws
  /// [InvalidInputException] with a [ReelNameProblem] and saves nothing. A
  /// null, empty or blank [description] is stored as null; one over 1,000
  /// characters throws [InvalidInputException] with
  /// [ReelDescriptionProblem.tooLong]. The name check and the insert are one
  /// transaction, so two saves at once cannot both take a name.
  Future<Reel> create(String name, {String? description}) async {
    _checkName(name);
    _checkDescription(description);
    final row = await _db.transaction(() async {
      await _checkUnique(name);
      final now = _clock.storedNow();
      return await _db
          .into(_db.reels)
          .insertReturning(
            ReelsCompanion.insert(
              name: normalizeName(name),
              description: Value(_cleanDescription(description)),
              status: ReelStatus.collecting,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    _log.info('Created reel ${row.id}');
    return reelFromRow(row);
  }

  /// Renames reel [id]. The name is checked as in [create]; the reel's own
  /// name, in any case, is fine, even when another reel has it too (a backup
  /// import or an Undo can bring two). Throws [StateError] when there is no
  /// such reel.
  Future<void> rename(int id, String name) async {
    _checkName(name);
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.reels,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (current == null) throw StateError('No reel with id $id');
      // Its own name in any case is always fine, even while an imported or
      // restored reel has the same name: otherwise that reel could not be
      // saved at all.
      if (reelNameKey(current.name) != reelNameKey(name)) {
        await _checkUnique(name);
      }
      await _update(id, ReelsCompanion(name: Value(normalizeName(name))));
    });
  }

  /// Sets or clears (null, empty or blank) the description of reel [id].
  /// Throws [InvalidInputException] with [ReelDescriptionProblem.tooLong],
  /// saving nothing, over 1,000 characters, and [StateError] when there is no
  /// such reel.
  Future<void> setDescription(int id, String? description) async {
    _checkDescription(description);
    await _update(
      id,
      ReelsCompanion(description: Value(_cleanDescription(description))),
    );
  }

  /// Sets the status of reel [id]. Throws [StateError] when there is no such
  /// reel.
  Future<void> setStatus(int id, ReelStatus status) =>
      _update(id, ReelsCompanion(status: Value(status)));

  /// Deletes reel [id], its clip links, references and editing session (with
  /// its copy and sent rows), then every clip that is left in no reel and not
  /// in To tag or Skipped. All of it happens in one transaction: either
  /// everything goes or nothing does.
  ///
  /// A clip that is also in another reel, or in To tag or Skipped, stays. The
  /// `vn_copies` rows of a removed clip stay too (D-54).
  ///
  /// The caller deletes this reel's copy files and ends its editing session
  /// first (R8, D-120): once the reel is gone, nothing in the database says
  /// which files were copied.
  ///
  /// Returns what [undo] needs to put it all back (D-84): the reel row, its
  /// links, references, editing session and copy rows (none on the app's
  /// path, which ended the session), and every field of the clips the sweep
  /// deleted, read in the same transaction before they go. Sent rows are not
  /// kept.
  ///
  /// An unknown [id] deletes no reel, but the orphan sweep still runs, so any
  /// clip that is in no reel and no list is removed anyway. Its record
  /// restores nothing.
  Future<DeleteReelUndo> delete(int id) async {
    final record = await _db.transaction(() async {
      final reel = await (_db.select(
        _db.reels,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      final links = await (_db.select(
        _db.clipReels,
      )..where((l) => l.reelId.equals(id))).get();
      final references = await (_db.select(
        _db.reelReferences,
      )..where((r) => r.reelId.equals(id))).get();
      final session = await (_db.select(
        _db.editSessions,
      )..where((s) => s.reelId.equals(id))).getSingleOrNull();
      final copies = await (_db.select(
        _db.editCopies,
      )..where((c) => c.reelId.equals(id))).get();
      // The links, references and editing rows (session, copies, sent clips)
      // go with the reel: ON DELETE CASCADE.
      await (_db.delete(_db.reels)..where((r) => r.id.equals(id))).go();
      final swept = await _undo.sweepOrphans();
      return DeleteReelUndo(
        reel: reel == null ? null : reelFromRow(reel),
        links: [for (final link in links) linkFromRow(link)],
        references: [for (final r in references) referenceFromRow(r)],
        editSession: session == null ? null : editSessionFromRow(session),
        editCopies: [for (final copy in copies) editCopyFromRow(copy)],
        sweptClips: swept,
      );
    });
    _log.info(
      'Delete reel $id: removed ${record.reel == null ? 0 : 1} reel, '
      'swept ${record.sweptClips.length} clips',
    );
    return record;
  }

  /// Puts back what a remove, move, add or reel delete changed (D-84); the
  /// same as `ClipsRepository.undo`. See `UndoWriter.undo`.
  Future<void> undo(UndoRecord record) => _undo.undo(record);

  /// Puts back what every one of [records] changed, last to first, in one
  /// transaction: all of them or, on a failure, none (then the list can be
  /// undone again). See `UndoWriter.undoAll`.
  Future<void> undoAll(List<UndoRecord> records) => _undo.undoAll(records);

  /// Reel [id], or null when there is none.
  Future<Reel?> getById(int id) async {
    final row = await (_db.select(
      _db.reels,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : reelFromRow(row);
  }

  /// Reel [id] now and again after every change to it; null once it is gone.
  Stream<Reel?> watchById(int id) =>
      (_db.select(_db.reels)..where((r) => r.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : reelFromRow(row));

  /// Every reel, most recently updated first (ties: highest id first), again
  /// after every change.
  Stream<List<Reel>> watchAll() =>
      (_db.select(_db.reels)..orderBy([
            (r) => OrderingTerm.desc(r.updatedAt),
            (r) => OrderingTerm.desc(r.id),
          ]))
          .watch()
          .map((rows) => [for (final row in rows) reelFromRow(row)]);

  /// Every reel as Home shows it, newest created first (ties: highest id
  /// first), again after every change to reels, links or clips.
  ///
  /// One SQL statement per emission, whatever the number of reels: the
  /// counts and the live duration are aggregates over `clip_reels` joined to
  /// `clips`, and the cover is the first row of a window over each reel's
  /// showable clips (`ReelSummary.cover`), joined in.
  Stream<List<ReelSummary>> watchReelSummaries() {
    // The cover rule is the shared `hasPicture`, written as SQL for the
    // alias `c` with its own variables.
    final picture = GenerationContext.fromDb(_db);
    hasPicture(_db.alias(_db.clips, 'c')).writeInto(picture);
    final clipColumns = [
      for (final column in _db.clips.$columns)
        'cc."${column.name}" AS "cover.${column.name}"',
    ].join(', ');
    final query = _db.customSelect(
      '''
      WITH agg AS (
        SELECT cr.reel_id AS reel_id,
               COUNT(*) AS clip_count,
               SUM(CASE WHEN c.missing THEN 1 ELSE 0 END) AS missing_count,
               SUM(CASE WHEN c.missing THEN 0 ELSE c.duration_ms END) AS live_ms
          FROM clip_reels cr JOIN clips c ON c.id = cr.clip_id
         GROUP BY cr.reel_id
      ),
      cover AS (
        SELECT reel_id, clip_id FROM (
          SELECT cr.reel_id AS reel_id, c.id AS clip_id,
                 ROW_NUMBER() OVER (
                   PARTITION BY cr.reel_id ORDER BY c.date_taken_utc, c.id
                 ) AS rank
            FROM clip_reels cr JOIN clips c ON c.id = cr.clip_id
           WHERE ${picture.sql}
        ) WHERE rank = 1
      )
      SELECT r.*,
             COALESCE(agg.clip_count, 0) AS clip_count,
             COALESCE(agg.missing_count, 0) AS missing_count,
             COALESCE(agg.live_ms, 0) AS live_ms,
             $clipColumns
        FROM reels r
        LEFT JOIN agg ON agg.reel_id = r.id
        LEFT JOIN cover ON cover.reel_id = r.id
        LEFT JOIN clips cc ON cc.id = cover.clip_id
       ORDER BY r.created_at DESC, r.id DESC
      ''',
      variables: picture.introducedVariables,
      readsFrom: {_db.reels, _db.clipReels, _db.clips},
    );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          ReelSummary(
            reel: reelFromRow(_db.reels.map(row.data)),
            clipCount: row.read<int>('clip_count'),
            missingCount: row.read<int>('missing_count'),
            liveDurationMs: row.read<int>('live_ms'),
            cover: row.data['cover.id'] == null
                ? null
                : clipFromRow(_db.clips.map(row.data, tablePrefix: 'cover')),
          ),
      ],
    );
  }

  void _checkName(String name) {
    final problem = checkReelName(name);
    if (problem != null) throw InvalidInputException(problem);
  }

  void _checkDescription(String? description) {
    final problem = checkReelDescription(description);
    if (problem != null) throw InvalidInputException(problem);
  }

  /// Throws [ReelNameProblem.duplicate] when a reel has [name], ignoring case
  /// and edge spaces (`rename` skips this for the reel's own name). Compared
  /// in Dart ([reelNameKey]): SQL's `lower()` folds only ASCII, so "CAFÉ"
  /// would not match "Café". Run inside the write's transaction.
  Future<void> _checkUnique(String name) async {
    final key = reelNameKey(name);
    final query = _db.selectOnly(_db.reels)..addColumns([_db.reels.name]);
    final rows = await query.get();
    for (final row in rows) {
      if (reelNameKey(row.read(_db.reels.name)!) == key) {
        throw const InvalidInputException(ReelNameProblem.duplicate);
      }
    }
  }

  String? _cleanDescription(String? description) {
    if (description == null) return null;
    final cleaned = normalizeName(description);
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _update(int id, ReelsCompanion changes) async {
    final updated = await (_db.update(_db.reels)..where((r) => r.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value(_clock.storedNow())));
    if (updated == 0) throw StateError('No reel with id $id');
  }
}

@Riverpod(keepAlive: true)
ReelsRepository reelsRepository(Ref ref) =>
    ReelsRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider));
