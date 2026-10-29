import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';

/// Test setup for a repository: saving clips the way a scan does, without
/// asking whether a known clip is the same video.
extension ClipTestSetup on ClipsRepository {
  /// Saves [clips] with `addCheckedClips`, taking every clip that is already
  /// stored under the same identity to be the same video. Returns the ids in
  /// input order.
  Future<List<int>> saveDetected(List<NewClip> clips) async =>
      (await addCheckedClips(clips, sameVideo: (_, _) => true)).ids;
}

/// Test setup: flags the clips [ids] as `missing` (or not) with
/// `lastVerifiedAt` = [at], writing the rows directly, so a clip keeps its
/// place in To tag or a reel.
Future<void> flagClips(
  AppDatabase db,
  Set<int> ids, {
  required bool missing,
  required DateTime at,
}) => (db.update(db.clips)..where((c) => c.id.isIn(ids))).write(
  ClipsCompanion(missing: Value(missing), lastVerifiedAt: Value(at)),
);

/// Test setup: detaches the MediaStore clips [ids] by writing their rows
/// directly, the way a lost clip looks after a rebuild: `mediaStoreId` =
/// `-clipId`, `missing`, `lastVerifiedAt` = [at]. The clip keeps its place in
/// To tag or a reel.
Future<void> detachClips(
  AppDatabase db,
  Set<int> ids, {
  required DateTime at,
}) async {
  for (final id in ids) {
    await (db.update(db.clips)..where(
          (c) =>
              c.id.equals(id) &
              c.source.equalsValue(ClipSource.mediaStore) &
              c.mediaStoreId.isNotNull(),
        ))
        .write(
          ClipsCompanion(
            mediaStoreId: Value(-id),
            missing: const Value(true),
            lastVerifiedAt: Value(at),
          ),
        );
  }
}
