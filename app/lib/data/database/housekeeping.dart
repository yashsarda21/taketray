import 'package:drift/drift.dart';
import 'package:taketray/data/database/app_database.dart';

/// Clean-up that more than one repository needs, kept in one place so the
/// rule is written once.
extension Housekeeping on AppDatabase {
  /// Deletes every clip that is in no reel and not in To tag or Skipped
  /// (the orphan rule, D-56).
  ///
  /// A clip with neither a `clip_reels` row nor an `inbox` row is not
  /// reachable from any screen, so its record would only sit in the database.
  /// The video file itself is never touched.
  ///
  /// `vn_copies` rows are left alone: they have no foreign key to `clips` on
  /// purpose (D-54), because a VN copy file must still be found and deleted
  /// after its clip row is gone.
  ///
  /// Returns how many clips it deleted.
  ///
  /// The sweep is global, so a caller that inserts a clip must give it a
  /// `clip_reels` or `inbox` row in the same transaction, or a concurrent
  /// sweep could delete it first.
  ///
  /// This is one statement, so it is atomic by itself; callers that need it
  /// together with other changes run it inside their own `transaction`.
  Future<int> deleteOrphanClips() {
    final inAReel = selectOnly(clipReels)..addColumns([clipReels.clipId]);
    final inInbox = selectOnly(inbox)..addColumns([inbox.clipId]);
    return (delete(clips)..where(
          (c) => c.id.isNotInQuery(inAReel) & c.id.isNotInQuery(inInbox),
        ))
        .go();
  }
}
