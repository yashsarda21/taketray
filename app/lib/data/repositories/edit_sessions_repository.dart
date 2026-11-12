import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/database/converters.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/rules/folder_names.dart';
import 'package:taketray/domain/rules/text_limits.dart';

part 'edit_sessions_repository.g.dart';

// Never log a folder name or file name (D-10): ids and counts only.
final Logger _log = Logger('editSessions');

/// Remembers which reels are being edited, in which editor, which folder
/// their copies go into, which files were copied there and which clips were
/// sent (D-120).
///
/// This only keeps the records. The files are the copy engine's and
/// `EditSessionService`'s job: the record is what lets a copy be found again,
/// so the caller deletes the files first and then calls [endSession] (or
/// [removeCopies]).
class EditSessionsRepository {
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Starts reel [reelId]'s editing session in [editor], in a folder named
  /// after [baseFolderName], and returns it.
  ///
  /// The name is trimmed, and made unique with `uniqueFolderName` against the
  /// folders of every other session (whatever its editor) and [alsoTaken]
  /// (the folders already in `Movies/TakeTray/`): "Goa", then "Goa (2)",
  /// ignoring case. A blank [baseFolderName] throws [ArgumentError]. Throws
  /// [StateError], saving nothing, when there is no reel [reelId] or it
  /// already has a session.
  Future<EditSession> startSession(
    int reelId,
    EditorApp editor,
    String baseFolderName, {
    Iterable<String> alsoTaken = const [],
  }) async {
    final base = normalizeName(baseFolderName);
    if (base.isEmpty) {
      throw ArgumentError.value(
        baseFolderName,
        'baseFolderName',
        'must not be blank',
      );
    }
    final session = await _db.transaction(() async {
      final reel = await (_db.select(
        _db.reels,
      )..where((r) => r.id.equals(reelId))).getSingleOrNull();
      if (reel == null) throw StateError('No reel with id $reelId');
      if (await _sessionRow(reelId) != null) {
        throw StateError('Reel $reelId already has an editing session');
      }
      final taken = {
        for (final s in await _db.select(_db.editSessions).get()) s.folderName,
        ...alsoTaken,
      };
      final row = await _db
          .into(_db.editSessions)
          .insertReturning(
            EditSessionsCompanion.insert(
              reelId: Value(reelId),
              editor: Value(editor),
              folderName: uniqueFolderName(base, taken),
              createdAt: _clock.storedNow(),
            ),
          );
      return _toSession(row);
    });
    _log.info('Started the ${editor.name} session of reel $reelId');
    return session;
  }

  /// The editing session of reel [reelId], or null when it has none.
  Future<EditSession?> sessionOf(int reelId) async {
    final row = await _sessionRow(reelId);
    return row == null ? null : _toSession(row);
  }

  /// Reel [reelId]'s session with its copies and sent clips, now and again
  /// after every change to them; null while the reel has no session.
  ///
  /// A change to another reel's rows re-reads, but emits only when this
  /// reel's state changed.
  Stream<EditState?> watchEditState(int reelId) => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.editSessions, _db.editCopies, _db.sentClips},
      )
      .watch()
      .asyncMap((_) => _editState(reelId))
      .distinct();

  /// The editor of every reel that has a session (reel id to editor), for
  /// the reel cards, again after every change.
  Stream<Map<int, EditorApp>> watchEditors() => _db
      .select(_db.editSessions)
      .watch()
      .map((rows) => {for (final row in rows) row.reelId: row.editor});

  /// Every editing session with its reel's current name and its recorded
  /// copies (how many, their bytes, the newest copy time), newest session
  /// first (ties: highest reel id first), for the storage screen and the
  /// copies reminder. One SQL statement per emission; again after every
  /// change to sessions, copies or reels.
  Stream<List<EditSessionSummary>> watchSummaries() => _db
      .customSelect(
        '''
        SELECT s.*, r.name AS reel_name,
               COUNT(c.clip_id) AS copy_count,
               COALESCE(SUM(c.size_bytes), 0) AS copy_bytes,
               MAX(c.copied_at) AS last_copied_at
          FROM vn_sessions s
          JOIN reels r ON r.id = s.reel_id
          LEFT JOIN vn_copies c ON c.reel_id = s.reel_id
         GROUP BY s.reel_id
         ORDER BY s.created_at DESC, s.reel_id DESC
        ''',
        readsFrom: {_db.editSessions, _db.editCopies, _db.reels},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            _toSummary(_db.editSessions.map(row.data), row),
        ],
      );

  /// Records that [clipIds] were sent to reel [reelId]'s editor, now.
  ///
  /// A clip already recorded keeps its first time. Ids need not be clips
  /// that still exist (D-54). Throws [StateError], saving nothing, when the
  /// reel has no session (also for an empty list).
  Future<void> recordSent(int reelId, Iterable<int> clipIds) async {
    final ids = clipIds.toSet();
    var added = 0;
    await _db.transaction(() async {
      if (await _sessionRow(reelId) == null) {
        throw StateError('Reel $reelId has no editing session');
      }
      final now = _clock.storedNow();
      for (final clipId in ids) {
        final rowId = await _db
            .into(_db.sentClips)
            .insert(
              SentClipsCompanion.insert(
                reelId: reelId,
                clipId: clipId,
                sentAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        if (rowId != 0) added++;
      }
    });
    _log.info(
      'Recorded $added new of ${ids.length} sent clips for reel $reelId',
    );
  }

  /// Records [copies], all or none, in one transaction.
  ///
  /// A copy equal to one already recorded (same reel, clip and
  /// `copyMediaStoreId`) is skipped, so recording a copy twice (a restart
  /// reading the folder back) is safe and keeps the first row. Throws
  /// [StateError], saving none of [copies], when a copy's reel has no
  /// session, or its reel and clip already have a copy with another id (two
  /// rows would hide one of the files). A copy's clip need not still exist
  /// (D-54).
  Future<void> recordCopies(List<EditCopy> copies) async {
    if (copies.isEmpty) return;
    var added = 0;
    await _db.transaction(() async {
      for (final reelId in {for (final copy in copies) copy.reelId}) {
        if (await _sessionRow(reelId) == null) {
          throw StateError('Reel $reelId has no editing session');
        }
      }
      for (final copy in copies) {
        final existing =
            await (_db.select(_db.editCopies)..where(
                  (c) =>
                      c.reelId.equals(copy.reelId) &
                      c.clipId.equals(copy.clipId),
                ))
                .getSingleOrNull();
        if (existing != null) {
          if (existing.copyMediaStoreId == copy.copyMediaStoreId) continue;
          throw StateError(
            'Reel ${copy.reelId} already has another copy of clip '
            '${copy.clipId}',
          );
        }
        await _db
            .into(_db.editCopies)
            .insert(
              EditCopiesCompanion.insert(
                reelId: copy.reelId,
                clipId: copy.clipId,
                copyMediaStoreId: copy.copyMediaStoreId,
                fileName: copy.fileName,
                sizeBytes: copy.sizeBytes,
                copiedAt: Value(copy.copiedAt),
              ),
            );
        added++;
      }
    });
    _log.info('Recorded $added new of ${copies.length} copies');
  }

  /// Forgets the copies of reel [reelId] whose MediaStore ids are in
  /// [copyMediaStoreIds] (the caller deleted the files, or found them gone).
  /// Unknown ids, and other reels' rows, are left alone; sent rows stay.
  Future<void> removeCopies(int reelId, Iterable<int> copyMediaStoreIds) async {
    final ids = copyMediaStoreIds.toSet();
    if (ids.isEmpty) return;
    final removed =
        await (_db.delete(_db.editCopies)..where(
              (c) => c.reelId.equals(reelId) & c.copyMediaStoreId.isIn(ids),
            ))
            .go();
    _log.info('Removed $removed of ${ids.length} copies of reel $reelId');
  }

  /// The copies recorded for reel [reelId], by file name (which starts with
  /// the shooting time), ties by clip id.
  Future<List<EditCopy>> copiesOf(int reelId) async {
    final rows =
        await (_db.select(_db.editCopies)
              ..where((c) => c.reelId.equals(reelId))
              ..orderBy([
                (c) => OrderingTerm.asc(c.fileName),
                (c) => OrderingTerm.asc(c.clipId),
              ]))
            .get();
    return [
      for (final row in rows)
        EditCopy(
          reelId: row.reelId,
          clipId: row.clipId,
          copyMediaStoreId: row.copyMediaStoreId,
          fileName: row.fileName,
          sizeBytes: row.sizeBytes,
          copiedAt: row.copiedAt,
        ),
    ];
  }

  /// Ends reel [reelId]'s session ("Done editing"): deletes the session and,
  /// with it (`ON DELETE CASCADE`), its copy and sent rows. An unknown reel
  /// or a reel with no session does nothing.
  ///
  /// The caller deletes the copy files first: afterwards nothing records
  /// which files were copied.
  Future<void> endSession(int reelId) async {
    final removed = await (_db.delete(
      _db.editSessions,
    )..where((s) => s.reelId.equals(reelId))).go();
    _log.info('Ended the editing session of reel $reelId ($removed removed)');
  }

  Future<EditState?> _editState(int reelId) => _db.transaction(() async {
    final row = await _sessionRow(reelId);
    if (row == null) return null;
    final sent = await (_db.select(
      _db.sentClips,
    )..where((s) => s.reelId.equals(reelId))).get();
    return EditState(
      session: _toSession(row),
      copies: await copiesOf(reelId),
      sentIds: {for (final s in sent) s.clipId},
    );
  });

  EditSessionSummary _toSummary(EditSessionRow session, QueryRow row) {
    final last = row.read<int?>('last_copied_at');
    return EditSessionSummary(
      reelId: session.reelId,
      reelName: row.read<String>('reel_name'),
      editor: session.editor,
      folderName: session.folderName,
      createdAt: session.createdAt,
      copyCount: row.read<int>('copy_count'),
      copyBytes: row.read<int>('copy_bytes'),
      lastCopiedAt: last == null
          ? null
          : const UtcMillisConverter().fromSql(last),
    );
  }

  Future<EditSessionRow?> _sessionRow(int reelId) => (_db.select(
    _db.editSessions,
  )..where((s) => s.reelId.equals(reelId))).getSingleOrNull();

  EditSession _toSession(EditSessionRow row) => EditSession(
    reelId: row.reelId,
    editor: row.editor,
    folderName: row.folderName,
    createdAt: row.createdAt,
  );
}

@Riverpod(keepAlive: true)
EditSessionsRepository editSessionsRepository(Ref ref) =>
    EditSessionsRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(clockProvider),
    );
