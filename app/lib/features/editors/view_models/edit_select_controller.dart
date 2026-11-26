import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/rules/edit_split.dart';
import 'package:taketray/domain/rules/shooting_days.dart';
import 'package:taketray/domain/rules/shooting_order.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';

part 'edit_select_controller.g.dart';

/// What the clip picking screen shows (D-126, add mode only since D-192).
@immutable
class EditSelectState {
  const new({
    required this.reel,
    required this.days,
    required this.times,
    required this.selected,
    required this.liveCount,
    this.editor,
    this.folder,
    this.inFolder = const {},
    this.toCopyInOrder = const [],
    this.toCopyBytes = 0,
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

  /// How many live clips the reel has.
  final int liveCount;

  /// The editor of the reel's session; null when the reel has no session
  /// (Done editing ran meanwhile): the screen then leaves.
  final EditorApp? editor;

  /// The session's folder under `Movies/TakeTray` (a renamed reel keeps it);
  /// null without a session.
  final String? folder;

  /// The live clips whose copy is in the folder already: ticked and locked,
  /// nothing to copy (`AddPick.inFolder`).
  final Set<int> inFolder;

  /// The ticked clips that would be copied (or sent), in shooting order: the
  /// picked ones, without [inFolder]. And their size.
  final List<int> toCopyInOrder;
  final int toCopyBytes;

  /// Whether every clip that can be ticked is ticked: every live clip, but
  /// the [inFolder] ones. False when none can be ticked.
  bool get allPicked =>
      liveCount > inFolder.length && selected.length == liveCount;
}

/// The clips ticked on the picking screen of one reel [reelId] (D-126, D-128,
/// D-129), which since D-192 is only for adding clips to the reel's editing
/// folder.
///
/// - **Only live clips can be ticked.** A missing clip is not listed, and a
///   clip of another reel or an unknown id cannot be ticked.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
/// - **Add mode** (owner decision 7, D-128, D-129; any editor's session):
///   every live clip, by `addPicks` against the reel's session. A fresh clip
///   (neither sent nor copied) starts ticked, a sent one without a copy
///   starts unticked and can be ticked, a clip whose copy is in the folder is
///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
///   follow-up never un-tick it). Only the other ticked clips are to copy. It
///   follows the session too: a copy recorded meanwhile locks its clip, a
///   copy forgotten (deleted outside TakeTray) frees it, unticked.
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

  /// The session's editor, its folder and the clips in it (locked).
  EditorApp? _editor;
  String? _folder;
  Set<int> _inFolder = const {};

  @override
  Future<EditSelectState?> build(int reelId) async {
    final reelFuture = ref.watch(reelByIdProvider(reelId).future);
    final clipsFuture = ref.watch(reelClipsProvider(reelId).future);
    final editFuture = ref.watch(reelEditSessionProvider(reelId).future);
    // Never awaited: the screen shows without the times.
    _times =
        ref.watch(reelClipTimesProvider(reelId)).value ??
        const <int, ClipLocalTime>{};
    final reel = await reelFuture;
    if (reel == null) return null;
    _reel = reel;
    _live = [
      for (final c in await clipsFuture)
        if (!c.clip.missing) c,
    ];
    final liveIds = {for (final c in _live) c.clip.id};
    final edit = await editFuture;
    final picks = edit == null
        ? const <int, AddPick>{}
        : addPicks(
            [for (final c in _live) c.clip.id],
            sentIds: edit.sentIds,
            liveCopyIds: {for (final c in edit.copies) c.clipId},
          );
    _editor = edit?.session.editor;
    _folder = edit?.session.folderName;
    _inFolder = {
      for (final MapEntry(:key, :value) in picks.entries)
        if (value == AddPick.inFolder) key,
    };
    final seed = _seeded
        ? _selected
        : {
            for (final MapEntry(:key, :value) in picks.entries)
              if (value == AddPick.fresh) key,
          };
    _selected = seed.intersection(liveIds).difference(_inFolder);
    _seeded = true;
    return _stateNow();
  }

  EditSelectState _stateNow() {
    final selected = {..._selected, ..._inFolder};
    final picked = inShootingOrder([
      for (final c in _live)
        if (selected.contains(c.clip.id)) c.clip,
    ]);
    final toCopy = [
      for (final c in picked)
        if (!_inFolder.contains(c.id)) c,
    ];
    return EditSelectState(
      reel: _reel,
      days: groupByShootingDay<ReelClip>(_live, (c) => c.clip, _times),
      times: _times,
      selected: Set.unmodifiable(selected),
      liveCount: _live.length,
      editor: _editor,
      folder: _folder,
      inFolder: Set.unmodifiable(_inFolder),
      toCopyInOrder: [for (final c in toCopy) c.id],
      toCopyBytes: toCopy.fold(0, (s, c) => s + c.fingerprint.sizeBytes),
    );
  }

  void _set(Set<int> next) {
    if (state.value == null) return;
    _selected = next.difference(_inFolder);
    state = AsyncData(_stateNow());
  }

  /// Ticks [clipId], or un-ticks it when it is ticked. Nothing happens for a
  /// clip that is not a live clip of the reel, or whose copy is in the
  /// folder: [_set] keeps those out of the user's own ticks.
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

  /// Un-ticks every clip (but the locked ones).
  void clear() => _set({});
}
