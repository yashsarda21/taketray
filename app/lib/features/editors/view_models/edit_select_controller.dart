import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/rules/shooting_days.dart';
import 'package:taketray/domain/rules/shooting_order.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';

part 'edit_select_controller.g.dart';

/// Which reel the clip picking screen is for, and which clips start ticked.
///
/// The arguments of [EditSelectController]; they compare by value, so one
/// screen keeps one controller however often it is built.
@immutable
class EditSelectArgs {
  EditSelectArgs(this.reelId, Iterable<int> preselected)
    : preselected = List.unmodifiable(preselected);

  final int reelId;

  /// Clip ids to tick at first (the reel page's ⋮ menu); ids that are not
  /// live clips of the reel are dropped.
  final List<int> preselected;

  @override
  bool operator ==(Object other) =>
      other is EditSelectArgs &&
      other.reelId == reelId &&
      listEquals(other.preselected, preselected);

  @override
  int get hashCode => Object.hash(reelId, Object.hashAll(preselected));
}

/// What the clip picking screen shows (D-126).
@immutable
class EditSelectState {
  const new({
    required this.reel,
    required this.days,
    required this.times,
    required this.selected,
    required this.pickedInOrder,
    required this.pickedDurationMs,
    required this.pickedBytes,
    required this.liveCount,
  });

  final Reel reel;

  /// The live clips of the reel by the day they were shot (D-83), earliest
  /// day first. Missing clips are not here.
  final List<ShootingDay<ReelClip>> days;

  /// The time where each clip was shot, by clip id; a clip not here yet shows
  /// the phone's time.
  final Map<int, ClipLocalTime> times;

  /// The ids of the ticked clips; always live clips of the reel.
  final Set<int> selected;

  /// The ticked clips' ids in shooting order (oldest date taken first).
  final List<int> pickedInOrder;

  /// The ticked clips' total length and size.
  final int pickedDurationMs;
  final int pickedBytes;

  /// How many live clips the reel has.
  final int liveCount;

  /// Whether every live clip is ticked (false for a reel with none).
  bool get allPicked => liveCount > 0 && selected.length == liveCount;
}

/// The clips ticked on the picking screen of one reel (D-126).
///
/// - **Only live clips can be ticked.** A missing clip is not listed, a clip
///   of another reel or an unknown id cannot be ticked, and the preselected
///   ids are cut down the same way.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
///
/// Auto-disposes with the screen.
@Riverpod(retry: noRetry)
class EditSelectController extends _$EditSelectController {
  /// The ticked ids, once the first state has been built ([_seeded]).
  Set<int> _selected = {};
  bool _seeded = false;

  late Reel _reel;
  List<ReelClip> _live = const [];
  Map<int, ClipLocalTime> _times = const {};

  @override
  Future<EditSelectState?> build(EditSelectArgs args) async {
    final reelFuture = ref.watch(reelByIdProvider(args.reelId).future);
    final clipsFuture = ref.watch(reelClipsProvider(args.reelId).future);
    // Never awaited: the screen shows without the times.
    _times =
        ref.watch(reelClipTimesProvider(args.reelId)).value ??
        const <int, ClipLocalTime>{};
    final reel = await reelFuture;
    if (reel == null) return null;
    _reel = reel;
    _live = [
      for (final c in await clipsFuture)
        if (!c.clip.missing) c,
    ];
    final liveIds = {for (final c in _live) c.clip.id};
    _selected = (_seeded ? _selected : args.preselected.toSet()).intersection(
      liveIds,
    );
    _seeded = true;
    return _stateNow();
  }

  EditSelectState _stateNow() {
    final selected = _selected;
    final picked = inShootingOrder([
      for (final c in _live)
        if (selected.contains(c.clip.id)) c.clip,
    ]);
    return EditSelectState(
      reel: _reel,
      days: groupByShootingDay<ReelClip>(_live, (c) => c.clip, _times),
      times: _times,
      selected: Set.unmodifiable(selected),
      pickedInOrder: [for (final c in picked) c.id],
      pickedDurationMs: picked.fold(0, (s, c) => s + c.fingerprint.durationMs),
      pickedBytes: picked.fold(0, (s, c) => s + c.fingerprint.sizeBytes),
      liveCount: _live.length,
    );
  }

  void _set(Set<int> next) {
    if (state.value == null) return;
    _selected = next;
    state = AsyncData(_stateNow());
  }

  /// Ticks [clipId], or un-ticks it when it is ticked. Nothing happens for a
  /// clip that is not a live clip of the reel.
  void toggle(int clipId) {
    if (!_seeded) return;
    final next = {..._selected};
    if (!next.remove(clipId)) {
      if (!_live.any((c) => c.clip.id == clipId)) return;
      next.add(clipId);
    }
    _set(next);
  }

  /// Ticks every live clip.
  void selectAll() => _set({for (final c in _live) c.clip.id});

  /// Un-ticks every clip.
  void clear() => _set({});
}

/// Whether reel [reelId] has an editing session (D-120); no value until the
/// database has answered. A reel being edited cannot start another edit
/// (R1).
@riverpod
Stream<bool> reelInEditingSession(Ref ref, int reelId) => ref
    .watch(editSessionsRepositoryProvider)
    .watchEditState(reelId)
    .map((state) => state != null);
