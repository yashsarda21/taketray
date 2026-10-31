import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/housekeeping.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/models/vn_copy.dart';
import 'package:taketray/domain/models/vn_session.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';

// Ids and counts only (D-10): never a name, a description, a display name or
// a URI.
final Logger _log = Logger('undo');

/// The records undone so far, by identity. A record lives only as long as
/// its snack, and an [Expando] does not keep it alive.
final Expando<bool> _undone = Expando<bool>('undone');

/// Takes the snapshots that become [UndoRecord]s and puts them back (D-84).
///
/// Shared by `ClipsRepository` and `ReelsRepository`; screens call `undo` on
/// either. Every method except [undo] runs inside the caller's transaction.
class UndoWriter {
  new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Runs the orphan sweep (D-56) and returns every field of each clip it
  /// deleted. Run inside a transaction, so the rows read are the rows
  /// deleted.
  Future<List<Clip>> sweepOrphans() async {
    final rows = await _db.selectOrphanClips();
    final deleted = await _db.deleteOrphanClips();
    if (deleted != rows.length) {
      // Cannot happen inside a transaction: both statements see one state.
      throw StateError('Swept $deleted clips but read ${rows.length}');
    }
    return [for (final row in rows) clipFromRow(row)];
  }

  /// The current `updatedAt` of reel [reelId], or null when it is gone.
  Future<DateTime?> updatedAtOf(int reelId) async => (await (_db.select(
    _db.reels,
  )..where((r) => r.id.equals(reelId))).getSingleOrNull())?.updatedAt;

  /// Puts back what [record] changed, in one transaction, with the same ids.
  ///
  /// - A clip the sweep deleted comes back with its old id and every field,
  ///   unless a clip with the same identity (volume and MediaStore number
  ///   above 0, or picker URI) exists now under another id: that clip is
  ///   linked instead and nothing is inserted, so there is never a second row
  ///   for one video.
  /// - Links come back with their old `addedAt`; a link that exists already
  ///   is left alone.
  /// - A reel's `updatedAt` goes back to its value before the action, only
  ///   while it still holds the value the action wrote.
  /// - A reel that is gone (deleted meanwhile) gets nothing back, with a
  ///   warning; nothing throws for it.
  ///
  /// Idempotent: a second undo of the same record changes nothing. A failed
  /// undo changes nothing and can be tried again.
  Future<void> undo(UndoRecord record) => undoAll([record]);

  /// Puts back what every one of [records] changed, **last to first**, in
  /// **one** transaction, as [undo] does for one (an add to three reels is
  /// three records, D-84 point 8). If any step fails, the transaction rolls
  /// back, so nothing of any record stays undone, none is marked, and the
  /// same list can be undone again. A record undone already is skipped.
  Future<void> undoAll(List<UndoRecord> records) async {
    final marked = <UndoRecord>[];
    try {
      await _db.transaction(() async {
        for (final record in records.reversed) {
          // Undo calls run one after another (a transaction each), so a
          // double tap sees the first one's marks.
          if (_undone[record] ?? false) {
            _log.info(
              'Undo of a ${record.runtimeType} that was undone already',
            );
            continue;
          }
          switch (record) {
            case RemoveUndo():
              await _undoRemove(record);
            case MoveUndo():
              await _undoMove(record);
            case AddUndo():
              await _undoAdd(record);
            case DeleteReelUndo():
              await _undoDelete(record);
          }
          _undone[record] = true;
          marked.add(record);
        }
      });
    } on Object {
      // The transaction rolled back (the commit itself can fail after the
      // marks), so every record can be undone again. One found undone
      // already keeps its mark.
      for (final record in marked) {
        _undone[record] = null;
      }
      rethrow;
    }
  }

  Future<void> _undoRemove(RemoveUndo record) async {
    if (record.isEmpty) return;
    if (!await _reelExists(record.reelId)) {
      _log.warning('Undo remove: reel ${record.reelId} is gone');
      return;
    }
    final ids = await _restoreClips(record.sweptClips, record.removedLinks);
    final links = await _restoreLinks(record.removedLinks, ids);
    await _restoreTouch(record.touch);
    _log.info(
      'Undid a remove from reel ${record.reelId}: $links links, '
      '${ids.length} swept clips',
    );
  }

  Future<void> _undoMove(MoveUndo record) async {
    if (record.isEmpty) return;
    for (final reelId in {record.fromReelId, record.toReelId}) {
      if (!await _reelExists(reelId)) {
        _log.warning('Undo move: reel $reelId is gone');
      }
    }
    // The source links first, so a clip always has a place when its target
    // link goes.
    final restored = await _restoreLinks(record.removedLinks, const {});
    final deleted = await _deleteCreatedLinks(record.createdLinks);
    for (final touch in record.touches) {
      await _restoreTouch(touch);
    }
    _log.info(
      'Undid a move from reel ${record.fromReelId} to ${record.toReelId}: '
      '$restored links back, $deleted removed',
    );
  }

  Future<void> _undoAdd(AddUndo record) async {
    if (record.isEmpty) return;
    if (!await _reelExists(record.reelId)) {
      _log.warning('Undo add: reel ${record.reelId} is gone');
      return;
    }
    var back = 0;
    // The lists first: a clip that came from To tag or Skipped and is in no
    // reel now except through this add goes back to its list, so it has a
    // place before its link goes. One the user has put in a reel since stays
    // there (a clip is never in a reel and a list at once, D-57).
    for (final entry in record.removedInbox) {
      if (!await _clipExists(entry.clipId) ||
          await _hasInboxRow(entry.clipId) ||
          await _hasOtherLink(entry.clipId, record)) {
        continue;
      }
      await _db
          .into(_db.inbox)
          .insert(
            InboxCompanion.insert(
              clipId: Value(entry.clipId),
              state: entry.state,
              addedAt: entry.addedAt,
            ),
          );
      back++;
    }
    // Then the links, each only while its clip keeps another place: undoing
    // an add never deletes a clip (one removed from its other reel since
    // stays in this one). No sweep.
    final deleted = await _deleteCreatedLinks(record.createdLinks);
    await _restoreTouch(record.touch);
    _log.info(
      'Undid an add to reel ${record.reelId}: $deleted links removed, '
      '$back back in their list',
    );
  }

  Future<void> _undoDelete(DeleteReelUndo record) async {
    final reel = record.reel;
    if (reel == null) return;
    if (await _reelExists(reel.id)) {
      // Undone already (a second record of one delete), or the id was given
      // to another reel by a backup import: either way, leave it.
      _log.warning('Undo delete: reel ${reel.id} exists, nothing restored');
      return;
    }
    // With its old id, and without the duplicate-name check: restoring the
    // user's reel wins over the rule (D-80).
    await _db
        .into(_db.reels)
        .insert(
          ReelsCompanion.insert(
            id: Value(reel.id),
            name: reel.name,
            description: Value(reel.description),
            status: reel.status,
            createdAt: reel.createdAt,
            updatedAt: reel.updatedAt,
          ),
        );
    final ids = await _restoreClips(record.sweptClips, record.links);
    final links = await _restoreLinks(record.links, ids);
    for (final reference in record.references) {
      await _restoreReference(reference);
    }
    final session = record.vnSession;
    if (session != null) {
      await _db
          .into(_db.vnSessions)
          .insert(
            VnSessionsCompanion.insert(
              reelId: Value(session.reelId),
              folderName: session.folderName,
              createdAt: session.createdAt,
            ),
          );
      var leftOut = 0;
      for (final copy in record.vnCopies) {
        // A swept clip that could not come back (mapped to null) must not
        // get a copy row: its old id has no clip, or holds another one. A
        // clip that was not swept keeps its id.
        if (ids.containsKey(copy.clipId) && ids[copy.clipId] == null) {
          leftOut++;
          continue;
        }
        final clipId = ids[copy.clipId] ?? copy.clipId;
        await _db
            .into(_db.vnCopies)
            .insert(
              VnCopiesCompanion.insert(
                reelId: copy.reelId,
                clipId: clipId,
                copyMediaStoreId: copy.copyMediaStoreId,
                fileName: copy.fileName,
                sizeBytes: copy.sizeBytes,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      if (leftOut > 0) {
        _log.warning(
          'Undo delete of reel ${reel.id}: $leftOut VN copy rows left out, '
          'their clips could not come back',
        );
      }
    }
    _log.info(
      'Undid the delete of reel ${reel.id}: $links links, '
      '${ids.length} swept clips, ${record.references.length} references',
    );
  }

  /// Puts back the swept clips that [links] need, and returns, for each, the
  /// id it has now: its old id (inserted again, or already back), the id of
  /// the clip that holds its identity now, or null when it cannot come back.
  /// A swept clip no link needs stays gone: alone it would be an orphan.
  Future<Map<int, int?>> _restoreClips(
    List<Clip> swept,
    List<ClipLink> links,
  ) async {
    final needed = {for (final link in links) link.clipId};
    final ids = <int, int?>{};
    for (final clip in swept) {
      if (needed.contains(clip.id)) ids[clip.id] = await _restoreClip(clip);
    }
    return ids;
  }

  Future<int?> _restoreClip(Clip clip) async {
    final atId = await (_db.select(
      _db.clips,
    )..where((c) => c.id.equals(clip.id))).getSingleOrNull();
    if (atId != null && _sameClip(atId, clip)) return clip.id;
    // The same video, saved again under another id meanwhile (Add earlier
    // videos found it again): link that one, insert nothing. Only when its
    // fingerprint is this clip's (D-69): after a rebuild the number, or a
    // URI, can belong to another video, which must never join the reel.
    final holder = await _identityHolder(clip);
    if (holder != null &&
        sameFingerprint(_fingerprintOf(holder), clip.fingerprint)) {
      return holder.id;
    }
    if (atId != null) {
      // Ids are AUTOINCREMENT and never reused, so only a backup import can
      // put another clip here. Skip it rather than link the wrong video.
      _log.warning('Undo: clip id ${clip.id} holds another clip, not restored');
      return null;
    }
    if (holder == null) {
      await _db
          .into(_db.clips)
          .insert(_clipCompanion(clip), mode: InsertMode.insertOrAbort);
      return clip.id;
    }
    // Another video holds its identity now.
    if (clip.source != ClipSource.mediaStore || clip.pickerUri != null) {
      // A picked clip has nothing else to be found by: leave it out.
      _log.warning(
        'Undo: clip ${clip.id}: clip ${holder.id} is another video with its '
        'identity, not restored',
      );
      return null;
    }
    // Back with its old id but detached and missing (the D-71 shape): it
    // shows the missing tile and can never play the other video.
    await _db
        .into(_db.clips)
        .insert(
          _clipCompanion(clip).copyWith(
            mediaStoreId: Value(-clip.id),
            missing: const Value(true),
            lastVerifiedAt: Value(_clock.storedNow()),
          ),
          mode: InsertMode.insertOrAbort,
        );
    _log.info(
      'Undo: clip ${clip.id} restored detached; clip ${holder.id} is '
      'another video with its number',
    );
    return clip.id;
  }

  ClipFingerprint _fingerprintOf(ClipRow row) => ClipFingerprint(
    sizeBytes: row.sizeBytes,
    durationMs: row.durationMs,
    dateTakenUtc: row.dateTakenUtc,
    displayName: row.displayName,
  );

  /// The row with [clip]'s id is [clip] when it was saved at the same moment
  /// from the same video facts. Its MediaStore number may have changed since
  /// (a detach or a remap), so that is not compared.
  bool _sameClip(ClipRow row, Clip clip) =>
      row.source == clip.source &&
      row.sizeBytes == clip.fingerprint.sizeBytes &&
      row.durationMs == clip.fingerprint.durationMs &&
      row.dateTakenUtc == clip.fingerprint.dateTakenUtc &&
      row.firstSeenAt == clip.firstSeenAt;

  /// The stored clip with [clip]'s identity: the same volume and MediaStore
  /// number above 0, or the same picker URI. These are the table's unique
  /// keys, so a clip they find would also block the insert. A detached clip
  /// (number `-id`) has no identity to find.
  Future<ClipRow?> _identityHolder(Clip clip) async {
    final volume = clip.volumeName;
    final number = clip.mediaStoreId;
    final uri = clip.pickerUri;
    final byStore = volume != null && number != null && number > 0;
    if (!byStore && uri == null) return null;
    final query = _db.select(_db.clips)
      ..where(
        (c) => Expression.or([
          if (byStore)
            c.volumeName.equals(volume) & c.mediaStoreId.equals(number),
          if (uri != null) c.pickerUri.equals(uri),
        ]),
      )
      ..orderBy([(c) => OrderingTerm.asc(c.id)])
      ..limit(1);
    return await query.getSingleOrNull();
  }

  /// Inserts each of [links] that is not there, with its `addedAt`, when its
  /// reel and its clip exist, and takes that clip out of To tag and Skipped
  /// (a clip is never in a reel and a list at once, D-57). [ids] maps a swept
  /// clip's old id to its id now (null: it did not come back). Returns how
  /// many links it inserted.
  Future<int> _restoreLinks(List<ClipLink> links, Map<int, int?> ids) async {
    var inserted = 0;
    var skipped = 0;
    final reelThere = <int, bool>{};
    for (final link in links) {
      final clipId = ids.containsKey(link.clipId)
          ? ids[link.clipId]
          : link.clipId;
      if (clipId == null ||
          !(reelThere[link.reelId] ??= await _reelExists(link.reelId)) ||
          !await _clipExists(clipId)) {
        skipped++;
        continue;
      }
      final exists =
          await (_db.select(_db.clipReels)..where(
                (l) => l.clipId.equals(clipId) & l.reelId.equals(link.reelId),
              ))
              .getSingleOrNull();
      if (exists != null) continue;
      await _db
          .into(_db.clipReels)
          .insert(
            ClipReelsCompanion.insert(
              clipId: clipId,
              reelId: link.reelId,
              addedAt: link.addedAt,
            ),
          );
      await (_db.delete(_db.inbox)..where((i) => i.clipId.equals(clipId))).go();
      inserted++;
    }
    if (skipped > 0) _log.warning('Undo: $skipped links could not come back');
    return inserted;
  }

  /// Deletes each of [links] (still there with the same `addedAt`) whose clip
  /// keeps another place: another link or a list. A clip that would be left
  /// with no place keeps the link, so undoing a move never deletes a clip
  /// (its source reel may be gone). Returns how many it deleted.
  Future<int> _deleteCreatedLinks(List<ClipLink> links) async {
    var deleted = 0;
    var kept = 0;
    for (final link in links) {
      final elsewhere =
          await (_db.select(_db.clipReels)
                ..where(
                  (l) =>
                      l.clipId.equals(link.clipId) &
                      l.reelId.equals(link.reelId).not(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (elsewhere == null && !await _hasInboxRow(link.clipId)) {
        kept++;
        continue;
      }
      deleted += await _deleteLink(link);
    }
    if (kept > 0) {
      _log.warning('Undo: kept $kept links of clips with no other place');
    }
    return deleted;
  }

  /// Deletes [link] if it is still the link the action created (same
  /// `addedAt`): one the user removed and added again since is theirs.
  Future<int> _deleteLink(ClipLink link) =>
      (_db.delete(_db.clipReels)..where(
            (l) =>
                l.clipId.equals(link.clipId) &
                l.reelId.equals(link.reelId) &
                l.addedAt.equalsValue(link.addedAt),
          ))
          .go();

  Future<void> _restoreTouch(ReelTouch? touch) async {
    if (touch == null) return;
    await (_db.update(_db.reels)..where(
          (r) =>
              r.id.equals(touch.reelId) & r.updatedAt.equalsValue(touch.after),
        ))
        .write(ReelsCompanion(updatedAt: Value(touch.before)));
  }

  Future<void> _restoreReference(ReelReference reference) async {
    final taken = await (_db.select(
      _db.reelReferences,
    )..where((r) => r.id.equals(reference.id))).getSingleOrNull();
    await _db
        .into(_db.reelReferences)
        .insert(
          ReelReferencesCompanion.insert(
            // Ids are never reused; only a backup import could have given
            // this one away, and then the reference comes back with a new id.
            id: taken == null ? Value(reference.id) : const Value.absent(),
            reelId: reference.reelId,
            url: reference.url,
            source: reference.source,
            label: Value(reference.label),
            createdAt: reference.createdAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<bool> _reelExists(int reelId) async =>
      await updatedAtOf(reelId) != null;

  Future<bool> _clipExists(int clipId) async =>
      await (_db.selectOnly(_db.clips)
            ..addColumns([_db.clips.id])
            ..where(_db.clips.id.equals(clipId)))
          .getSingleOrNull() !=
      null;

  /// Whether [clipId] has a link other than the one [record] created (to
  /// its reel, with the add's `addedAt`).
  Future<bool> _hasOtherLink(int clipId, AddUndo record) async {
    final ours = record.createdLinks.where((l) => l.clipId == clipId).toList();
    final links = await (_db.select(
      _db.clipReels,
    )..where((l) => l.clipId.equals(clipId))).get();
    return links.any(
      (l) => !ours.any((o) => o.reelId == l.reelId && o.addedAt == l.addedAt),
    );
  }

  Future<bool> _hasInboxRow(int clipId) async =>
      await (_db.select(
        _db.inbox,
      )..where((i) => i.clipId.equals(clipId))).getSingleOrNull() !=
      null;

  ClipsCompanion _clipCompanion(Clip clip) => ClipsCompanion.insert(
    id: Value(clip.id),
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
    firstSeenAt: clip.firstSeenAt,
    missing: Value(clip.missing),
    lastVerifiedAt: Value(clip.lastVerifiedAt),
  );
}

/// A clip row as the domain model.
Clip clipFromRow(ClipRow row) => Clip(
  id: row.id,
  source: row.source,
  mediaStoreId: row.mediaStoreId,
  volumeName: row.volumeName,
  pickerUri: row.pickerUri,
  fingerprint: ClipFingerprint(
    sizeBytes: row.sizeBytes,
    durationMs: row.durationMs,
    dateTakenUtc: row.dateTakenUtc,
    displayName: row.displayName,
  ),
  width: row.width,
  height: row.height,
  mimeType: row.mimeType,
  timeZoneId: row.timeZoneId,
  generationAdded: row.generationAdded,
  firstSeenAt: row.firstSeenAt,
  missing: row.missing,
  lastVerifiedAt: row.lastVerifiedAt,
);

/// A reel row as the domain model.
Reel reelFromRow(ReelRow row) => Reel(
  id: row.id,
  name: row.name,
  description: row.description,
  status: row.status,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
);

/// A link row as the undo records hold it.
ClipLink linkFromRow(ClipReelRow row) =>
    ClipLink(clipId: row.clipId, reelId: row.reelId, addedAt: row.addedAt);

/// A reference row as the domain model.
ReelReference referenceFromRow(ReelReferenceRow row) => ReelReference(
  id: row.id,
  reelId: row.reelId,
  url: row.url,
  source: row.source,
  label: row.label,
  createdAt: row.createdAt,
);

/// A VN session row as the domain model.
VnSession vnSessionFromRow(VnSessionRow row) => VnSession(
  reelId: row.reelId,
  folderName: row.folderName,
  createdAt: row.createdAt,
);

/// A VN copy row as the domain model.
VnCopy vnCopyFromRow(VnCopyRow row) => VnCopy(
  reelId: row.reelId,
  clipId: row.clipId,
  copyMediaStoreId: row.copyMediaStoreId,
  fileName: row.fileName,
  sizeBytes: row.sizeBytes,
);
