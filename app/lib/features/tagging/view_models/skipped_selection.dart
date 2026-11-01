import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/features/tagging/view_models/skipped_controller.dart';

part 'skipped_selection.g.dart';

/// Which skipped clips are chosen on the Skipped screen (D-99).
@immutable
class SkippedSelectionState {
  const new({this.selecting = false, this.selected = const {}});

  /// Whether the screen is choosing clips. True with nothing chosen yet after
  /// **Select** (the bar then says "0 selected").
  final bool selecting;

  /// The ids of the chosen clips. Never holds a clip that is missing or no
  /// longer skipped.
  final Set<int> selected;

  @override
  bool operator ==(Object other) =>
      other is SkippedSelectionState &&
      other.selecting == selecting &&
      setEquals(other.selected, selected);

  @override
  int get hashCode => Object.hash(selecting, Object.hashAllUnordered(selected));
}

/// Choosing clips on the Skipped screen (D-99; `app.js`: `startSelBtn`,
/// `startSel`, `toggleSel`, `clearSel`), as To tag chooses (`ToTagSelection`,
/// D-98):
///
/// - **Only a skipped clip that is not missing can be chosen.** Before the
///   list has been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
///   the one way to be choosing with nothing chosen.
/// - **It follows the list.** A chosen clip that leaves Skipped (restored,
///   tagged elsewhere, taken out by a verify) is un-chosen; when that empties
///   a selection that had clips, choosing ends. **When the list itself
///   empties, choosing ends** even with nothing chosen: there is nothing left
///   to choose.
///
/// Auto-disposes with the screen.
@riverpod
class SkippedSelection extends _$SkippedSelection {
  @override
  SkippedSelectionState build() {
    ref.listen(skippedControllerProvider, (_, next) {
      final clips = next.value;
      if (clips != null) _prune(_liveIds(clips));
    });
    return const SkippedSelectionState();
  }

  Set<int> _liveIds(List<Clip> clips) => {
    for (final c in clips)
      if (!c.missing) c.id,
  };

  Set<int> get _live =>
      _liveIds(ref.read(skippedControllerProvider).value ?? const []);

  void _prune(Set<int> live) {
    if (live.isEmpty) {
      clear();
      return;
    }
    if (state.selected.isEmpty) return;
    final kept = state.selected.intersection(live);
    if (kept.length == state.selected.length) return;
    state = kept.isEmpty
        ? const SkippedSelectionState()
        : SkippedSelectionState(selecting: true, selected: kept);
  }

  /// Starts choosing with nothing chosen (**Select**).
  void begin() {
    if (!state.selecting) state = const SkippedSelectionState(selecting: true);
  }

  /// Starts choosing with [clipId] chosen (a long press). Nothing happens for
  /// a clip that cannot be chosen.
  void start(int clipId) {
    if (!_live.contains(clipId)) return;
    state = SkippedSelectionState(selecting: true, selected: {clipId});
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
        ? const SkippedSelectionState()
        : SkippedSelectionState(selecting: true, selected: next);
  }

  /// Ends choosing.
  void clear() {
    if (state.selecting || state.selected.isNotEmpty) {
      state = const SkippedSelectionState();
    }
  }
}
