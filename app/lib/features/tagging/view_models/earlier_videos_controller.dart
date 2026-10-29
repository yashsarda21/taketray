import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/rules/earlier_window.dart';

part 'earlier_videos_controller.g.dart';

// Error types and counts only, never a message (D-10).
final Logger _log = Logger('earlierVideos');

/// The "Add earlier videos" sheet (D-73, D-75): how many videos each range
/// would add, adding a range, and Undo.
///
/// The state is the count per [EarlierRange], read when the sheet opens
/// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
/// auto-disposes: closing the sheet drops it, and opening the sheet again
/// counts again. A failed count is an `AsyncError` for the sheet to show; it
/// is logged by type and not retried by itself.
///
/// [add] and [undo] **rethrow** their errors, after logging the type, so the
/// sheet can tell the user it did not work (a missing full access is a
/// `StateError`). The caller must catch. After either one succeeds the counts
/// are read again, and if that fails the old counts stay.
@Riverpod(retry: noRetry)
class EarlierVideosController extends _$EarlierVideosController {
  @override
  Future<Map<EarlierRange, int>> build() async {
    final scanner = ref.read(mediaScannerProvider);
    try {
      return await scanner.countEarlier();
    } on Object catch (error) {
      _log.warning('Counting earlier videos failed: ${error.runtimeType}');
      rethrow;
    }
  }

  /// Adds the videos of [range] to To tag and returns the new clips' ids
  /// (give them to [undo]). Throws when it could not (see the class
  /// comment).
  Future<List<int>> add(EarlierRange range) async {
    final scanner = ref.read(mediaScannerProvider);
    final List<int> ids;
    try {
      ids = await scanner.addEarlier(range);
    } on Object catch (error) {
      _log.warning('Adding earlier videos failed: ${error.runtimeType}');
      rethrow;
    }
    await _recount(scanner);
    return ids;
  }

  /// Takes the clips [add] returned back out of To tag.
  ///
  /// Only a clip that is still waiting in To tag and in no reel goes: one
  /// tagged or skipped since was dealt with by the user and stays
  /// (`ClipsRepository.undoEarlierAdd`). Runs on the media queue, so it never
  /// overlaps a scan. Throws when it could not (see the class comment).
  Future<void> undo(List<int> ids) async {
    final scanner = ref.read(mediaScannerProvider);
    final clips = ref.read(clipsRepositoryProvider);
    final queue = ref.read(mediaWorkQueueProvider);
    try {
      await queue.run(() => clips.undoEarlierAdd(ids.toSet()));
    } on Object catch (error) {
      _log.warning('Undoing the earlier videos failed: ${error.runtimeType}');
      rethrow;
    }
    await _recount(scanner);
  }

  /// Reads the counts again after a change. A failure is logged and the old
  /// counts stay; a sheet that was closed meanwhile is left alone.
  Future<void> _recount(MediaScanner scanner) async {
    final counts = await guarded(
      _log,
      'Counting earlier videos',
      scanner.countEarlier,
    );
    if (counts != null && ref.mounted) state = AsyncData(counts);
  }
}
