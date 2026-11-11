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

/// The hand adds undone so far, by identity (as `UndoWriter` marks its
/// records).
final Expando<bool> _handUndone = Expando<bool>('handUndone');

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
      final now = _clock.storedNow();
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
      final now = _clock.storedNow();
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

  /// Adds clips the user chose by hand (Add videos, D-113) to To tag
  /// ([reelId] null) or to reel [reelId], in **one** transaction, and returns
  /// the counts and what [undoHandAdd] needs.
  ///
  /// Clips are found by identity as in [addCheckedClips] (D-57; the same clip
  /// twice in [clips] counts once). For each:
  ///
  /// - **Not known:** inserted with its place in the same transaction: a
  ///   `pending` row in To tag, or a link to the reel (no `inbox` row).
  /// - **Known, but another video:** a stored MediaStore clip at its number
  ///   that is not [sameVideo] is detached (`-clipId`, `missing`) and the clip
  ///   inserted as new, exactly as [addCheckedClips] does (Ruling U, Y). A
  ///   picked clip's URI is its identity: it is never asked.
  /// - **Known, already where the add would put it** (`alreadyThere`): to To
  ///   tag, one in To tag or in a reel; to a reel, one in that reel or in To
  ///   tag. Nothing changes. These are the videos `placesOf` marks.
  /// - **Known, in Skipped:** to To tag, back to `pending` (its `addedAt`
  ///   kept); to a reel, linked and out of Skipped.
  /// - **Known, only in other reels:** to a reel, linked to it too.
  ///
  /// The reel's `updatedAt` moves when a link was added. Throws
  /// [StateError], writing nothing, when there is no reel [reelId]. Known
  /// clips, their rows and links are read in batches of [idBatch].
  Future<HandAdd> addByHand(
    List<NewClip> clips, {
    required bool Function(Clip stored, NewClip incoming) sameVideo,
    int? reelId,
  }) async {
    final result = await _db.transaction(() async {
      final before = reelId == null ? null : await _undo.updatedAtOf(reelId);
      if (reelId != null && before == null) {
        throw StateError('No reel with id $reelId');
      }
      final now = _clock.storedNow();
      final unique = {for (final c in clips) _identityKey(c): c};
      final known = await _knownByIdentity(unique.values);
      final knownIds = {for (final row in known.values) row.id};
      final inboxOf = {
        for (final row in await _inboxRowsOf(knownIds)) row.clipId: row,
      };
      final reelsOf = await _reelIdsOfAll(knownIds);

      var alreadyThere = 0;
      final inserted = <int>[];
      final detached = <int>{};
      final restored = <InboxEntry>[];
      final linked = <int>{};
      final unlisted = <InboxEntry>[];
      for (final MapEntry(:key, value: clip) in unique.entries) {
        var row = known[key];
        if (row != null &&
            clip.source == ClipSource.mediaStore &&
            !sameVideo(_toClip(row), clip)) {
          await _markDetached({row.id}, now);
          detached.add(row.id);
          row = null;
        }
        final inbox = row == null ? null : inboxOf[row.id];
        final reels = row == null ? const <int>{} : reelsOf[row.id] ?? const {};
        if (row == null || (inbox == null && reels.isEmpty)) {
          // New, or (only a backup can leave one) known with no place: it
          // gets its place now, and Undo takes it away again.
          final id = row?.id ?? await _insertClip(clip, now);
          if (reelId == null) {
            await _insertInbox(id, InboxState.pending, now);
          } else {
            await _insertLink(id, reelId, now);
          }
          inserted.add(id);
        } else if (reelId == null) {
          if (inbox?.state == InboxState.skipped) {
            restored.add(_entryOf(inbox!));
          } else {
            alreadyThere++;
          }
        } else if (reels.contains(reelId) ||
            inbox?.state == InboxState.pending) {
          alreadyThere++;
        } else {
          linked.add(row.id);
          if (inbox != null) unlisted.add(_entryOf(inbox));
        }
      }

      for (final batch in _batches({for (final e in restored) e.clipId})) {
        await (_db.update(_db.inbox)..where(
              (i) =>
                  i.clipId.isIn(batch) &
                  i.state.equalsValue(InboxState.skipped),
            ))
            .write(const InboxCompanion(state: Value(InboxState.pending)));
      }
      for (final clipId in linked) {
        await _insertLink(clipId, reelId!, now);
      }
      for (final batch in _batches({for (final e in unlisted) e.clipId})) {
        await (_db.delete(_db.inbox)..where((i) => i.clipId.isIn(batch))).go();
      }
      final touched =
          reelId != null && (linked.isNotEmpty || inserted.isNotEmpty);
      if (touched) await _touchReels({reelId}, now);
      // A detached clip only in To tag or Skipped leaves it (Ruling Y); every
      // inserted clip has its place by now.
      if (detached.isNotEmpty) await _removeMissing(detached);

      final record = reelId == null
          ? InboxUndo(before: restored, after: InboxState.pending)
          : AddUndo(
              reelId: reelId,
              createdLinks: [
                for (final clipId in linked)
                  ClipLink(clipId: clipId, reelId: reelId, addedAt: now),
              ],
              removedInbox: unlisted,
              // The reel's time is put back by `undoHandAdd`, which also
              // knows the links of the inserted clips.
              touch: null,
            );
      return HandAdd(
        inserted.length + restored.length + linked.length,
        alreadyThere,
        HandAddUndo._(
          reelId: reelId,
          at: now,
          inserted: inserted,
          record: record,
          touch: touched
              ? ReelTouch(reelId: reelId, before: before!, after: now)
              : null,
        ),
        detached.length,
      );
    });
    _log.info(
      'Added ${clips.length} clips by hand to '
      '${reelId == null ? 'To tag' : 'reel $reelId'}: ${result.added} added, '
      '${result.alreadyThere} already there, ${result.detached} detached',
    );
    return result;
  }

  /// Undo for [addByHand], in one transaction: takes away only what that add
  /// created (D-113).
  ///
  /// - A clip it inserted loses the place the add gave it, while that place
  ///   is still as the add left it: its `pending` row with the add's
  ///   `addedAt` and no reel (To tag), or its link with the add's `addedAt`
  ///   (a reel). Then the orphan sweep deletes it if it has no other place. A
  ///   clip tagged, skipped or put in another reel since keeps that.
  /// - A clip it brought back from Skipped goes back to Skipped, and one it
  ///   linked loses that link and gets its Skipped row back (the D-84 and
  ///   D-94 undo rules: only while nothing else changed it).
  /// - The reel's `updatedAt` goes back while it still holds the add's.
  /// - A clip the add detached stays detached: it was another video.
  ///
  /// Idempotent: a second call changes nothing (the record is marked once
  /// its transaction commits; a failed undo can run again). The sweep is
  /// global, as in every use of it (D-56).
  Future<void> undoHandAdd(HandAddUndo record) async {
    if (_handUndone[record] ?? false) {
      _log.info('Undo of a hand add that was undone already');
      return;
    }
    final swept = await _db.transaction(() async {
      final inner = record._record;
      if (inner != null && !inner.isEmpty) await _undo.applyUndo(inner);
      final reelId = record.reelId;
      final at = record.at;
      final inAReel = _db.selectOnly(_db.clipReels)
        ..addColumns([_db.clipReels.clipId]);
      for (final batch in _batches(record._inserted.toSet())) {
        if (reelId == null) {
          await (_db.delete(_db.inbox)..where(
                (i) =>
                    i.clipId.isIn(batch) &
                    i.state.equalsValue(InboxState.pending) &
                    i.addedAt.equalsValue(at) &
                    i.clipId.isNotInQuery(inAReel),
              ))
              .go();
        } else {
          await (_db.delete(_db.clipReels)..where(
                (l) =>
                    l.clipId.isIn(batch) &
                    l.reelId.equals(reelId) &
                    l.addedAt.equalsValue(at),
              ))
              .go();
        }
      }
      final touch = record._touch;
      if (touch != null) {
        await (_db.update(_db.reels)..where(
              (r) =>
                  r.id.equals(touch.reelId) &
                  r.updatedAt.equalsValue(touch.after),
            ))
            .write(ReelsCompanion(updatedAt: Value(touch.before)));
      }
      return await _db.deleteOrphanClips();
    });
    _handUndone[record] = true;
    _log.info('Undid a hand add: removed $swept clips');
  }

  /// Where the attached, not-missing MediaStore clips of volume [volumeName]
  /// that hold one of [mediaStoreIds] are, by number: the Add videos marks
  /// (D-113). A missing or detached clip, a picked clip and a clip of
  /// another volume are left out. Asked in batches of [idBatch].
  Future<Map<int, ClipPlace>> placesOf(
    String volumeName,
    Iterable<int> mediaStoreIds,
  ) async {
    final numberOf = <int, int>{};
    for (final batch in _batches(mediaStoreIds.toSet())) {
      final rows =
          await (_db.select(_db.clips)..where(
                (c) =>
                    c.source.equalsValue(ClipSource.mediaStore) &
                    c.volumeName.equals(volumeName) &
                    c.mediaStoreId.isBiggerThanValue(0) &
                    c.mediaStoreId.isIn(batch) &
                    c.missing.equals(false),
              ))
              .get();
      for (final row in rows) {
        numberOf[row.id] = row.mediaStoreId!;
      }
    }
    final ids = numberOf.keys.toSet();
    final inbox = {
      for (final row in await _inboxRowsOf(ids)) row.clipId: row.state,
    };
    final reels = await _reelIdsOfAll(ids);
    return {
      for (final MapEntry(key: clipId, value: number) in numberOf.entries)
        number: ClipPlace(inbox[clipId], reels[clipId] ?? const {}),
    };
  }

  /// A clip's identity (D-57), as a map key.
  static Object _identityKey(NewClip clip) => switch (clip.source) {
    ClipSource.mediaStore => (clip.volumeName!, clip.mediaStoreId!),
    ClipSource.picker => clip.pickerUri!,
  };

  /// The stored clips holding the identities of [clips], by [_identityKey],
  /// read in batches of [idBatch] (per volume for MediaStore clips). Only a
  /// MediaStore clip is "this video" for a MediaStore identity (Ruling X).
  Future<Map<Object, ClipRow>> _knownByIdentity(Iterable<NewClip> clips) async {
    final numbers = <String, Set<int>>{};
    final uris = <String>{};
    for (final clip in clips) {
      switch (clip.source) {
        case ClipSource.mediaStore:
          numbers
              .putIfAbsent(clip.volumeName!, () => {})
              .add(clip.mediaStoreId!);
        case ClipSource.picker:
          uris.add(clip.pickerUri!);
      }
    }
    final known = <Object, ClipRow>{};
    for (final MapEntry(key: volume, value: ids) in numbers.entries) {
      for (final batch in _batches(ids)) {
        for (final row
            in await (_db.select(_db.clips)..where(
                  (c) =>
                      c.source.equalsValue(ClipSource.mediaStore) &
                      c.volumeName.equals(volume) &
                      c.mediaStoreId.isIn(batch),
                ))
                .get()) {
          known[(volume, row.mediaStoreId!)] = row;
        }
      }
    }
    final uriList = uris.toList();
    for (var start = 0; start < uriList.length; start += idBatch) {
      final batch = uriList.sublist(
        start,
        min(start + idBatch, uriList.length),
      );
      for (final row in await (_db.select(
        _db.clips,
      )..where((c) => c.pickerUri.isIn(batch))).get()) {
        known[row.pickerUri!] = row;
      }
    }
    return known;
  }

  /// The `inbox` rows of [clipIds], in batches of [idBatch].
  Future<List<InboxRow>> _inboxRowsOf(Set<int> clipIds) async => [
    for (final batch in _batches(clipIds))
      ...await (_db.select(
        _db.inbox,
      )..where((i) => i.clipId.isIn(batch))).get(),
  ];

  /// The reels of each of [clipIds] that is in one, in batches of [idBatch].
  Future<Map<int, Set<int>>> _reelIdsOfAll(Set<int> clipIds) async {
    final reels = <int, Set<int>>{};
    for (final batch in _batches(clipIds)) {
      for (final link in await (_db.select(
        _db.clipReels,
      )..where((l) => l.clipId.isIn(batch))).get()) {
        reels.putIfAbsent(link.clipId, () => {}).add(link.reelId);
      }
    }
    return reels;
  }

  Future<void> _insertInbox(int clipId, InboxState state, DateTime addedAt) =>
      _db
          .into(_db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(clipId),
              state: state,
              addedAt: addedAt,
            ),
          );

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
      final now = _clock.storedNow();
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
      final now = _clock.storedNow();
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

  /// Skip (D-94): moves the clips in [clipIds] that are in To tag
  /// ([InboxState.pending]) to Skipped, in one transaction. A clip that is
  /// skipped already, in a reel (no `inbox` row) or unknown is left alone.
  /// Only the state moves: `addedAt` keeps when the clip arrived.
  ///
  /// Returns what [undo] needs: the rows it moved, as they were, read in the
  /// same transaction. Empty when it moved nothing (it then writes nothing).
  Future<InboxUndo> skipClips(Iterable<int> clipIds) async {
    final ids = clipIds.toSet();
    final record = await _moveInbox(
      ids,
      from: InboxState.pending,
      to: InboxState.skipped,
    );
    _log.info('Skipped ${record.before.length} of ${ids.length} clips');
    return record;
  }

  /// Skip all (D-94): moves every clip in To tag to Skipped, in one
  /// transaction that reads the rows and writes them, so a clip a scan saves
  /// meanwhile is either in the record (it was saved first) or still in To
  /// tag (it waited for this transaction); it is never skipped without being
  /// in the record. Only the state moves: `addedAt` is kept.
  ///
  /// Returns what [undo] needs: the rows it moved, as they were. Empty when
  /// To tag was empty (it then writes nothing).
  Future<InboxUndo> skipAllPending() async {
    final record = await _db.transaction(() async {
      final rows =
          await (_db.select(_db.inbox)
                ..where((i) => i.state.equalsValue(InboxState.pending))
                ..orderBy([(i) => OrderingTerm.asc(i.clipId)]))
              .get();
      if (rows.isNotEmpty) {
        final moved =
            await (_db.update(_db.inbox)
                  ..where((i) => i.state.equalsValue(InboxState.pending)))
                .write(const InboxCompanion(state: Value(InboxState.skipped)));
        if (moved != rows.length) {
          // Cannot happen inside a transaction: both statements see one
          // state. A row skipped but not in the record could not be undone.
          throw StateError('Skipped $moved clips but read ${rows.length}');
        }
      }
      return InboxUndo(
        before: [for (final row in rows) _entryOf(row)],
        after: InboxState.skipped,
      );
    });
    _log.info('Skipped all ${record.before.length} clips in To tag');
    return record;
  }

  /// Restore (D-94): moves the clips in [clipIds] that are in Skipped back to
  /// To tag ([InboxState.pending]), in one transaction. A clip that is
  /// pending already, in a reel or unknown is left alone. Only the state
  /// moves: `addedAt` is kept.
  ///
  /// Returns what [undo] needs: the rows it moved, as they were. Empty when
  /// it moved nothing (it then writes nothing).
  Future<InboxUndo> restoreClips(Iterable<int> clipIds) async {
    final ids = clipIds.toSet();
    final record = await _moveInbox(
      ids,
      from: InboxState.skipped,
      to: InboxState.pending,
    );
    _log.info('Restored ${record.before.length} of ${ids.length} clips');
    return record;
  }

  /// Moves the `inbox` rows of [ids] that are in state [from] to [to], in one
  /// transaction (batches of [idBatch]), and returns them as they were, by
  /// clip id. Writes nothing when no row is in [from].
  Future<InboxUndo> _moveInbox(
    Set<int> ids, {
    required InboxState from,
    required InboxState to,
  }) async {
    if (ids.isEmpty) return InboxUndo(before: const [], after: to);
    final rows = await _db.transaction(() async {
      final rows = <InboxRow>[];
      for (final batch in _batches(ids)) {
        final found =
            await (_db.select(_db.inbox)..where(
                  (i) => i.clipId.isIn(batch) & i.state.equalsValue(from),
                ))
                .get();
        if (found.isEmpty) continue;
        final moved =
            await (_db.update(_db.inbox)..where(
                  (i) => i.clipId.isIn(batch) & i.state.equalsValue(from),
                ))
                .write(InboxCompanion(state: Value(to)));
        if (moved != found.length) {
          // Cannot happen inside a transaction (see skipAllPending).
          throw StateError('Moved $moved clips but read ${found.length}');
        }
        rows.addAll(found);
      }
      return rows..sort((a, b) => a.clipId.compareTo(b.clipId));
    });
    return InboxUndo(
      before: [for (final row in rows) _entryOf(row)],
      after: to,
    );
  }

  InboxEntry _entryOf(InboxRow row) =>
      InboxEntry(clipId: row.clipId, state: row.state, addedAt: row.addedAt);

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
    final now = _clock.storedNow();
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
      final now = _clock.storedNow();
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
      final now = _clock.storedNow();
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

  /// Puts back what a remove, move, add, reel delete, skip or restore
  /// changed, with the same ids, in one transaction (D-84, D-94). Idempotent;
  /// a reel that is gone gets nothing back. See `UndoWriter.undo`.
  Future<void> undo(UndoRecord record) => _undo.undo(record);

  /// Puts back what every one of [records] changed, last to first, in one
  /// transaction: all of them or, on a failure, none (then the list can be
  /// undone again). See `UndoWriter.undoAll`.
  Future<void> undoAll(List<UndoRecord> records) => _undo.undoAll(records);

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
      final now = _clock.storedNow();
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

  /// Runs [body] in one database transaction, so writes of this repository
  /// and of `PhoneStateRepository` (one database) stand or fall together. The
  /// transactions inside [body] join it. Used by `LibraryResync.resync`,
  /// which must not detach clips without the window that finds them again
  /// (D-108).
  Future<T> inTransaction<T>(Future<T> Function() body) =>
      _db.transaction(body);

  /// The detached MediaStore clips of volume [volumeName]: the ones
  /// [applyRebuildMatch] or a verify left with `mediaStoreId = -clipId` (and
  /// `missing`), which [mediaStoreClipsOn] leaves out. [reattachDetached]
  /// finds them again. Picked clips, attached clips and clips of other
  /// volumes are not in it. By id.
  Future<List<Clip>> detachedClipsOn(String volumeName) async {
    final rows =
        await (_db.select(_db.clips)
              ..where(
                (c) =>
                    c.source.equalsValue(ClipSource.mediaStore) &
                    c.volumeName.equals(volumeName) &
                    c.mediaStoreId.isSmallerThanValue(0),
              )
              ..orderBy([(c) => OrderingTerm.asc(c.id)]))
            .get();
    return [for (final row in rows) _toClip(row)];
  }

  /// Gives detached clips the numbers of their videos again, in one
  /// transaction per volume (D-108, I-3). [matches] maps a detached clip's id
  /// to the MediaStore id of the video `matchAfterRebuild` found for it on
  /// [volumeName].
  ///
  /// For each pair, in the order of the clip ids, with D the detached clip
  /// and V the video:
  ///
  /// - no clip holds V: D takes V's number, `missing = false`,
  ///   `lastVerifiedAt` = now;
  /// - a clip N holds V and is the same video as D (`sameFingerprint`: it is
  ///   a duplicate that came in as a new clip while D was detached): N is
  ///   deleted, with its `inbox` row and its reel links, and D takes V's
  ///   number. D keeps what the user did with it. D also gets N's reel links:
  ///   a reel that has both keeps one link with the earlier `addedAt`, a reel
  ///   that had only N gets a link for D with N's `addedAt`. A D that is in no
  ///   reel and no list takes N's `inbox` row, so it is not left an orphan;
  /// - V is held by a clip that is not the same video as D (its number is
  ///   stale), or by a picked clip: nothing is changed, so a clip in a reel
  ///   never ends up on the wrong video. A later verify detaches the stale
  ///   holder and the next scan matches D again.
  ///
  /// A pair whose clip is not a detached MediaStore clip of [volumeName]
  /// (attached, picked, of another volume, unknown) is ignored, so a stale
  /// match changes nothing. A reel's `updatedAt` is not touched: this is a
  /// repair, not an edit. `vn_copies` rows are left as they are (D-54).
  ///
  /// Throws [ArgumentError], changing nothing, when two clips are matched to
  /// one video or a video id is below 1. A database failure rolls the whole
  /// volume back.
  Future<ReattachResult> reattachDetached(
    String volumeName,
    Map<int, int> matches,
  ) async {
    final targets = matches.values.toList();
    if (targets.any((id) => id < 1)) {
      throw ArgumentError.value(
        matches,
        'matches',
        'a MediaStore id must be above 0',
      );
    }
    if (targets.toSet().length != targets.length) {
      throw ArgumentError.value(
        matches,
        'matches',
        'two clips cannot get the same MediaStore id',
      );
    }
    if (matches.isEmpty) return const ReattachResult(0, 0, 0);

    final result = await _db.transaction(() async {
      final now = _clock.storedNow();
      var reattached = 0;
      var merged = 0;
      for (final clipId in matches.keys.toList()..sort()) {
        final videoId = matches[clipId]!;
        final detached =
            await (_db.select(_db.clips)..where(
                  (c) =>
                      c.id.equals(clipId) &
                      c.source.equalsValue(ClipSource.mediaStore) &
                      c.volumeName.equals(volumeName) &
                      c.mediaStoreId.isSmallerThanValue(0),
                ))
                .getSingleOrNull();
        if (detached == null) continue;
        final holder =
            await (_db.select(_db.clips)..where(
                  (c) =>
                      c.volumeName.equals(volumeName) &
                      c.mediaStoreId.equals(videoId),
                ))
                .getSingleOrNull();
        if (holder != null) {
          final same =
              holder.source == ClipSource.mediaStore &&
              sameFingerprint(
                _toClip(detached).fingerprint,
                _toClip(holder).fingerprint,
              );
          if (!same) continue;
          await _mergeDuplicate(detached.id, holder.id);
          merged++;
        } else {
          reattached++;
        }
        await _setMediaStoreId(
          volumeName,
          clipId,
          videoId,
          verification: ClipsCompanion(
            missing: const Value(false),
            lastVerifiedAt: Value(now),
          ),
        );
      }
      return ReattachResult(
        reattached,
        merged,
        matches.length - reattached - merged,
      );
    });
    _log.info(
      'Re-attached ${result.reattached} detached clips, '
      '${result.merged} merged with a duplicate, ${result.left} left',
    );
    return result;
  }

  /// Moves what the duplicate [duplicateId] has onto [keptId] and deletes
  /// the duplicate (its `inbox` row and links with it): the union of the
  /// reel links, keeping the earlier `addedAt` of a reel both are in, and the
  /// duplicate's `inbox` row when the kept clip has no place at all. Run
  /// inside a transaction, before the kept clip takes the duplicate's number.
  Future<void> _mergeDuplicate(int keptId, int duplicateId) async {
    final kept = {
      for (final l in await (_db.select(
        _db.clipReels,
      )..where((l) => l.clipId.equals(keptId))).get())
        l.reelId: l.addedAt,
    };
    final duplicateLinks = await (_db.select(
      _db.clipReels,
    )..where((l) => l.clipId.equals(duplicateId))).get();
    for (final link in duplicateLinks) {
      final own = kept[link.reelId];
      if (own == null) {
        await _insertLink(keptId, link.reelId, link.addedAt);
      } else if (link.addedAt.isBefore(own)) {
        await (_db.update(_db.clipReels)..where(
              (l) => l.clipId.equals(keptId) & l.reelId.equals(link.reelId),
            ))
            .write(ClipReelsCompanion(addedAt: Value(link.addedAt)));
      }
    }
    final keptInbox = await (_db.select(
      _db.inbox,
    )..where((i) => i.clipId.equals(keptId))).getSingleOrNull();
    final duplicateInbox = await (_db.select(
      _db.inbox,
    )..where((i) => i.clipId.equals(duplicateId))).getSingleOrNull();
    if (kept.isEmpty &&
        duplicateLinks.isEmpty &&
        keptInbox == null &&
        duplicateInbox != null) {
      await _db
          .into(_db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(keptId),
              state: duplicateInbox.state,
              addedAt: duplicateInbox.addedAt,
            ),
          );
    }
    await (_db.delete(
      _db.inbox,
    )..where((i) => i.clipId.equals(duplicateId))).go();
    await (_db.delete(
      _db.clipReels,
    )..where((l) => l.clipId.equals(duplicateId))).go();
    await (_db.delete(_db.clips)..where((c) => c.id.equals(duplicateId))).go();
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
  ///    that was not flagged keeps its row; a picked clip flagged missing by
  ///    its own check leaves To tag like any other) go, then the clips
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
      final now = _clock.storedNow();
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

  /// When the clips waiting in To tag were shot (their `dateTakenUtc`),
  /// oldest first, again each time that list changes (D-106: the phone's
  /// copy holds them for the evening reminder). A change that leaves the
  /// list as it was (a reel created, a clip flagged missing) does not emit.
  Stream<List<DateTime>> watchPendingShotTimes() =>
      _pendingShotTimesQuery().watch().map(_shotTimes).distinct(_sameTimes);

  /// [watchPendingShotTimes] now, once.
  Future<List<DateTime>> pendingShotTimes() async =>
      _shotTimes(await _pendingShotTimesQuery().get());

  JoinedSelectStatement<HasResultSet, dynamic> _pendingShotTimesQuery() =>
      _db.selectOnly(_db.inbox).join([
          innerJoin(_db.clips, _db.clips.id.equalsExp(_db.inbox.clipId)),
        ])
        ..addColumns([_db.clips.dateTakenUtc])
        ..where(_db.inbox.state.equalsValue(InboxState.pending))
        ..orderBy([OrderingTerm.asc(_db.clips.dateTakenUtc)]);

  List<DateTime> _shotTimes(List<TypedResult> rows) => [
    for (final row in rows) row.readWithConverter(_db.clips.dateTakenUtc)!,
  ];

  static bool _sameTimes(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!a[i].isAtSameMomentAs(b[i])) return false;
    }
    return true;
  }

  /// How many clips are waiting in To tag, again after every change.
  Stream<int> watchPendingCount() => _watchInboxCount(InboxState.pending);

  /// How many clips are in Skipped, again after every change (D-98: the
  /// **Skipped ({n})** button on To tag).
  Stream<int> watchSkippedCount() => _watchInboxCount(InboxState.skipped);

  Stream<int> _watchInboxCount(InboxState state) {
    final count = _db.inbox.clipId.count();
    final query = _db.selectOnly(_db.inbox)
      ..addColumns([count])
      ..where(_db.inbox.state.equalsValue(state));
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

  Future<void> _insertLink(int clipId, int reelId, DateTime addedAt) => _db
      .into(_db.clipReels)
      .insert(
        ClipReelsCompanion.insert(
          clipId: clipId,
          reelId: reelId,
          addedAt: addedAt,
        ),
      );

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

/// What [ClipsRepository.addByHand] did: [added] clips are now where the
/// add put them (new, from Skipped, or linked from another reel),
/// [alreadyThere] were there already and did not change, and [detached]
/// stored clips turned out to be other videos. [undo] is what
/// [ClipsRepository.undoHandAdd] needs.
class HandAdd {
  const HandAdd(this.added, this.alreadyThere, this.undo, this.detached);

  final int added;
  final int alreadyThere;
  final HandAddUndo undo;
  final int detached;
}

/// What [ClipsRepository.undoHandAdd] needs to take one hand add back
/// (D-113). Opaque outside the repository.
class HandAddUndo {
  HandAddUndo._({
    required this.reelId,
    required this.at,
    required List<int> inserted,
    required this._record,
    required this._touch,
  }) : _inserted = List.unmodifiable(inserted);

  /// The reel the add was for, or null for To tag.
  final int? reelId;

  /// When the add ran: the `addedAt` of every row and link it created.
  final DateTime at;

  /// The clips that got their place from the add (new ones).
  final List<int> _inserted;

  /// The known clips it moved: an [InboxUndo] (To tag) or an [AddUndo] (a
  /// reel).
  final UndoRecord? _record;

  final ReelTouch? _touch;
}

/// Where one stored clip is: its `inbox` state (null when it has no row) and
/// the reels it is in.
class ClipPlace {
  const ClipPlace(this.inbox, this.reelIds);

  final InboxState? inbox;
  final Set<int> reelIds;
}

/// What [ClipsRepository.reattachDetached] did: [reattached] detached clips
/// took the number of a video nobody held, [merged] took it from a duplicate
/// that was deleted, and [left] were not changed (their video is held by
/// another video's clip, or they were not detached clips of the volume).
class ReattachResult {
  const ReattachResult(this.reattached, this.merged, this.left);

  final int reattached;
  final int merged;
  final int left;
}

@Riverpod(keepAlive: true)
ClipsRepository clipsRepository(Ref ref) =>
    ClipsRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider));
