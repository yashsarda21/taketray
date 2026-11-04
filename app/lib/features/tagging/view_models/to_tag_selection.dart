import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';

part 'to_tag_selection.g.dart';

/// Which waiting clips are chosen on To tag (D-98).
@immutable
class ToTagSelectionState {
  const new({this.selecting = false, this.selected = const {}});

  /// Whether To tag is choosing clips. True with nothing chosen yet when
  /// **Select clips** was used (the bar then says "0 selected").
  final bool selecting;

  /// The ids of the chosen clips. Never holds a clip that is missing or no
  /// longer waiting.
  final Set<int> selected;

  @override
  bool operator ==(Object other) =>
      other is ToTagSelectionState &&
      other.selecting == selecting &&
      setEquals(other.selected, selected);

  @override
  int get hashCode => Object.hash(selecting, Object.hashAllUnordered(selected));
}

/// Choosing clips on To tag (D-98; `app.js`: `startSel`, `toggleSel`,
/// `selScene`, `clearSel`), the way the reel page chooses (`ReelSelection`,
/// D-88):
///
/// - **Only a waiting clip that is not missing can be chosen.** Before the
///   list has been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
///   the one way to be choosing with nothing chosen, and [toggleScene] may
///   leave it so (a scene's **Unselect** is not the last tap of a choice).
/// - **It follows the list.** A chosen clip that leaves To tag (a verify
///   takes it out, a scan, the tag player or a Skip tags it) is un-chosen;
///   when that empties a selection that had clips, choosing ends, and so
///   does choosing with nothing chosen once the list is empty. The ids are
///   never kept for a clip that is gone.
///
/// Auto-disposes with the screen.
@riverpod
class ToTagSelection extends _$ToTagSelection {
  @override
  ToTagSelectionState build() {
    ref.listen(toTagControllerProvider, (_, next) {
      final clips = next.value;
      if (clips != null) _prune(_liveIds(clips));
    });
    return const ToTagSelectionState();
  }

  Set<int> _liveIds(List<Clip> clips) => {
    for (final c in clips)
      if (!c.missing) c.id,
  };

  Set<int> get _live =>
      _liveIds(ref.read(toTagControllerProvider).value ?? const []);

  void _prune(Set<int> live) {
    if (state.selected.isEmpty) {
      // Choosing with nothing chosen (Select clips) ends when nothing is
      // left to choose.
      if (state.selecting && live.isEmpty) {
        state = const ToTagSelectionState();
      }
      return;
    }
    final kept = state.selected.intersection(live);
    if (kept.length == state.selected.length) return;
    state = kept.isEmpty
        ? const ToTagSelectionState()
        : ToTagSelectionState(selecting: true, selected: kept);
  }

  /// Starts choosing with nothing chosen (**Select clips**).
  void begin() {
    if (!state.selecting) state = const ToTagSelectionState(selecting: true);
  }

  /// Starts choosing with [clipId] chosen (a long press). Nothing happens for
  /// a clip that cannot be chosen.
  void start(int clipId) {
    if (!_live.contains(clipId)) return;
    state = ToTagSelectionState(selecting: true, selected: {clipId});
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
        ? const ToTagSelectionState()
        : ToTagSelectionState(selecting: true, selected: next);
  }

  /// **Select all** / **Unselect** on a scene's header: chooses every clip of
  /// [clipIds] that can be chosen, or, when they are all chosen already,
  /// un-chooses them. Choosing goes on when it leaves nothing chosen.
  void toggleScene(Iterable<int> clipIds) {
    final live = _live;
    final ids = {
      for (final id in clipIds)
        if (live.contains(id)) id,
    };
    if (ids.isEmpty) return;
    final all = state.selected.containsAll(ids);
    final next = all
        ? state.selected.difference(ids)
        : state.selected.union(ids);
    state = ToTagSelectionState(selecting: true, selected: next);
  }

  /// Ends choosing.
  void clear() {
    if (state.selecting || state.selected.isNotEmpty) {
      state = const ToTagSelectionState();
    }
  }
}
