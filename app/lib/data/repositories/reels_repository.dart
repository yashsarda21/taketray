import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/database/housekeeping.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';

part 'reels_repository.g.dart';

// Never log a reel name (D-10): ids and counts only.
final Logger _log = Logger('reels');

/// Creates, edits, watches and deletes reels.
///
/// Screens use this instead of the database: it checks the rules (a name is 1
/// to 40 characters) and keeps `updatedAt` honest. A reel's clips, references
/// and VN session live in other tables and are handled by their own
/// repositories; this one only removes them when the reel goes.
///
/// Reel names are not unique (D-56): two reels may both be called "Goa".
class ReelsRepository {
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Saves a new reel, `collecting`, created and updated now.
  ///
  /// [name] is trimmed and must be 1 to 40 characters, otherwise this throws
  /// [InvalidInputException] with a [ReelNameProblem] and saves nothing. A
  /// null, empty or blank [description] is stored as null.
  Future<Reel> create(String name, {String? description}) async {
    _checkName(name);
    final now = _clock.now();
    final row = await _db
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
    _log.info('Created reel ${row.id}');
    return _toReel(row);
  }

  /// Renames reel [id]. The name is checked as in [create]. Throws
  /// [StateError] when there is no such reel.
  Future<void> rename(int id, String name) async {
    _checkName(name);
    await _update(id, ReelsCompanion(name: Value(normalizeName(name))));
  }

  /// Sets or clears (null, empty or blank) the description of reel [id].
  /// Throws [StateError] when there is no such reel.
  Future<void> setDescription(int id, String? description) => _update(
    id,
    ReelsCompanion(description: Value(_cleanDescription(description))),
  );

  /// Sets the status of reel [id]. Throws [StateError] when there is no such
  /// reel.
  Future<void> setStatus(int id, ReelStatus status) =>
      _update(id, ReelsCompanion(status: Value(status)));

  /// Deletes reel [id], its clip links, references and VN session, then every
  /// clip that is left in no reel and not in To tag or Skipped. All of it
  /// happens in one transaction: either everything goes or nothing does.
  ///
  /// A clip that is also in another reel, or in To tag or Skipped, stays. The
  /// `vn_copies` rows of a removed clip stay too (D-54).
  ///
  /// The caller deletes this reel's VN copy files first (phase 8): once the
  /// reel is gone, nothing in the database says which files were copied.
  ///
  /// An unknown [id] deletes no reel, but the orphan sweep still runs, so any
  /// clip that is in no reel and no list is removed anyway.
  Future<void> delete(int id) async {
    final (reels, orphans) = await _db.transaction(() async {
      // The links, references and VN rows go with the reel: ON DELETE CASCADE.
      final reels = await (_db.delete(
        _db.reels,
      )..where((r) => r.id.equals(id))).go();
      return (reels, await _db.deleteOrphanClips());
    });
    _log.info('Delete reel $id: removed $reels reel, swept $orphans clips');
  }

  /// Reel [id], or null when there is none.
  Future<Reel?> getById(int id) async {
    final row = await (_db.select(
      _db.reels,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toReel(row);
  }

  /// Reel [id] now and again after every change to it; null once it is gone.
  Stream<Reel?> watchById(int id) =>
      (_db.select(_db.reels)..where((r) => r.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toReel(row));

  /// Every reel, most recently updated first (ties: highest id first), again
  /// after every change.
  Stream<List<Reel>> watchAll() =>
      (_db.select(_db.reels)..orderBy([
            (r) => OrderingTerm.desc(r.updatedAt),
            (r) => OrderingTerm.desc(r.id),
          ]))
          .watch()
          .map((rows) => [for (final row in rows) _toReel(row)]);

  void _checkName(String name) {
    final problem = checkReelName(name);
    if (problem != null) throw InvalidInputException(problem);
  }

  String? _cleanDescription(String? description) {
    if (description == null) return null;
    final cleaned = normalizeName(description);
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _update(int id, ReelsCompanion changes) async {
    final updated = await (_db.update(_db.reels)..where((r) => r.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value(_clock.now())));
    if (updated == 0) throw StateError('No reel with id $id');
  }

  Reel _toReel(ReelRow row) => Reel(
    id: row.id,
    name: row.name,
    description: row.description,
    status: row.status,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

@Riverpod(keepAlive: true)
ReelsRepository reelsRepository(Ref ref) =>
    ReelsRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider));
