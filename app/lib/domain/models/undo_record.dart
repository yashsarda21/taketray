import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';

/// What one remove, move, add-to-reel, reel delete, skip or restore changed,
/// so that Undo can put it back (D-84, D-94).
///
/// Each record is a snapshot taken inside the same transaction as the change,
/// and holds only plain values and domain models (never database rows), so
/// it does not depend on the database layer. `ClipsRepository.undo` and
/// `ReelsRepository.undo` restore it, with the same ids. Undo is idempotent:
/// a second undo of the same record changes nothing.
///
/// A record lives as long as its Undo snack; nothing stores it.
@immutable
sealed class UndoRecord {
  const UndoRecord();

  /// True when undoing this record would put nothing back: the action
  /// changed nothing.
  bool get isEmpty;
}

/// A clip's link to a reel, with the time it joined the reel.
@immutable
class ClipLink {
  const ClipLink({
    required this.clipId,
    required this.reelId,
    required this.addedAt,
  });

  final int clipId;
  final int reelId;
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      other is ClipLink &&
      other.clipId == clipId &&
      other.reelId == reelId &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(clipId, reelId, addedAt);

  @override
  String toString() => 'ClipLink($clipId → $reelId, $addedAt)';
}

/// A clip's place in To tag (`pending`) or Skipped (`skipped`).
@immutable
class InboxEntry {
  const InboxEntry({
    required this.clipId,
    required this.state,
    required this.addedAt,
  });

  final int clipId;
  final InboxState state;
  final DateTime addedAt;

  @override
  bool operator ==(Object other) =>
      other is InboxEntry &&
      other.clipId == clipId &&
      other.state == state &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(clipId, state, addedAt);

  @override
  String toString() => 'InboxEntry($clipId, ${state.name}, $addedAt)';
}

/// A reel's `updatedAt` before an action ([before]) and the value the action
/// wrote ([after]). Undo puts [before] back only while the reel still holds
/// [after], so a later edit of the reel is not undone with it.
@immutable
class ReelTouch {
  const ReelTouch({
    required this.reelId,
    required this.before,
    required this.after,
  });

  final int reelId;
  final DateTime before;
  final DateTime after;

  @override
  bool operator ==(Object other) =>
      other is ReelTouch &&
      other.reelId == reelId &&
      other.before == before &&
      other.after == after;

  @override
  int get hashCode => Object.hash(reelId, before, after);

  @override
  String toString() => 'ReelTouch($reelId, $before → $after)';
}

/// What `ClipsRepository.removeClipsFromReel` changed.
final class RemoveUndo extends UndoRecord {
  RemoveUndo({
    required this.reelId,
    required List<ClipLink> removedLinks,
    required List<Clip> sweptClips,
    required this.touch,
  }) : removedLinks = List.unmodifiable(removedLinks),
       sweptClips = List.unmodifiable(sweptClips);

  final int reelId;

  /// The links that were deleted, with their `addedAt`.
  final List<ClipLink> removedLinks;

  /// Every field of each clip the orphan sweep deleted (D-56).
  final List<Clip> sweptClips;

  /// The reel's `updatedAt`, or null when no link was removed (the action did
  /// not touch it).
  final ReelTouch? touch;

  @override
  bool get isEmpty => removedLinks.isEmpty;
}

/// What `ClipsRepository.moveClips` changed.
final class MoveUndo extends UndoRecord {
  MoveUndo({
    required this.fromReelId,
    required this.toReelId,
    required List<ClipLink> createdLinks,
    required List<ClipLink> removedLinks,
    required List<ReelTouch> touches,
  }) : createdLinks = List.unmodifiable(createdLinks),
       removedLinks = List.unmodifiable(removedLinks),
       touches = List.unmodifiable(touches);

  final int fromReelId;
  final int toReelId;

  /// The links the move created in the target reel. A clip the target
  /// already had is not here: its link was there before and stays.
  final List<ClipLink> createdLinks;

  /// The source reel's links that the move deleted, with their `addedAt`.
  final List<ClipLink> removedLinks;

  /// The `updatedAt` of each reel the move changed.
  final List<ReelTouch> touches;

  @override
  bool get isEmpty => createdLinks.isEmpty && removedLinks.isEmpty;
}

/// What `ClipsRepository.addClipsToReel` changed.
final class AddUndo extends UndoRecord {
  AddUndo({
    required this.reelId,
    required List<ClipLink> createdLinks,
    required List<InboxEntry> removedInbox,
    required this.touch,
  }) : createdLinks = List.unmodifiable(createdLinks),
       removedInbox = List.unmodifiable(removedInbox);

  final int reelId;

  /// The links the add created. A clip the reel already had is not here.
  final List<ClipLink> createdLinks;

  /// The To tag and Skipped rows the add deleted, with their state and
  /// `addedAt`.
  final List<InboxEntry> removedInbox;

  /// The reel's `updatedAt`, or null when no link was added.
  final ReelTouch? touch;

  @override
  bool get isEmpty => createdLinks.isEmpty && removedInbox.isEmpty;
}

/// What `ClipsRepository.skipClips`, `skipAllPending` or `restoreClips`
/// changed (D-94).
///
/// [before] holds each `inbox` row the action moved, as it was (its state and
/// `addedAt`), and [after] the state the action gave them all. The action
/// moves only the state, so a row it left is in [after] with the same
/// `addedAt`. Undo puts back only the rows that are still exactly that: a
/// clip tagged since, restored since (after a skip), skipped since (after a
/// restore) or put back in To tag since keeps what happened to it, and a
/// clip that arrived later is not in the record. A row that went back and
/// forth to exactly [after] again (skipped, restored, skipped) matches, and
/// an old record would still undo it; that is accepted because each action's
/// Undo snack replaces the one before, so only the latest action offers Undo
/// (D-94).
final class InboxUndo extends UndoRecord {
  InboxUndo({required List<InboxEntry> before, required this.after})
    : before = List.unmodifiable(before);

  /// The rows the action changed, as they were, by clip id.
  final List<InboxEntry> before;

  /// The state the action set: `skipped` for a skip, `pending` for a
  /// restore.
  final InboxState after;

  @override
  bool get isEmpty => before.isEmpty;
}

/// What `ClipsRepository.removeMissingFromInbox` changed: a missing clip's
/// row in To tag or Skipped, and the clip itself if the orphan sweep (D-56)
/// then deleted it (D-116).
final class InboxRemoveUndo extends UndoRecord {
  InboxRemoveUndo({
    required List<InboxEntry> removed,
    required List<Clip> sweptClips,
  }) : removed = List.unmodifiable(removed),
       sweptClips = List.unmodifiable(sweptClips);

  /// The rows that were deleted, as they were (state and `addedAt`).
  final List<InboxEntry> removed;

  /// Every field of each clip the orphan sweep deleted.
  final List<Clip> sweptClips;

  @override
  bool get isEmpty => removed.isEmpty;
}

/// What `ReelsRepository.delete` changed.
final class DeleteReelUndo extends UndoRecord {
  DeleteReelUndo({
    required this.reel,
    required List<ClipLink> links,
    required List<ReelReference> references,
    required this.editSession,
    required List<EditCopy> editCopies,
    required List<Clip> sweptClips,
  }) : links = List.unmodifiable(links),
       references = List.unmodifiable(references),
       editCopies = List.unmodifiable(editCopies),
       sweptClips = List.unmodifiable(sweptClips);

  /// The deleted reel, every field; null when there was no such reel (the
  /// record then restores nothing).
  final Reel? reel;

  /// The reel's clip links, with their `addedAt`.
  final List<ClipLink> links;

  /// The reel's references.
  final List<ReelReference> references;

  /// The reel's editing session, if it had one (D-120). The app ends the
  /// session before it deletes a reel (R8), so on the app's path this is
  /// null and [editCopies] is empty; they are kept as a defence in depth.
  /// The session's sent rows are not kept: Undo never brings them back.
  final EditSession? editSession;

  /// The copy rows of that session.
  final List<EditCopy> editCopies;

  /// Every field of each clip the orphan sweep deleted (D-56).
  final List<Clip> sweptClips;

  @override
  bool get isEmpty => reel == null;
}
