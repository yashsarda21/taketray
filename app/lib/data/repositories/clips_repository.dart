import 'dart:math';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/clip_rules.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/database/housekeeping.dart';
import 'package:taketray/data/repositories/undo_writer.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';

part 'clips_repository.g.dart';

// Never log a clip's display name, path or URI (D-10): ids and counts only.
final Logger _log = Logger('clips');

/// Detects, tags, skips, adds and removes clips, and watches them.
///
/// A clip is in one of three places: in To tag (an `inbox` row, `pending`), in
/// Skipped (an `inbox` row, `skipped`), or in one or more reels (`clip_reels`
/// rows). A clip in none of them is an orphan and is deleted (D-56), so every
/// method that inserts a clip also gives it a place in the same transaction.
///
/// A clip's identity is `volumeName` + `mediaStoreId` for a detected clip, or
/// `pickerUri` for a picked one (D-57). Saving a clip that is already known
/// finds it instead of inserting it again.
///
/// Every `Iterable<int>` / `Set<int>` of ids is treated as a set: duplicates
/// are ignored.
class ClipsRepository {
  new(this._db, this._clock) : _undo = UndoWriter(_db, _clock);

  final AppDatabase _db;
  final Clock _clock;
  final UndoWriter _undo;

  /// Saves clips read from the phone's media library (Shooting mode, a
  /// rescan, "Add earlier videos") and puts the new ones in To tag as
  /// `pending`, with a check of every clip that is already known (D-72,
  /// Ruling U). Returns the ids in input order, the ones that are new and the
  /// ones detached.
  ///
  /// It is idempotent: a clip whose identity is already known and is the
  /// same video is not inserted, not put in To tag again and keeps its
  /// `firstSeenAt`; its existing id is returned. So a clip seen twice (a
  /// rescan, or a crash between saving the clips and moving the baseline) is
  /// still one clip, a clip already tagged into a reel does not come back to
  /// To tag, and a clip that was skipped stays skipped.
  ///
  /// A stored MediaStore clip holding a clip's (volume, number) is asked
  /// [sameVideo]. When it is not the same video, it is provably not this one
  /// (an imported clip holding a number this phone gave another video, say):
  /// it is detached (`mediaStoreId = -clipId`, `missing`, `lastVerifiedAt` =
  /// now) and the clip is inserted as new, into To tag. A detached clip in a
  /// reel stays there, flagged; one only in To tag or Skipped leaves it and is
  /// swept (Ruling Y). The detach, that removal and the insert are one
  /// transaction, and a new clip is inserted together with its `inbox` row so
  /// a concurrent orphan sweep cannot delete it.
  Future<DetectedClips> addCheckedClips(
    List<NewClip> clips, {
    required bool Function(Clip stored, NewClip incoming) sameVideo,
  }) async {
    final result = await _db.transaction(() async {
      final now = _clock.now();
      final ids = <int>[];
      final inserted = <int>[];
      final detached = <int>{};
      for (final clip in clips) {
        final known = await _findId(clip);
        if (known != null) {
          final row = await (_db.select(
            _db.clips,
          )..where((c) => c.id.equals(known))).getSingle();
          if (sameVideo(_toClip(row), clip)) {
            ids.add(known);
            continue;
          }
          await _markDetached({known}, now);
          detached.add(known);
        }
        final id = await _insertClip(clip, now);
        await _db
            .into(_db.inbox)
            .insert(
              InboxCompanion.insert(
                clipId: Value(id),
                state: InboxState.pending,
                addedAt: now,
              ),
            );
        ids.add(id);
        inserted.add(id);
      }
      // A detached clip that is only in To tag or Skipped leaves it (Ruling
      // Y, the D-71 rule), in this transaction; one in a reel stays, flagged.
      if (detached.isNotEmpty) await _removeMissing(detached);
      return DetectedClips(ids: ids, inserted: inserted, detached: detached);
    });
    _log.info(
      'Detected ${clips.length} clips, ${result.inserted.length} new, '
      '${result.detached.length} detached',
    );
    return result;
  }

  /// Saves clips and adds them to reel [reelId] (phase 7: the user picks
  /// videos by hand). Returns their ids, in input order.
  ///
  /// The same identity rule as [addCheckedClips], but a new clip gets a link
  /// to the reel instead of an `inbox` row. A known clip is found and linked,
  /// and leaves To tag or Skipped (its `inbox` row is deleted), as when it is
  /// tagged. A clip the reel already has keeps its `addedAt`. The reel's
  /// `updatedAt` moves only when a link was added.
  ///
  /// Inserting and linking are one transaction, because the orphan sweep is
  /// global: a clip with neither a link nor an `inbox` row could be deleted by
  /// any other delete before it was linked. Throws [StateError], saving
  /// nothing, when there is no reel [reelId].
  Future<List<int>> addNewClipsToReel(int reelId, List<NewClip> clips) async {
    final ids = await _db.transaction(() async {
      await _requireReel(reelId);
      final now = _clock.now();
      final ids = <int>[];
      for (final clip in clips) {
        ids.add(await _findId(clip) ?? await _insertClip(clip, now));
      }
      await _link(reelId, ids.toSet(), now);
      return ids;
    });
    _log.info('Added ${clips.length} picked clips to reel $reelId');
    return ids;
  }

  /// Files clip [clipId] into exactly the reels [reelIds] and takes it out of
  /// To tag or Skipped.
  ///
  /// The clip's links are replaced: reels it was in but are not in [reelIds]
  /// lose it, new ones gain it, and a reel it stays in keeps the original
  /// `addedAt`, which says when the clip joined that reel. The `updatedAt` of
  /// every reel that gained or lost the clip is set to now.
  ///
  /// Throws [ArgumentError] when [reelIds] is empty (a clip with no reel is
  /// [untagToInbox]), and [StateError], changing nothing, when the clip or a
  /// reel does not exist.
  Future<void> tagClip(int clipId, Set<int> reelIds) async {
    if (reelIds.isEmpty) {
      throw ArgumentError.value(reelIds, 'reelIds', 'must not be empty');
    }
    final changed = await _db.transaction(() async {
      await _requireClip(clipId);
      await _requireReels(reelIds);
      final now = _clock.now();
      final current = await _reelIdsOf(clipId);
      final gained = reelIds.difference(current);
      final lost = current.difference(reelIds);
      if (lost.isNotEmpty) {
        await (_db.delete(
          _db.clipReels,
        )..where((l) => l.clipId.equals(clipId) & l.reelId.isIn(lost))).go();
      }
      for (final reelId in gained) {
        await _insertLink(clipId, reelId, now);
      }
      await (_db.delete(_db.inbox)..where((i) => i.clipId.equals(clipId))).go();
      await _touchReels({...gained, ...lost}, now);
      return gained.length + lost.length;
    });
    _log.info(
      'Tagged clip $clipId into ${reelIds.length} reels, '
      '$changed links changed',
    );
  }

  /// Undo for [tagClip]: removes every reel link of clip [clipId] and puts the
  /// clip back in To tag as `pending`. The `updatedAt` of the reels that lost
  /// it is set to now. Throws [StateError] when there is no such clip.
  ///
  /// This is bigger than "undo the last tag": it removes *every* link, also
  /// ones that existed before the last [tagClip], and it rewrites the `inbox`
  /// row of a clip that is already pending (its `addedAt` becomes now). The
  /// clip stays in the database: it has an `inbox` row again.
  Future<void> untagToInbox(int clipId) async {
    await _db.transaction(() async {
      await _requireClip(clipId);
      final now = _clock.now();
      final reelIds = await _reelIdsOf(clipId);
      await (_db.delete(
        _db.clipReels,
      )..where((l) => l.clipId.equals(clipId))).go();
      await _db
          .into(_db.inbox)
          .insertOnConflictUpdate(
            InboxCompanion.insert(
              clipId: Value(clipId),
              state: InboxState.pending,
              addedAt: now,
            ),
          );
      await _touchReels(reelIds, now);
    });
    _log.info('Moved clip $clipId back to To tag');
  }

  /// Moves clips from To tag to Skipped. A clip with no `inbox` row (one that
  /// is in a reel) is left alone.
  Future<void> skip(Iterable<int> clipIds) =>
      _setInboxState(clipIds, InboxState.skipped);

  /// Moves clips from Skipped back to To tag. A clip with no `inbox` row is
  /// left alone.
  Future<void> restore(Iterable<int> clipIds) =>
      _setInboxState(clipIds, InboxState.pending);

  /// Adds existing clips to reel [reelId]. A clip the reel already has keeps
  /// its `addedAt`. The reel's `updatedAt` is set to now when a link was
  /// added. The clips leave To tag and Skipped (their `inbox` rows are
  /// deleted, whatever their state), as when they are tagged: adding a clip to
  /// a reel by hand is a stronger choice than leaving it for later.
  ///
  /// Returns what [undo] needs (D-84): the links it created (not the ones
  /// that were there), the `inbox` rows it deleted, and the reel's
  /// `updatedAt` before.
  ///
  /// Throws [StateError], changing nothing, when the reel or a clip does not
  /// exist.
  Future<AddUndo> addClipsToReel(int reelId, Iterable<int> clipIds) async {
    final ids = clipIds.toSet();
    final record = await _db.transaction(() => _addToReel(reelId, ids));
    _log.info(
      'Added ${ids.length} clips to reel $reelId, '
      '${record.createdLinks.length} new',
    );
    return record;
  }

  /// Adds existing clips to every reel of [reelIds], as [addClipsToReel] does
  /// for one, in **one** transaction (D-84 point 8): if any reel or clip is
  /// gone, or any write fails, nothing is added to any reel and the error is
  /// thrown.
  ///
  /// Returns one record for each reel, in the order of [reelIds]. Undo them
  /// last to first: the first record is the one that holds the `inbox` rows
  /// the add deleted, and the later ones only link the clips.
  Future<List<AddUndo>> addClipsToReels(
    Set<int> reelIds,
    Iterable<int> clipIds,
  ) async {
    final ids = clipIds.toSet();
    final records = await _db.transaction(() async {
      final records = <AddUndo>[];
      for (final reelId in reelIds) {
        records.add(await _addToReel(reelId, ids));
      }
      return records;
    });
    _log.info(
      'Added ${ids.length} clips to ${reelIds.length} reels, '
      '${records.fold<int>(0, (sum, r) => sum + r.createdLinks.length)} new',
    );
    return records;
  }

  /// The body of an add, inside the caller's transaction.
  Future<AddUndo> _addToReel(int reelId, Set<int> ids) async {
    await _requireReel(reelId);
    for (final id in ids) {
      await _requireClip(id);
    }
    final before = (await _undo.updatedAtOf(reelId))!;
    final inbox = ids.isEmpty
        ? const <InboxRow>[]
        : await (_db.select(_db.inbox)..where((i) => i.clipId.isIn(ids))).get();
    final now = _clock.now();
    final created = await _link(reelId, ids, now);
    return AddUndo(
      reelId: reelId,
      createdLinks: [
        for (final clipId in created)
          ClipLink(clipId: clipId, reelId: reelId, addedAt: now),
      ],
      removedInbox: [
        for (final row in inbox)
          InboxEntry(
            clipId: row.clipId,
            state: row.state,
            addedAt: row.addedAt,
          ),
      ],
      touch: created.isEmpty
          ? null
          : ReelTouch(reelId: reelId, before: before, after: now),
    );
  }

  /// Removes clips from reel [reelId], sets the reel's `updatedAt` to now when
  /// a link was removed, then deletes every clip left in no reel and not in
  /// To tag or Skipped (the orphan rule, D-56), all in one transaction.
  ///
  /// A clip that is in another reel or in a list stays. The `vn_copies` row of
  /// a deleted clip stays too (D-54). Clips the reel does not have are ignored.
  /// The caller deletes the clip's VN copy file first when there is a VN
  /// session (phase 8). Throws [StateError] when there is no such reel.
  ///
  /// Returns what [undo] needs (D-84): the removed links with their
  /// `addedAt`, every field of the clips the sweep deleted (read in this
  /// transaction, before they go), and the reel's `updatedAt` before.
  Future<RemoveUndo> removeClipsFromReel(
    int reelId,
    Iterable<int> clipIds,
  ) async {
    final ids = clipIds.toSet();
    final record = await _db.transaction(() async {
      await _requireReel(reelId);
      final before = (await _undo.updatedAtOf(reelId))!;
      final now = _clock.now();
      final (removed, swept) = await _unlinkAndSweep(reelId, ids, now);
      return RemoveUndo(
        reelId: reelId,
        removedLinks: removed,
        sweptClips: swept,
        touch: removed.isEmpty
            ? null
            : ReelTouch(reelId: reelId, before: before, after: now),
      );
    });
    _log.info(
      'Removed ${record.removedLinks.length} clips from reel $reelId, '
      'swept ${record.sweptClips.length}',
    );
    return record;
  }

  /// Moves clips from reel [fromReelId] to reel [toReelId], in one
  /// transaction: each clip that is in the source gets a link to the target
  /// (`addedAt` now; a clip the target already has keeps its link), and only
  /// then loses its source link, so the orphan sweep that follows never sees
  /// it without a place. Clips the source does not have are ignored. Each
  /// reel's `updatedAt` is set to now when it gained or lost a link.
  ///
  /// Returns what [undo] needs (D-84): the links created in the target (not
  /// the ones that were there), the removed source links with their
  /// `addedAt`, and both reels' `updatedAt` before.
  ///
  /// Throws [ArgumentError] when the two reels are the same, and
  /// [StateError], changing nothing, when either reel does not exist.
  Future<MoveUndo> moveClips(
    int fromReelId,
    int toReelId,
    Iterable<int> clipIds,
  ) async {
    if (fromReelId == toReelId) {
      throw ArgumentError.value(toReelId, 'toReelId', 'is the source reel');
    }
    final ids = clipIds.toSet();
    final record = await _db.transaction(() async {
      await _requireReels({fromReelId, toReelId});
      final beforeFrom = (await _undo.updatedAtOf(fromReelId))!;
      final beforeTo = (await _undo.updatedAtOf(toReelId))!;
      final now = _clock.now();
      final inSource = ids.isEmpty
          ? const <int>{}
          : {
              for (final link
                  in await (_db.select(_db.clipReels)..where(
                        (l) => l.reelId.equals(fromReelId) & l.clipId.isIn(ids),
                      ))
                      .get())
                link.clipId,
            };
      // Add first, then remove: the removal runs the orphan sweep, and a clip
      // only in the source must already have its target link by then.
      final created = await _link(toReelId, inSource, now);
      final (removed, swept) = await _unlinkAndSweep(fromReelId, inSource, now);
      if (swept.isNotEmpty) {
        // Only clips that were orphans before the move: every moved clip has
        // its target link.
        _log.warning('Move swept ${swept.length} clips that had no place');
      }
      return MoveUndo(
        fromReelId: fromReelId,
        toReelId: toReelId,
        createdLinks: [
          for (final clipId in created)
            ClipLink(clipId: clipId, reelId: toReelId, addedAt: now),
        ],
        removedLinks: removed,
        touches: [
          if (removed.isNotEmpty)
            ReelTouch(reelId: fromReelId, before: beforeFrom, after: now),
          if (created.isNotEmpty)
            ReelTouch(reelId: toReelId, before: beforeTo, after: now),
        ],
      );
    });
    _log.info(
      'Moved ${record.removedLinks.length} clips from reel $fromReelId to '
      '$toReelId, ${record.createdLinks.length} new links',
    );
    return record;
  }

  /// Puts back what a remove, move, add or reel delete changed, with the same
  /// ids, in one transaction (D-84). Idempotent; a reel that is gone gets
  /// nothing back. See `UndoWriter.undo`.
  Future<void> undo(UndoRecord record) => _undo.undo(record);

  /// The MediaStore clips on volume [volumeName] that still hold a MediaStore
  /// id: the ones a verifier or a rebuild match can look for. Detached clips
  /// (`mediaStoreId` below 1, see [applyVerification]), picked clips (also
  /// one that has a volume and an id) and clips of other volumes are not in
  /// it; a clip flagged missing that kept its id is. By id.
  Future<List<Clip>> mediaStoreClipsOn(String volumeName) async {
    final rows =
        await (_db.select(_db.clips)
              ..where(
                (c) =>
                    c.source.equalsValue(ClipSource.mediaStore) &
                    c.volumeName.equals(volumeName) &
                    c.mediaStoreId.isBiggerThanValue(0),
              )
              ..orderBy([(c) => OrderingTerm.asc(c.id)]))
            .get();
    return [for (final row in rows) _toClip(row)];
  }

  /// The attached MediaStore clips on volume [volumeName] that hold one of
  /// [mediaStoreIds], by number: the clips [addCheckedClips] would ask about.
  /// Picked clips and detached ones (they hold `-clipId`) are not in it.
  /// Asked in batches of [idBatch].
  Future<Map<int, Clip>> mediaStoreClipsHolding(
    String volumeName,
    Iterable<int> mediaStoreIds,
  ) async {
    final held = <int, Clip>{};
    for (final batch in _batches(mediaStoreIds.toSet())) {
      final rows =
          await (_db.select(_db.clips)..where(
                (c) =>
                    c.source.equalsValue(ClipSource.mediaStore) &
                    c.volumeName.equals(volumeName) &
                    c.mediaStoreId.isIn(batch),
              ))
              .get();
      for (final row in rows) {
        held[row.mediaStoreId!] = _toClip(row);
      }
    }
    return held;
  }

  /// The clips with these ids that exist, by id. Unknown ids are left out.
  /// Asked in batches of [idBatch].
  Future<List<Clip>> clipsByIds(Iterable<int> clipIds) async {
    final rows = <ClipRow>[];
    for (final batch in _batches(clipIds.toSet())) {
      rows.addAll(
        await (_db.select(_db.clips)..where((c) => c.id.isIn(batch))).get(),
      );
    }
    rows.sort((a, b) => a.id.compareTo(b.id));
    return [for (final row in rows) _toClip(row)];
  }

  /// The ids of every stored clip.
  Future<Set<int>> allClipIds() async {
    final query = _db.selectOnly(_db.clips)..addColumns([_db.clips.id]);
    return (await query.map((row) => row.read(_db.clips.id)!).get()).toSet();
  }

  /// How many ids one `IN (...)` query takes, well below SQLite's limit on
  /// bound variables.
  static const idBatch = 500;

  static Iterable<List<int>> _batches(Set<int> ids) sync* {
    final list = ids.toList();
    for (var start = 0; start < list.length; start += idBatch) {
      yield list.sublist(start, min(start + idBatch, list.length));
    }
  }

  /// Applies what `matchAfterRebuild` found after Android rebuilt volume
  /// [volumeName]'s media library, in one transaction (D-71):
  ///
  /// 1. Every clip in `match.remap` and `match.lost` is detached: its
  ///    `mediaStoreId` becomes `-clipId`. Nothing holds a positive id any
  ///    more, so ids can be swapped or rotated, and a clip may take the old
  ///    id of a lost one, without the unique key (volume, id) ever clashing.
  /// 2. A clip in `remap` gets its new id, `missing = false` and
  ///    `lastVerifiedAt` = now.
  /// 3. A clip in `lost` keeps `-clipId`, with `missing = true` and
  ///    `lastVerifiedAt` = now, so its old number can never match a
  ///    different video. A lost clip in a reel stays there, flagged; one that
  ///    is only in To tag or Skipped leaves it and, in no other place, is
  ///    swept (Ruling Y, the D-71 rule), in this same transaction.
  ///
  /// Only attached MediaStore clips of this volume (source `mediaStore`,
  /// `mediaStoreId` above 0) are touched. A clip in the match that is already
  /// detached, a picked clip (also one with a volume and an id), a clip of
  /// another volume and an unknown id are ignored, so a stale match cannot
  /// re-attach a detached clip.
  ///
  /// Throws [ArgumentError], changing nothing, for an invalid match: a clip
  /// in both sets, two clips with one new id, or a new id below 1. Throws
  /// [StateError], rolling every change back, when a clip outside the match
  /// holds a new id (the id would belong to two clips).
  Future<void> applyRebuildMatch(String volumeName, RebuildMatch match) async {
    final both = match.remap.keys.toSet().intersection(match.lost);
    if (both.isNotEmpty) {
      throw ArgumentError.value(
        both,
        'match',
        'a clip cannot be both found and lost',
      );
    }
    final targets = match.remap.values.toList();
    if (targets.any((id) => id < 1)) {
      throw ArgumentError.value(
        match.remap,
        'match',
        'a new MediaStore id must be above 0',
      );
    }
    if (targets.toSet().length != targets.length) {
      throw ArgumentError.value(
        match.remap,
        'match',
        'two clips cannot get the same MediaStore id',
      );
    }
    if (match.remap.isEmpty && match.lost.isEmpty) return;

    final applied = await _db.transaction(() async {
      final now = _clock.now();
      // Only attached MediaStore clips of this volume take part: a clip that
      // is detached already (a stale match), a picked clip, a clip of another
      // volume and an unknown id are ignored.
      final ids = {...match.remap.keys, ...match.lost};
      final rows =
          await (_db.select(_db.clips)..where(
                (c) =>
                    c.id.isIn(ids) &
                    c.source.equalsValue(ClipSource.mediaStore) &
                    c.volumeName.equals(volumeName) &
                    c.mediaStoreId.isBiggerThanValue(0),
              ))
              .get();
      final eligible = {for (final row in rows) row.id};
      final remap = {
        for (final MapEntry(key: clipId, value: newId) in match.remap.entries)
          if (eligible.contains(clipId)) clipId: newId,
      };
      final lost = match.lost.intersection(eligible);

      for (final clipId in eligible) {
        await _setMediaStoreId(volumeName, clipId, -clipId);
      }
      // Every clip of the match is negative now, so a positive holder of a
      // new id is a clip outside the match.
      final clash =
          await (_db.select(_db.clips)..where(
                (c) =>
                    c.volumeName.equals(volumeName) &
                    c.mediaStoreId.isIn(remap.values),
              ))
              .get();
      if (clash.isNotEmpty) {
        throw StateError(
          '${clash.length} clips outside the match hold a new MediaStore id',
        );
      }
      for (final MapEntry(key: clipId, value: newId) in remap.entries) {
        await _setMediaStoreId(
          volumeName,
          clipId,
          newId,
          verification: ClipsCompanion(
            missing: const Value(false),
            lastVerifiedAt: Value(now),
          ),
        );
      }
      await _markDetached(lost, now, volumeName: volumeName);
      // A lost clip that is only in To tag or Skipped leaves it (Ruling Y,
      // the D-71 rule); one in a reel stays there, flagged missing.
      final swept = lost.isEmpty ? 0 : await _removeMissing(lost);
      return (remap.length, lost.length, swept);
    });
    _log.info(
      'Applied a rebuild: ${applied.$1} found, ${applied.$2} lost, '
      '${applied.$3} left the lists',
    );
  }

  /// Undo for "Add earlier videos" (D-75): takes the just-added clips in
  /// [clipIds] back out of To tag. In one transaction it deletes the `inbox`
  /// row of each id that is still waiting in To tag ([InboxState.pending])
  /// and in no reel, then runs the orphan sweep (D-56). Returns how many
  /// clips were deleted.
  ///
  /// A clip that was tagged into a reel, or skipped, since it was added is
  /// the user's work now, so it keeps its row, its link and its state. Unknown
  /// ids are ignored, an empty set writes nothing, and a second undo of the
  /// same ids deletes nothing. The sweep is global (as in every use of it), so
  /// a clip that was already in no reel and no list goes too. The ids are
  /// handled in batches of [idBatch], all in the one transaction. The video
  /// files are never touched.
  ///
  /// This is only the database step. The caller runs it on the media queue,
  /// so it cannot interleave with a scan.
  Future<int> undoEarlierAdd(Set<int> clipIds) async {
    if (clipIds.isEmpty) return 0;
    final deleted = await _db.transaction(() async {
      final inAReel = _db.selectOnly(_db.clipReels)
        ..addColumns([_db.clipReels.clipId]);
      for (final batch in _batches(clipIds)) {
        await (_db.delete(_db.inbox)..where(
              (i) =>
                  i.clipId.isIn(batch) &
                  i.state.equalsValue(InboxState.pending) &
                  i.clipId.isNotInQuery(inAReel),
            ))
            .go();
      }
      return await _db.deleteOrphanClips();
    });
    _log.info('Undid an earlier add: removed $deleted clips');
    return deleted;
  }

  /// Writes what one verify found, in one transaction (D-72), so a crash
  /// cannot leave a detached clip in To tag:
  ///
  /// 1. [otherVideo] (their number now holds another video) are detached:
  ///    each gets `mediaStoreId = -clipId`, `missing = true` and
  ///    `lastVerifiedAt` = now, like a lost clip in [applyRebuildMatch]. The
  ///    clip keeps its row and its place, but its old number can no longer be
  ///    found or matched to a new video: a video that later gets that number
  ///    is a new clip. Unknown ids and clips that are not MediaStore clips
  ///    (picked ones) are ignored;
  /// 2. [gone] are flagged missing and [found] not missing, with
  ///    `lastVerifiedAt` = now for both;
  /// 3. [gone] and [otherVideo] leave To tag and Skipped: the `inbox` rows of
  ///    those flagged `missing` (checked in the same transaction, so a clip
  ///    that was not flagged, a picked one, keeps its row) go, then the clips
  ///    left in no reel and no list (the orphan rule, D-56). A clip in a reel
  ///    is only ever flagged, never removed: its link and its row stay, even
  ///    if it also has an `inbox` row (only that row goes). The video file is
  ///    never touched, and neither is a `vn_copies` row (D-54).
  ///
  /// Returns how many clips were deleted. Throws [ArgumentError], writing
  /// nothing, when a clip is in two of the sets. Empty sets write nothing.
  Future<int> applyVerification({
    required Set<int> found,
    required Set<int> gone,
    required Set<int> otherVideo,
  }) async {
    if (found.intersection(gone).isNotEmpty ||
        found.intersection(otherVideo).isNotEmpty ||
        gone.intersection(otherVideo).isNotEmpty) {
      throw ArgumentError('A clip can be in only one verification set');
    }
    if (found.isEmpty && gone.isEmpty && otherVideo.isEmpty) return 0;
    final deleted = await _db.transaction(() async {
      final now = _clock.now();
      await _markDetached(otherVideo, now);
      await _markVerified(gone, isMissing: true, at: now);
      await _markVerified(found, isMissing: false, at: now);
      final missing = {...gone, ...otherVideo};
      return missing.isEmpty ? 0 : await _removeMissing(missing);
    });
    _log.info(
      'Applied a verification: ${found.length} found, ${gone.length} gone, '
      '${otherVideo.length} detached, $deleted left the lists',
    );
    return deleted;
  }

  /// The inbox rows of the clips in [clipIds] that are flagged missing go,
  /// then the orphan sweep. Run inside a transaction.
  Future<int> _removeMissing(Set<int> clipIds) async {
    final missing = _db.selectOnly(_db.clips)
      ..addColumns([_db.clips.id])
      ..where(_db.clips.missing.equals(true));
    await (_db.delete(
      _db.inbox,
    )..where((i) => i.clipId.isIn(clipIds) & i.clipId.isInQuery(missing))).go();
    return await _db.deleteOrphanClips();
  }

  /// The clips in To tag ([InboxState.pending]) or Skipped
  /// ([InboxState.skipped]), by shooting time, oldest first (ties: lowest id
  /// first), again after every change.
  Stream<List<Clip>> watchInbox(InboxState state) {
    final query =
        _db.select(_db.inbox).join([
            innerJoin(_db.clips, _db.clips.id.equalsExp(_db.inbox.clipId)),
          ])
          ..where(_db.inbox.state.equalsValue(state))
          ..orderBy([
            OrderingTerm.asc(_db.clips.dateTakenUtc),
            OrderingTerm.asc(_db.clips.id),
          ]);
    return query.watch().map(
      (rows) => [for (final row in rows) _toClip(row.readTable(_db.clips))],
    );
  }

  /// How many clips are waiting in To tag, again after every change.
  Stream<int> watchPendingCount() {
    final count = _db.inbox.clipId.count();
    final query = _db.selectOnly(_db.inbox)
      ..addColumns([count])
      ..where(_db.inbox.state.equalsValue(InboxState.pending));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// The first stored clip that has a thumbnail to show (lowest id), again
  /// after every change, or null: a MediaStore clip that is not missing and
  /// holds a number above 0 ([hasPicture]). A detached clip is `missing`, and
  /// a picked clip has no picture to ask for (D-74), so neither is offered.
  /// It is where the Shooting mode card finds its backdrop when no clip waits
  /// in To tag (D-76). A reel card's cover uses the same rule.
  Stream<Clip?> watchFirstShowableClip() {
    final query = _db.select(_db.clips)
      ..where(hasPicture)
      ..orderBy([(c) => OrderingTerm.asc(c.id)])
      ..limit(1);
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toClip(row),
    );
  }

  /// The clips of reel [reelId], by shooting time, oldest first (ties: lowest
  /// id first; spec §8.4), again after every change. Each comes with how many
  /// reels it is in and when it joined this one.
  Stream<List<ReelClip>> watchReelClips(int reelId) {
    final others = _db.alias(_db.clipReels, 'others');
    final reelCount = subqueryExpression<int>(
      _db.selectOnly(others)
        ..addColumns([countAll()])
        ..where(others.clipId.equalsExp(_db.clips.id)),
    );
    final query =
        _db.select(_db.clipReels).join([
            innerJoin(_db.clips, _db.clips.id.equalsExp(_db.clipReels.clipId)),
          ])
          ..addColumns([reelCount])
          ..where(_db.clipReels.reelId.equals(reelId))
          ..orderBy([
            OrderingTerm.asc(_db.clips.dateTakenUtc),
            OrderingTerm.asc(_db.clips.id),
          ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          ReelClip(
            clip: clipFromRow(row.readTable(_db.clips)),
            reelCount: row.read(reelCount)!,
            addedAt: row.readTable(_db.clipReels).addedAt,
          ),
      ],
    );
  }

  /// The ids of the reels clip [clipId] is in, again after every change.
  Stream<Set<int>> watchReelIdsOf(int clipId) =>
      (_db.select(_db.clipReels)..where((l) => l.clipId.equals(clipId)))
          .watch()
          .map((rows) => {for (final row in rows) row.reelId});

  /// The id of the stored clip with the same identity as [clip], or null.
  Future<int?> _findId(NewClip clip) {
    final query = _db.selectOnly(_db.clips)..addColumns([_db.clips.id]);
    switch (clip.source) {
      case ClipSource.mediaStore:
        // Only a MediaStore clip is "this video" (Ruling X).
        query.where(
          _db.clips.source.equalsValue(ClipSource.mediaStore) &
              _db.clips.volumeName.equals(clip.volumeName!) &
              _db.clips.mediaStoreId.equals(clip.mediaStoreId!),
        );
      case ClipSource.picker:
        query.where(_db.clips.pickerUri.equals(clip.pickerUri!));
    }
    return query.map((row) => row.read(_db.clips.id)).getSingleOrNull();
  }

  Future<int> _insertClip(NewClip clip, DateTime now) => _db
      .into(_db.clips)
      .insert(
        ClipsCompanion.insert(
          source: clip.source,
          mediaStoreId: Value(clip.mediaStoreId),
          volumeName: Value(clip.volumeName),
          pickerUri: Value(clip.pickerUri),
          sizeBytes: clip.fingerprint.sizeBytes,
          durationMs: clip.fingerprint.durationMs,
          dateTakenUtc: clip.fingerprint.dateTakenUtc,
          displayName: clip.fingerprint.displayName,
          width: clip.width,
          height: clip.height,
          mimeType: clip.mimeType,
          timeZoneId: Value(clip.timeZoneId),
          generationAdded: Value(clip.generationAdded),
          firstSeenAt: now,
        ),
      );

  /// Links [clipIds] to [reelId], skipping links that exist, deletes their
  /// `inbox` rows, and sets the reel's `updatedAt` when at least one link was
  /// added. Returns the ids it linked. Run inside a transaction.
  Future<Set<int>> _link(int reelId, Set<int> clipIds, DateTime now) async {
    if (clipIds.isEmpty) return const {};
    final existing = await (_db.select(
      _db.clipReels,
    )..where((l) => l.reelId.equals(reelId) & l.clipId.isIn(clipIds))).get();
    final missing = clipIds.difference({for (final l in existing) l.clipId});
    for (final clipId in missing) {
      await _insertLink(clipId, reelId, now);
    }
    await (_db.delete(_db.inbox)..where((i) => i.clipId.isIn(clipIds))).go();
    if (missing.isNotEmpty) await _touchReels({reelId}, now);
    return missing;
  }

  /// Deletes the links of [clipIds] to [reelId], sets the reel's `updatedAt`
  /// when one went, then runs the orphan sweep (D-56). Returns the deleted
  /// links and every field of the clips the sweep deleted. Run inside a
  /// transaction.
  Future<(List<ClipLink>, List<Clip>)> _unlinkAndSweep(
    int reelId,
    Set<int> clipIds,
    DateTime now,
  ) async {
    final links = clipIds.isEmpty
        ? const <ClipReelRow>[]
        : await (_db.select(
                _db.clipReels,
              )..where((l) => l.reelId.equals(reelId) & l.clipId.isIn(clipIds)))
              .get();
    if (links.isNotEmpty) {
      await (_db.delete(
        _db.clipReels,
      )..where((l) => l.reelId.equals(reelId) & l.clipId.isIn(clipIds))).go();
      await _touchReels({reelId}, now);
    }
    return (
      [for (final link in links) linkFromRow(link)],
      await _undo.sweepOrphans(),
    );
  }

  Future<void> _insertLink(int clipId, int reelId, DateTime now) => _db
      .into(_db.clipReels)
      .insert(
        ClipReelsCompanion.insert(clipId: clipId, reelId: reelId, addedAt: now),
      );

  Future<void> _setInboxState(Iterable<int> clipIds, InboxState state) async {
    final ids = clipIds.toSet();
    final changed =
        await (_db.update(_db.inbox)..where((i) => i.clipId.isIn(ids))).write(
          InboxCompanion(state: Value(state)),
        );
    _log.info('Set $changed of ${ids.length} clips to ${state.name}');
  }

  /// Sets `mediaStoreId` (and [verification], when given) of clip [clipId] if
  /// it is a MediaStore clip of [volumeName].
  Future<void> _setMediaStoreId(
    String volumeName,
    int clipId,
    int mediaStoreId, {
    ClipsCompanion verification = const ClipsCompanion(),
  }) =>
      (_db.update(_db.clips)..where(
            (c) => c.id.equals(clipId) & c.volumeName.equals(volumeName),
          ))
          .write(verification.copyWith(mediaStoreId: Value(mediaStoreId)));

  /// Detaches [clipIds] (`mediaStoreId = -id`, missing, verified at [now]).
  /// With [volumeName], only clips of that volume; always only MediaStore
  /// clips (source `mediaStore`).
  Future<void> _markDetached(
    Set<int> clipIds,
    DateTime now, {
    String? volumeName,
  }) async {
    for (final clipId in clipIds) {
      await (_db.update(_db.clips)..where((c) {
            final holds =
                c.id.equals(clipId) &
                c.source.equalsValue(ClipSource.mediaStore) &
                c.mediaStoreId.isNotNull();
            return volumeName == null
                ? holds
                : holds & c.volumeName.equals(volumeName);
          }))
          .write(
            ClipsCompanion(
              mediaStoreId: Value(-clipId),
              missing: const Value(true),
              lastVerifiedAt: Value(now),
            ),
          );
    }
  }

  Future<void> _markVerified(
    Set<int> ids, {
    required bool isMissing,
    required DateTime at,
  }) => (_db.update(_db.clips)..where((c) => c.id.isIn(ids))).write(
    ClipsCompanion(missing: Value(isMissing), lastVerifiedAt: Value(at)),
  );

  Future<Set<int>> _reelIdsOf(int clipId) async => {
    for (final l in await (_db.select(
      _db.clipReels,
    )..where((l) => l.clipId.equals(clipId))).get())
      l.reelId,
  };

  Future<void> _touchReels(Set<int> reelIds, DateTime now) async {
    if (reelIds.isEmpty) return;
    await (_db.update(_db.reels)..where((r) => r.id.isIn(reelIds))).write(
      ReelsCompanion(updatedAt: Value(now)),
    );
  }

  Future<void> _requireReel(int reelId) => _requireReels({reelId});

  Future<void> _requireReels(Set<int> reelIds) async {
    final count = _db.reels.id.count();
    final query = _db.selectOnly(_db.reels)
      ..addColumns([count])
      ..where(_db.reels.id.isIn(reelIds));
    final found = await query.map((row) => row.read(count)).getSingle();
    if (found != reelIds.length) {
      throw StateError('Not every reel in $reelIds exists');
    }
  }

  Future<void> _requireClip(int clipId) async {
    final row = await (_db.select(
      _db.clips,
    )..where((c) => c.id.equals(clipId))).getSingleOrNull();
    if (row == null) throw StateError('No clip with id $clipId');
  }

  Clip _toClip(ClipRow row) => clipFromRow(row);
}

/// What [ClipsRepository.addCheckedClips] did: [ids] has one clip id per
/// clip passed in, in order (found or inserted); [inserted] the new ones, in
/// order; [detached] the stored clips that turned out to be other videos.
class DetectedClips {
  const DetectedClips({
    required this.ids,
    required this.inserted,
    required this.detached,
  });

  final List<int> ids;
  final List<int> inserted;
  final Set<int> detached;
}

@Riverpod(keepAlive: true)
ClipsRepository clipsRepository(Ref ref) =>
    ClipsRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider));
