import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';

part 'reel_selection.g.dart';

/// Which clips of a reel are chosen (D-88).
@immutable
class ReelSelectionState {
  const new({
    this.selecting = false,
    this.selected = const {},
    this.fromSheet = false,
  });

  /// Whether the reel's page is choosing clips. True with nothing chosen yet
  /// when **Select clips** was used (the bar then says "0 selected").
  final bool selecting;

  /// The ids of the chosen clips. Never holds a missing clip.
  final Set<int> selected;

  /// Whether choosing was started by **Choose clips instead** on the editor
  /// sheet (D-188). Choosing then stays on with nothing chosen; a held or
  /// **Select clips** start (false) ends when the last clip is un-chosen.
  final bool fromSheet;

  @override
  bool operator ==(Object other) =>
      other is ReelSelectionState &&
      other.selecting == selecting &&
      other.fromSheet == fromSheet &&
      setEquals(other.selected, selected);

  @override
  int get hashCode =>
      Object.hash(selecting, fromSheet, Object.hashAllUnordered(selected));
}

/// Choosing clips on reel [reelId]'s page (D-88; `app.js`: `startSel`,
/// `toggleSel`, `selAll`, `clearSel`).
///
/// - **Only a clip that is in this reel and not missing can be chosen.** A
///   missing tile is not selectable, and [selectAll] skips them. Before the
///   reel's clips have been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]), as
///   `toggleSel` does, unless it started from the editor sheet (D-188):
///   `begin(fromSheet: true)` keeps choosing on with nothing chosen.
///   [begin] is the one way to be choosing with nothing chosen.
/// - **It follows the reel's clips.** A chosen clip that goes missing, or
///   leaves the reel, is un-chosen; when that empties a selection that had
///   clips, choosing ends, unless it started from the sheet.
/// - **Clear keeps choosing on** ([clearChosen]); only [clear] (Close, Back,
///   a picked editor) ends it.
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
    state = _after(kept);
  }

  /// The state once [chosen] is what is chosen: empty ends choosing, unless
  /// it started from the sheet.
  ReelSelectionState _after(Set<int> chosen) {
    if (chosen.isEmpty && !state.fromSheet) return const ReelSelectionState();
    return ReelSelectionState(
      selecting: true,
      selected: chosen,
      fromSheet: state.fromSheet,
    );
  }

  /// Starts choosing with nothing chosen: **Select clips** on the reel's ⋮
  /// menu, or, with [fromSheet], **Choose clips instead** on the editor sheet
  /// (D-188). It is `begin`, not [start], that takes the flag: [start] is the
  /// long press, which is never from the sheet. While already choosing the
  /// chosen clips are kept, and [fromSheet] true is set.
  void begin({bool fromSheet = false}) {
    if (!state.selecting) {
      state = ReelSelectionState(selecting: true, fromSheet: fromSheet);
    } else if (fromSheet && !state.fromSheet) {
      state = ReelSelectionState(
        selecting: true,
        selected: state.selected,
        fromSheet: true,
      );
    }
  }

  /// Starts choosing with [clipId] chosen (a long press). Nothing happens for
  /// a clip that cannot be chosen.
  void start(int clipId) {
    if (!_live.contains(clipId)) return;
    state = ReelSelectionState(selecting: true, selected: {clipId});
  }

  /// Chooses [clipId], or un-chooses it when it is chosen. Un-choosing the
  /// last one ends choosing, unless it started from the sheet. Nothing
  /// happens for a clip that cannot be chosen.
  void toggle(int clipId) {
    final next = {...state.selected};
    if (!next.remove(clipId)) {
      if (!_live.contains(clipId)) return;
      next.add(clipId);
    }
    state = _after(next);
  }

  /// Chooses every clip that is not missing.
  void selectAll() {
    if (ref.read(reelClipsProvider(reelId)).value == null) return;
    state = ReelSelectionState(
      selecting: true,
      selected: _live,
      fromSheet: state.fromSheet,
    );
  }

  /// Un-chooses every clip and keeps choosing on, as the top bar's **Clear**
  /// does (`editflow.js:88`, `selNone`); [ReelSelectionState.fromSheet] is
  /// kept. Nothing happens when not choosing.
  void clearChosen() {
    if (!state.selecting) return;
    state = ReelSelectionState(selecting: true, fromSheet: state.fromSheet);
  }

  /// Ends choosing, and drops [ReelSelectionState.fromSheet].
  void clear() {
    if (state.selecting || state.selected.isNotEmpty) {
      state = const ReelSelectionState();
    }
  }
}
