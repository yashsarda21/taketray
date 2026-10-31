import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/undo_record.dart';

part 'reel_clip_actions.g.dart';

// Ids and counts only, never a reel name (D-10).
final Logger _log = Logger('reelClipActions');

/// What an add, move or remove did, for its snack (D-88).
class ClipActionOutcome {
  ClipActionOutcome({
    required List<UndoRecord> records,
    required List<String> reelNames,
    required this.clipCount,
  }) : records = List.unmodifiable(records),
       reelNames = List.unmodifiable(reelNames);

  /// What Undo needs, one record for each repository call, in the order they
  /// ran. Undo them last to first.
  final List<UndoRecord> records;

  /// The names of the reels the snack names: the reels added to, the reel
  /// moved to, or the reel removed from. In the order they were picked.
  final List<String> reelNames;

  /// How many clips were taken out of the reel (remove only; 0 otherwise).
  final int clipCount;

  /// Whether nothing changed (every clip was there already), so Undo would
  /// put nothing back.
  bool get isEmpty => records.every((r) => r.isEmpty);
}

/// What the selection bar does to the chosen clips (D-88): add them to
/// reels, move them to another reel, remove them from this one. Each returns
/// what its snack needs.
///
/// Kept alive, so an action that was started on a page that then goes away
/// still finishes and can be undone.
class ReelClipActions {
  ReelClipActions(this._reels, this._clips);

  final ReelsRepository _reels;
  final ClipsRepository _clips;

  Future<String> _nameOf(int reelId) async {
    final reel = await _reels.getById(reelId);
    if (reel == null) throw StateError('No reel with id $reelId');
    return reel.name;
  }

  /// Adds [clipIds] to every reel of [reelIds] (they stay where they are).
  ///
  /// All or nothing, as far as the user can tell: if one reel fails (or is
  /// gone), the adds that were done are undone before this throws. Throws
  /// [ArgumentError] for no reels.
  Future<ClipActionOutcome> addToReels({
    required Set<int> clipIds,
    required List<int> reelIds,
  }) async {
    if (reelIds.isEmpty) throw ArgumentError.value(reelIds, 'reelIds');
    final names = [for (final id in reelIds) await _nameOf(id)];
    final records = <UndoRecord>[];
    try {
      for (final id in reelIds) {
        records.add(await _clips.addClipsToReel(id, clipIds));
      }
    } on Object catch (error) {
      _log.warning(
        'Adding ${clipIds.length} clips to ${reelIds.length} reels failed '
        'after ${records.length}: ${error.runtimeType}',
      );
      for (final record in records.reversed) {
        try {
          await _clips.undo(record);
        } on Object catch (undoError) {
          _log.warning('Taking an add back failed: ${undoError.runtimeType}');
        }
      }
      rethrow;
    }
    return ClipActionOutcome(
      records: records,
      reelNames: names,
      clipCount: clipIds.length,
    );
  }

  /// Moves [clipIds] from [fromReelId] to [toReelId]. Throws [StateError]
  /// for a reel that is gone, changing nothing.
  Future<ClipActionOutcome> moveToReel({
    required int fromReelId,
    required int toReelId,
    required Set<int> clipIds,
  }) async {
    final name = await _nameOf(toReelId);
    try {
      final record = await _clips.moveClips(fromReelId, toReelId, clipIds);
      return ClipActionOutcome(
        records: [record],
        reelNames: [name],
        clipCount: record.removedLinks.length,
      );
    } on Object catch (error) {
      _log.warning(
        'Moving ${clipIds.length} clips from reel $fromReelId to '
        '$toReelId failed: ${error.runtimeType}',
      );
      rethrow;
    }
  }

  /// Removes [clipIds] from reel [reelId]. The videos stay in the gallery.
  Future<ClipActionOutcome> removeFromReel({
    required int reelId,
    required Set<int> clipIds,
  }) async {
    final name = await _nameOf(reelId);
    try {
      final record = await _clips.removeClipsFromReel(reelId, clipIds);
      return ClipActionOutcome(
        records: [record],
        reelNames: [name],
        clipCount: record.removedLinks.length,
      );
    } on Object catch (error) {
      _log.warning(
        'Removing ${clipIds.length} clips from reel $reelId failed: '
        '${error.runtimeType}',
      );
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
ReelClipActions reelClipActions(Ref ref) => ReelClipActions(
  ref.watch(reelsRepositoryProvider),
  ref.watch(clipsRepositoryProvider),
);
