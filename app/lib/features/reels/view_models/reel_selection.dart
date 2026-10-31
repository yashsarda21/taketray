import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';

part 'reel_selection.g.dart';

/// Which clips of a reel are chosen (D-88).
@immutable
class ReelSelectionState {
  const new({this.selecting = false, this.selected = const {}});

  /// Whether the reel's page is choosing clips. True with nothing chosen yet
  /// when **Select clips** was used (the bar then says "0 selected").
  final bool selecting;

  /// The ids of the chosen clips. Never holds a missing clip.
  final Set<int> selected;

  @override
  bool operator ==(Object other) =>
      other is ReelSelectionState &&
      other.selecting == selecting &&
      setEquals(other.selected, selected);

  @override
  int get hashCode => Object.hash(selecting, Object.hashAllUnordered(selected));
}

/// Choosing clips on reel [reelId]'s page (D-88; `app.js`: `startSel`,
/// `toggleSel`, `selAll`, `clearSel`).
///
/// - **Only a clip that is in this reel and not missing can be chosen.** A
///   missing tile is not selectable, and [selectAll] skips them. Before the
///   reel's clips have been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]), as
///   `toggleSel` does; [begin] is the one way to be choosing with nothing
///   chosen.
/// - **It follows the reel's clips.** A chosen clip that goes missing, or
///   leaves the reel, is un-chosen; when that empties a selection that had
///   clips, choosing ends.
///
/// Auto-disposes with the page.
@riverpod
class ReelSelection extends _$ReelSelection {
  @override
  ReelSelectionState build(int reelId) {
    ref.listen(reelClipsProvider(reelId), (_, next) {
      final clips = next.value;
      if (clips != null) _prune(_liveIds(clips));
    });
    return const ReelSelectionState();
  }

  Set<int> _liveIds(List<ReelClip> clips) => {
    for (final c in clips)
      if (!c.clip.missing) c.clip.id,
  };

  Set<int> get _live =>
      _liveIds(ref.read(reelClipsProvider(reelId)).value ?? const []);

  void _prune(Set<int> live) {
    if (state.selected.isEmpty) return;
    final kept = state.selected.intersection(live);
    if (kept.length == state.selected.length) return;
    state = kept.isEmpty
        ? const ReelSelectionState()
        : ReelSelectionState(selecting: true, selected: kept);
  }

  /// Starts choosing with nothing chosen (**Select clips**).
  void begin() {
    if (!state.selecting) state = const ReelSelectionState(selecting: true);
  }

  /// Starts choosing with [clipId] chosen (a long press). Nothing happens for
  /// a clip that cannot be chosen.
  void start(int clipId) {
    if (!_live.contains(clipId)) return;
    state = ReelSelectionState(selecting: true, selected: {clipId});
  }

  /// Chooses [clipId], or un-chooses it when it is chosen. Un-choosing the
  /// last one ends choosing. Nothing happens for a clip that cannot be
  /// chosen.
  void toggle(int clipId) {
    final next = {...state.selected};
    if (!next.remove(clipId)) {
      if (!_live.contains(clipId)) return;
      next.add(clipId);
    }
    state = next.isEmpty
        ? const ReelSelectionState()
        : ReelSelectionState(selecting: true, selected: next);
  }

  /// Chooses every clip that is not missing.
  void selectAll() {
    if (ref.read(reelClipsProvider(reelId)).value == null) return;
    state = ReelSelectionState(selecting: true, selected: _live);
  }

  /// Ends choosing.
  void clear() {
    if (state.selecting || state.selected.isNotEmpty) {
      state = const ReelSelectionState();
    }
  }
}
