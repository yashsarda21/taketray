import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';

part 'clip_viewer_controller.g.dart';

/// What the clip viewer shows (D-89).
@immutable
class ClipViewerState {
  const new({
    required this.reel,
    required this.clips,
    required this.index,
    required this.times,
    this.timesFailed = false,
  }) : assert(index >= 0 && index < clips.length, 'index is in the pager');

  final Reel reel;

  /// The pager: the reel's clips that are **not missing**, in the reel's
  /// order (shot first). Never empty.
  final List<ReelClip> clips;

  /// The page showing, an index into [clips].
  final int index;

  /// The time where each clip was shot, by clip id (D-83). A clip that is not
  /// here yet has no time shown (the phone's would be the wrong one).
  final Map<int, ClipLocalTime> times;

  /// Whether reading the times **failed** (not: is still going on). The
  /// viewer then shows the phone's own time for a clip, as the reel page's
  /// tiles do, instead of an empty line for good.
  final bool timesFailed;

  /// The clip showing.
  ReelClip get current => clips[index];

  /// The time where the clip showing was shot, once known.
  ClipLocalTime? get currentTime => times[current.clip.id];

  ClipViewerState _movedTo(int next) => ClipViewerState(
    reel: reel,
    clips: clips,
    index: next,
    times: times,
    timesFailed: timesFailed,
  );
}

/// The reels (by name) that clip [clipId] is in, in the order the reels were
/// made, again after every change to the links or a rename.
@riverpod
Future<List<String>> clipReelNames(Ref ref, int clipId) async {
  final ids = await ref.watch(_reelIdsOfProvider(clipId).future);
  final reels = await ref.watch(_allReelsProvider.future);
  final inside = [
    for (final reel in reels)
      if (ids.contains(reel.id)) reel,
  ]..sort((a, b) => a.id.compareTo(b.id));
  return [for (final reel in inside) reel.name];
}

@riverpod
Stream<Set<int>> _reelIdsOf(Ref ref, int clipId) =>
    ref.watch(clipsRepositoryProvider).watchReelIdsOf(clipId);

@riverpod
Stream<List<Reel>> _allReels(Ref ref) =>
    ref.watch(reelsRepositoryProvider).watchAll();

/// The clip viewer of reel [reelId], opened on clip [clipId] (D-89).
///
/// - **The pager is the reel's clips that are not missing**, in the reel's
///   order, from the database's own streams, so it follows every change.
/// - **It opens on [clipId], or on nothing.** If that clip is missing, not in
///   the reel, or the reel is gone, the state is `null` and the screen goes
///   back: it never opens another clip in its place (spec §4, the wrong video
///   is the worst bug).
/// - **It stays on its clip by id.** The index is looked up from the list
///   each time, so a clip joining or leaving elsewhere in the reel does not
///   move the viewer.
/// - **Leaving a clip** (removed or moved here or elsewhere, or turned
///   missing by a verify; `viewerAfterLeave` in the prototype) goes to the
///   clip that now stands in its place, the next one, or the one before it
///   when the last was left. With none left the state is `null`: the screen
///   goes back.
/// - **The times never hold it back** (as in D-87): the viewer opens at once,
///   and a clip's time appears when `ClipTimeService` has answered. If
///   reading them **fails**, [ClipViewerState.timesFailed] is set and the
///   screen shows the phone's time (never while they are only loading).
///
/// [goTo] is the page changing. Auto-disposes with the screen.
@Riverpod(retry: noRetry)
class ClipViewerController extends _$ClipViewerController {
  /// The id of the clip the viewer is on; the one it opened on at first.
  int? _currentId;

  /// Where that clip was in the pager the last time.
  int _lastIndex = 0;

  /// Whether the viewer has shown a clip.
  bool _opened = false;

  @override
  Future<ClipViewerState?> build(int reelId, int clipId) async {
    final reelFuture = ref.watch(reelByIdProvider(reelId).future);
    final clipsFuture = ref.watch(reelClipsProvider(reelId).future);
    // Never awaited: the viewer shows without the times.
    final timesNow = ref.watch(reelClipTimesProvider(reelId));
    final times = timesNow.value ?? const <int, ClipLocalTime>{};
    final timesFailed = timesNow.hasError && !timesNow.hasValue;

    final reel = await reelFuture;
    if (reel == null) return null;
    final live = [
      for (final rc in await clipsFuture)
        if (!rc.clip.missing) rc,
    ];
    var index = live.indexWhere((rc) => rc.clip.id == (_currentId ?? clipId));
    if (index < 0) {
      // The clip asked for is not playable: nothing to show. Or the clip on
      // screen has left: its neighbour takes over.
      if (!_opened || live.isEmpty) return null;
      index = math.min(_lastIndex, live.length - 1);
    }
    _opened = true;
    _currentId = live[index].clip.id;
    _lastIndex = index;
    return ClipViewerState(
      reel: reel,
      clips: live,
      index: index,
      times: times,
      timesFailed: timesFailed,
    );
  }

  /// Moves to page [index] of the pager. Ignores an index that is not there
  /// and any call before the pager is ready.
  void goTo(int index) {
    final current = state.value;
    if (current == null || index < 0 || index >= current.clips.length) return;
    if (index == current.index) return;
    _currentId = current.clips[index].clip.id;
    _lastIndex = index;
    state = AsyncData(current._movedTo(index));
  }
}
