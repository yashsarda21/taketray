import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/domain/models/vn_copy.dart';
import 'package:taketray/domain/models/vn_session.dart';
import 'package:taketray/domain/rules/folder_names.dart';
import 'package:taketray/domain/rules/text_limits.dart';

part 'vn_repository.g.dart';

// Never log a folder name or file name (D-10): ids and counts only.
final Logger _log = Logger('vn');

/// Remembers which folder a reel's clips were copied into for VN, and which
/// files were copied there.
///
/// This only keeps the records; copying and deleting files is phase 8's job.
/// The records are what lets a file be found again, so the caller deletes the
/// files first and then calls [endSession] (or deletes the reel).
class VnRepository {
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Starts the VN session of reel [reelId] in a folder named after
  /// [baseFolderName], and returns it.
  ///
  /// The name is trimmed, and made unique with `uniqueFolderName` against the
  /// folders of every other session and [alsoTaken] (phase 8 passes the
  /// folders already in `Movies/TakeTray/`): "Goa", then "Goa (2)", ignoring
  /// case. A blank [baseFolderName] throws [ArgumentError]. Throws
  /// [StateError], saving nothing, when there is no reel [reelId] or it
  /// already has a session.
  Future<VnSession> startSession(
    int reelId,
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
        throw StateError('Reel $reelId already has a VN session');
      }
      final taken = {
        for (final s in await _db.select(_db.vnSessions).get()) s.folderName,
        ...alsoTaken,
      };
      final row = await _db
          .into(_db.vnSessions)
          .insertReturning(
            VnSessionsCompanion.insert(
              reelId: Value(reelId),
              folderName: uniqueFolderName(base, taken),
              createdAt: _clock.storedNow(),
            ),
          );
      return _toSession(row);
    });
    _log.info('Started the VN session of reel $reelId');
    return session;
  }

  /// The VN session of reel [reelId], or null when it has none.
  Future<VnSession?> sessionOf(int reelId) async {
    final row = await _sessionRow(reelId);
    return row == null ? null : _toSession(row);
  }

  /// Records that [copy] was made in its reel's VN folder.
  ///
  /// Throws [StateError], saving nothing, when the reel has no session or the
  /// session already has a copy of that clip (a second row would hide the
  /// first file). `copy.clipId` need not be a clip that still exists (D-54).
  Future<void> addCopy(VnCopy copy) async {
    await _db.transaction(() async {
      if (await _sessionRow(copy.reelId) == null) {
        throw StateError('Reel ${copy.reelId} has no VN session');
      }
      final existing =
          await (_db.select(_db.vnCopies)..where(
                (c) =>
                    c.reelId.equals(copy.reelId) & c.clipId.equals(copy.clipId),
              ))
              .getSingleOrNull();
      if (existing != null) {
        throw StateError(
          'Reel ${copy.reelId} already has a copy of clip ${copy.clipId}',
        );
      }
      await _db
          .into(_db.vnCopies)
          .insert(
            VnCopiesCompanion.insert(
              reelId: copy.reelId,
              clipId: copy.clipId,
              copyMediaStoreId: copy.copyMediaStoreId,
              fileName: copy.fileName,
              sizeBytes: copy.sizeBytes,
            ),
          );
    });
    _log.info(
      'Recorded a VN copy of clip ${copy.clipId} for reel ${copy.reelId}',
    );
  }

  /// The copies recorded for reel [reelId], by file name (which starts with
  /// the shooting time), ties by clip id.
  Future<List<VnCopy>> copiesOf(int reelId) async {
    final rows =
        await (_db.select(_db.vnCopies)
              ..where((c) => c.reelId.equals(reelId))
              ..orderBy([
                (c) => OrderingTerm.asc(c.fileName),
                (c) => OrderingTerm.asc(c.clipId),
              ]))
            .get();
    return [
      for (final row in rows)
        VnCopy(
          reelId: row.reelId,
          clipId: row.clipId,
          copyMediaStoreId: row.copyMediaStoreId,
          fileName: row.fileName,
          sizeBytes: row.sizeBytes,
        ),
    ];
  }

  /// Ends reel [reelId]'s session ("Done editing"): deletes the session and,
  /// with it (`ON DELETE CASCADE`), its copy records. An unknown reel or a
  /// reel with no session does nothing.
  ///
  /// The caller deletes the copy files first: afterwards nothing records which
  /// files were copied.
  Future<void> endSession(int reelId) async {
    final removed = await (_db.delete(
      _db.vnSessions,
    )..where((s) => s.reelId.equals(reelId))).go();
    _log.info('Ended the VN session of reel $reelId ($removed removed)');
  }

  Future<VnSessionRow?> _sessionRow(int reelId) => (_db.select(
    _db.vnSessions,
  )..where((s) => s.reelId.equals(reelId))).getSingleOrNull();

  VnSession _toSession(VnSessionRow row) => VnSession(
    reelId: row.reelId,
    folderName: row.folderName,
    createdAt: row.createdAt,
  );
}

@Riverpod(keepAlive: true)
VnRepository vnRepository(Ref ref) =>
    VnRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider));
