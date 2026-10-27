import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/rules/reference_url.dart';
import 'package:taketray/domain/rules/text_limits.dart';

part 'references_repository.g.dart';

// Never log a URL or a label (D-10): ids and counts only.
final Logger _log = Logger('references');

/// What [ReferencesRepository.add] did. Switch over it: the compiler makes
/// every caller handle both outcomes.
sealed class AddReferenceResult {
  const new();
}

/// The link was new for this reel and is now saved.
final class ReferenceAdded extends AddReferenceResult {
  const new(this.reference);

  final ReelReference reference;
}

/// The reel already had this page (after cleaning the link, D-55), so nothing
/// was saved. [existing] is the reference that was already there, unchanged.
final class ReferenceAlreadySaved extends AddReferenceResult {
  const new(this.existing);

  final ReelReference existing;
}

/// Saves, labels, deletes and watches the links on a reel.
///
/// Every link is cleaned by `normalizeReferenceUrl` before it is compared or
/// stored, so the same Instagram reel shared twice (`?igsh=...` differs) is
/// one reference (D-58). The database also holds a unique key on
/// (reel, url) as a safety net.
class ReferencesRepository {
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Saves [rawUrl] on reel [reelId], or reports that the reel already has it.
  ///
  /// The link is cleaned with `normalizeReferenceUrl`; one that is not an
  /// http(s) link throws [InvalidInputException] with
  /// `ReferenceUrlProblem.invalid`. [label] is trimmed, must be at most 60
  /// characters (`ReferenceLabelProblem.tooLong` otherwise) and an empty one
  /// means no label. Nothing is saved when it throws.
  ///
  /// A new reference sets the reel's `updatedAt` to now. An already-saved link
  /// keeps its label and time, [label] is ignored, and the reel is not touched.
  /// Throws [StateError], saving nothing, when there is no reel [reelId].
  Future<AddReferenceResult> add(
    int reelId,
    String rawUrl, {
    String? label,
  }) async {
    final url = normalizeReferenceUrl(rawUrl);
    if (url == null) {
      throw const InvalidInputException(ReferenceUrlProblem.invalid);
    }
    final problem = checkReferenceLabel(label);
    if (problem != null) {
      throw InvalidInputException(problem);
    }

    final result = await _db.transaction<AddReferenceResult>(() async {
      await _requireReel(reelId);
      final existing =
          await (_db.select(_db.reelReferences)..where(
                (r) => r.reelId.equals(reelId) & r.url.equals(url.toString()),
              ))
              .getSingleOrNull();
      if (existing != null) {
        return ReferenceAlreadySaved(_toReference(existing));
      }

      final row = await _db
          .into(_db.reelReferences)
          .insertReturning(
            ReelReferencesCompanion.insert(
              reelId: reelId,
              url: url.toString(),
              source: referenceSourceOf(url),
              label: Value(_cleanLabel(label)),
              createdAt: _clock.now(),
            ),
          );
      await _touchReel(reelId);
      return ReferenceAdded(_toReference(row));
    });
    _log.info(
      result is ReferenceAdded
          ? 'Added reference ${result.reference.id} to reel $reelId'
          : 'Reel $reelId already had the reference',
    );
    return result;
  }

  /// Sets or clears (null, empty or blank) the label of reference [id]. The
  /// label is checked as in [add], and nothing changes when it throws. Sets the
  /// reel's `updatedAt` to now. Throws [StateError] when there is no such
  /// reference.
  Future<void> setLabel(int id, String? label) async {
    final problem = checkReferenceLabel(label);
    if (problem != null) {
      throw InvalidInputException(problem);
    }

    await _db.transaction(() async {
      final row = await (_db.select(
        _db.reelReferences,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (row == null) throw StateError('No reference with id $id');
      await (_db.update(_db.reelReferences)..where((r) => r.id.equals(id)))
          .write(ReelReferencesCompanion(label: Value(_cleanLabel(label))));
      await _touchReel(row.reelId);
    });
    _log.info('Set the label of reference $id');
  }

  /// Deletes reference [id] and sets its reel's `updatedAt` to now; an unknown
  /// id deletes nothing and changes nothing. The same link can be saved again
  /// afterwards.
  Future<void> delete(int id) async {
    final removed = await _db.transaction(() async {
      final row = await (_db.select(
        _db.reelReferences,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (row == null) return 0;
      await (_db.delete(
        _db.reelReferences,
      )..where((r) => r.id.equals(id))).go();
      await _touchReel(row.reelId);
      return 1;
    });
    _log.info('Deleted $removed references (id $id)');
  }

  /// The references of reel [reelId], newest first (ties: highest id first),
  /// again after every change.
  Stream<List<ReelReference>> watchForReel(int reelId) =>
      (_db.select(_db.reelReferences)
            ..where((r) => r.reelId.equals(reelId))
            ..orderBy([
              (r) => OrderingTerm.desc(r.createdAt),
              (r) => OrderingTerm.desc(r.id),
            ]))
          .watch()
          .map((rows) => [for (final row in rows) _toReference(row)]);

  /// How many references each reel has (reel id to count), again after every
  /// change. A reel with none is not in the map.
  Stream<Map<int, int>> watchCounts() {
    final count = _db.reelReferences.id.count();
    final query = _db.selectOnly(_db.reelReferences)
      ..addColumns([_db.reelReferences.reelId, count])
      ..groupBy([_db.reelReferences.reelId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.reelReferences.reelId)!: row.read(count)!,
      },
    );
  }

  /// A blank label is no label; otherwise the trimmed text.
  String? _cleanLabel(String? label) {
    if (label == null) return null;
    final trimmed = normalizeName(label);
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Sets the reel's `updatedAt` to now, so a reference change moves the reel
  /// to the top of Home (D-58). Run inside a transaction.
  Future<void> _touchReel(int reelId) =>
      (_db.update(_db.reels)..where((r) => r.id.equals(reelId))).write(
        ReelsCompanion(updatedAt: Value(_clock.now())),
      );

  Future<void> _requireReel(int reelId) async {
    final row = await (_db.select(
      _db.reels,
    )..where((r) => r.id.equals(reelId))).getSingleOrNull();
    if (row == null) throw StateError('No reel with id $reelId');
  }

  ReelReference _toReference(ReelReferenceRow row) => ReelReference(
    id: row.id,
    reelId: row.reelId,
    url: row.url,
    source: row.source,
    label: row.label,
    createdAt: row.createdAt,
  );
}

@Riverpod(keepAlive: true)
ReferencesRepository referencesRepository(Ref ref) => ReferencesRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
);
