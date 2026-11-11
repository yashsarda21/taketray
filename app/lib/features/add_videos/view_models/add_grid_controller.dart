import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/add_videos/view_models/folder_video.dart';
import 'package:taketray/platform/media_bridge.dart';

export 'package:taketray/features/add_videos/view_models/folder_video.dart';

part 'add_grid_controller.g.dart';

// Counts and error types only: never a video's name, a folder or a reel's
// name (D-10).
final Logger _log = Logger('addGrid');

/// How many videos the grid asks the phone for at a time (Review Focus 1):
/// a folder of thousands is read a page at a time, near the end of what is
/// shown.
const int addGridPageSize = 200;

/// What the Add videos grid shows of one folder (D-114).
@immutable
class AddGridState {
  AddGridState({
    required this.videos,
    required this.marks,
    required this.selected,
    required this.hasMore,
    required this.rowsRead,
    this.loadingMore = false,
    this.moreFailed = false,
    this.adding = false,
  }) : _ids = {for (final v in videos) v.id};

  AddGridState._same(
    AddGridState from, {
    required this.marks,
    required this.selected,
    required this.hasMore,
    required this.rowsRead,
    required this.loadingMore,
    required this.moreFailed,
    required this.adding,
  }) : videos = from.videos,
       _ids = from._ids;

  /// The videos read so far, newest shot first (the phone's order), each
  /// once.
  final List<FolderVideo> videos;

  /// Why a video is already added, by MediaStore id; an unmarked video is
  /// not in the map (`AddVideosService.marks`).
  final Map<int, AddMark> marks;

  /// The picked videos' ids, in the order they were picked. Never a marked
  /// video, and only videos in [videos].
  final Set<int> selected;

  /// Whether the last page read was full, so there may be more.
  final bool hasMore;

  /// How many rows the phone has given so far: the next page's offset.
  final int rowsRead;

  /// A next page is being read.
  final bool loadingMore;

  /// The last next page could not be read.
  final bool moreFailed;

  /// An add is running (and, once it has worked, the screen is leaving).
  final bool adding;

  final Set<int> _ids;

  /// Whether the video [id] is in the grid.
  bool shows(int id) => _ids.contains(id);

  /// The total length of the picked videos.
  int get pickedDurationMs => videos.fold(
    0,
    (sum, v) => selected.contains(v.id) ? sum + v.durationMs : sum,
  );

  AddGridState copyWith({
    List<FolderVideo>? videos,
    Map<int, AddMark>? marks,
    Set<int>? selected,
    bool? hasMore,
    int? rowsRead,
    bool? loadingMore,
    bool? moreFailed,
    bool? adding,
  }) => videos == null
      // The same videos: their ids are not gathered again (a tap on a tile
      // in a folder of thousands).
      ? AddGridState._same(
          this,
          marks: marks ?? this.marks,
          selected: selected ?? this.selected,
          hasMore: hasMore ?? this.hasMore,
          rowsRead: rowsRead ?? this.rowsRead,
          loadingMore: loadingMore ?? this.loadingMore,
          moreFailed: moreFailed ?? this.moreFailed,
          adding: adding ?? this.adding,
        )
      : AddGridState(
          videos: videos,
          marks: marks ?? this.marks,
          selected: selected ?? this.selected,
          hasMore: hasMore ?? this.hasMore,
          rowsRead: rowsRead ?? this.rowsRead,
          loadingMore: loadingMore ?? this.loadingMore,
          moreFailed: moreFailed ?? this.moreFailed,
          adding: adding ?? this.adding,
        );
}

/// How an add ended.
sealed class AddOutcome {
  const AddOutcome();
}

/// The add worked: [result] says what it did. The screen leaves.
final class AddDone extends AddOutcome {
  const AddDone(this.result);

  final AddResult result;
}

/// The add failed, or nothing could be kept: nothing was written, the choice
/// is kept to try again.
final class AddFailed extends AddOutcome {
  const AddFailed();
}

/// The add failed because its reel was deleted: the screen leaves calmly.
final class AddTargetGone extends AddOutcome {
  const AddTargetGone();
}

/// One folder of one volume in Add videos' grid, for an add to [target]
/// (D-114, Review Focus 1).
///
/// - **Pages.** The first [addGridPageSize] videos are read when the grid
///   opens; [loadMore] reads the next page (the screen asks near the end of
///   what is shown). Only one page is read at a time. A page that repeats a
///   video already shown (a video arrived meanwhile and pushed the rest down)
///   adds it once. A page with fewer than [addGridPageSize] is the last.
/// - **Marks** are read with each page (`AddVideosService.marks`), before its
///   videos show, so a video is never pickable and then marked. Marks that
///   cannot be read leave the page unmarked (logged by type): the add decides
///   each video again.
/// - **The choice** ([toggle]) survives paging; a marked video, or one not
///   in the grid, cannot be picked; nothing changes while an add runs.
/// - **[refresh]** (the app comes back to the front) reads again as many
///   rows as were read, keeps what is still picked, and drops a picked video
///   that is gone or now marked. A page that was being read when a refresh
///   started is dropped when it arrives.
/// - **[add]** adds the picked videos, oldest first, once: a second call
///   while one runs does nothing.
@Riverpod(retry: noRetry)
class AddGridController extends _$AddGridController {
  /// Bumped by every (re)read of the whole folder: a page read before it is
  /// dropped when it arrives.
  int _epoch = 0;

  Future<void>? _loading;
  int _loadingEpoch = -1;

  @override
  Future<AddGridState> build(
    AddTarget target,
    String volumeName,
    String relativePath,
  ) async {
    _epoch++;
    final (videos, rowsRead, full) = await _read(addGridPageSize);
    final marks = await _marksOf(videos);
    return AddGridState(
      videos: videos,
      marks: marks,
      selected: const {},
      hasMore: full,
      rowsRead: rowsRead,
    );
  }

  /// **Try again** after the first page failed: reads it again.
  void retry() => ref.invalidateSelf();

  /// Reads the next page, unless one is being read, there is no more, or the
  /// first page is not there. A failure sets [AddGridState.moreFailed]; the
  /// next call tries the same page again.
  Future<void> loadMore() {
    final running = _loading;
    if (running != null && _loadingEpoch == _epoch) return running;
    final epoch = _loadingEpoch = _epoch;
    late final Future<void> load;
    load = _loadMore(epoch).whenComplete(() {
      if (identical(_loading, load)) _loading = null;
    });
    return _loading = load;
  }

  Future<void> _loadMore(int epoch) async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    _set(current.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await _page(current.rowsRead);
      final now = ref.read(clockProvider).now();
      final fresh = [
        for (final v in page)
          if (!current.shows(v.mediaStoreId)) FolderVideo.of(v, now: now),
      ];
      final marks = await _marksOf(fresh);
      if (epoch != _epoch || !ref.mounted) return;
      final latest = state.requireValue;
      _set(
        latest.copyWith(
          videos: [...latest.videos, ...fresh],
          marks: {...latest.marks, ...marks},
          hasMore: page.length == addGridPageSize,
          rowsRead: latest.rowsRead + page.length,
          loadingMore: false,
        ),
      );
    } on Object catch (error) {
      _log.warning('Reading the next page failed: ${error.runtimeType}');
      if (epoch != _epoch || !ref.mounted) return;
      _set(state.requireValue.copyWith(loadingMore: false, moreFailed: true));
    }
  }

  /// Reads the folder again (the app came back to the front): as many rows
  /// as were read, at least a page, with their marks. What is still picked,
  /// shown and unmarked stays picked. A first page that had failed is read
  /// again. Nothing is read while an add runs. A failure is logged by type
  /// and the grid stays as it was.
  Future<void> refresh() async {
    final current = state.value;
    if (current == null) {
      if (state.hasError) retry();
      return;
    }
    if (current.adding) return;
    final epoch = ++_epoch;
    try {
      final (videos, rowsRead, full) = await _read(
        current.rowsRead > addGridPageSize ? current.rowsRead : addGridPageSize,
      );
      final marks = await _marksOf(videos);
      if (epoch != _epoch || !ref.mounted) return;
      final latest = state.requireValue;
      final shown = {for (final v in videos) v.id};
      final selected = {
        for (final id in latest.selected)
          if (shown.contains(id) && !marks.containsKey(id)) id,
      };
      _set(
        AddGridState(
          videos: videos,
          marks: marks,
          selected: selected,
          hasMore: full,
          rowsRead: rowsRead,
          adding: latest.adding,
        ),
      );
      _log.info(
        'Read the folder again: ${videos.length} videos, '
        '${latest.selected.length - selected.length} left the choice',
      );
    } on Object catch (error) {
      _log.warning('Reading the folder again failed: ${error.runtimeType}');
    }
  }

  /// Picks or unpicks the video [id]. False, and nothing changes, when it is
  /// marked, not in the grid, or an add runs.
  bool toggle(int id) {
    final current = state.value;
    if (current == null ||
        current.adding ||
        current.marks.containsKey(id) ||
        !current.shows(id)) {
      return false;
    }
    final selected = {...current.selected};
    if (!selected.remove(id)) selected.add(id);
    _set(current.copyWith(selected: selected));
    return true;
  }

  /// Adds the picked videos to the target, oldest first (one
  /// `AddVideosService.addFromFolder` job). Null, and nothing happens, when
  /// nothing is picked or an add runs. While it runs the choice is frozen.
  ///
  /// - It worked (something added or already there): [AddDone]; the grid
  ///   stays frozen, because the screen leaves.
  /// - Nothing could be kept (a card removed meanwhile) or it failed:
  ///   [AddFailed], and the choice is kept.
  /// - It failed and the target reel is gone: [AddTargetGone].
  Future<AddOutcome?> add() async {
    final current = state.value;
    if (current == null || current.adding || current.selected.isEmpty) {
      return null;
    }
    final picked = [
      for (final v in current.videos)
        if (current.selected.contains(v.id)) v,
    ]..sort(_shootingOrder);
    // Read now: the screen may close (and this be disposed) during the add.
    final service = ref.read(addVideosServiceProvider);
    final reels = ref.read(reelsRepositoryProvider);
    final target = this.target;
    _set(current.copyWith(adding: true));
    try {
      final result = await service.addFromFolder([
        for (final v in picked) v.video,
      ], target);
      if (result.added == 0 && result.alreadyThere == 0) {
        _log.warning('The add kept nothing: ${result.notKept} not kept');
        _unfreeze();
        return const AddFailed();
      }
      return AddDone(result);
    } on Object catch (error) {
      _log.warning('The add failed: ${error.runtimeType}');
      if (target case AddToReel(:final reelId)) {
        final reel = await guarded(_log, 'Reading the reel', () async {
          return await reels.getById(reelId);
        });
        if (reel == null) {
          _unfreeze();
          return const AddTargetGone();
        }
      }
      _unfreeze();
      return const AddFailed();
    }
  }

  void _unfreeze() {
    if (!ref.mounted) return;
    _set(state.requireValue.copyWith(adding: false));
  }

  void _set(AddGridState next) {
    if (ref.mounted) state = AsyncData(next);
  }

  /// Reads pages from the start until [atLeast] rows are read or a page is
  /// short: the videos (each once), the rows read, and whether the last page
  /// was full.
  Future<(List<FolderVideo>, int, bool)> _read(int atLeast) async {
    final now = ref.read(clockProvider).now();
    final videos = <FolderVideo>[];
    final seen = <int>{};
    var rows = 0;
    var full = true;
    while (full && rows < atLeast) {
      final page = await _page(rows);
      rows += page.length;
      full = page.length == addGridPageSize;
      for (final v in page) {
        if (seen.add(v.mediaStoreId)) videos.add(FolderVideo.of(v, now: now));
      }
    }
    return (videos, rows, full);
  }

  Future<List<MediaVideo>> _page(int offset) => ref
      .read(mediaBridgeProvider)
      .videosInFolder(volumeName, relativePath, addGridPageSize, offset);

  Future<Map<int, AddMark>> _marksOf(List<FolderVideo> videos) async {
    if (videos.isEmpty) return const {};
    try {
      return await ref.read(addVideosServiceProvider).marks(volumeName, [
        for (final v in videos) v.id,
      ], target);
    } on Object catch (error) {
      _log.warning('Reading the marks failed: ${error.runtimeType}');
      return const {};
    }
  }
}

/// Oldest shot first, then the lower id.
int _shootingOrder(FolderVideo a, FolderVideo b) {
  final byShot = a.shotAt.compareTo(b.shotAt);
  return byShot != 0 ? byShot : a.id.compareTo(b.id);
}
