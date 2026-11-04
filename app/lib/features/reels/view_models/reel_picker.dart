import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_summary.dart';

/// The two sections of the reel picker (`sheets.picker`, D-88).
class PickerSections {
  const new({required this.collecting, required this.other});

  /// Reels still Collecting.
  final List<ReelSummary> collecting;

  /// Ready to edit and Published reels.
  final List<ReelSummary> other;
}

/// Splits [summaries] for the picker: the reel [excludeReelId] (the one the
/// clips are in) is left out, then Collecting reels come first and the rest
/// follow, each in the order given. Tag mode (clips in no reel yet) passes
/// null and leaves nothing out (D-98).
PickerSections pickerSections(
  List<ReelSummary> summaries, {
  required int? excludeReelId,
}) {
  final shown = [
    for (final s in summaries)
      if (s.reel.id != excludeReelId) s,
  ];
  return PickerSections(
    collecting: [
      for (final s in shown)
        if (s.reel.status == ReelStatus.collecting) s,
    ],
    other: [
      for (final s in shown)
        if (s.reel.status != ReelStatus.collecting) s,
    ],
  );
}

/// The picks after tapping reel [id]: with [multi] (add) it joins or leaves
/// the picks, in tap order; without (move) it becomes the only pick, and
/// tapping it again keeps it (a radio button).
List<int> togglePick(List<int> picked, int id, {required bool multi}) {
  if (!multi) return [id];
  return picked.contains(id)
      ? [
          for (final p in picked)
            if (p != id) p,
        ]
      : [...picked, id];
}

/// The picks after the inline form created reel [id]: it is picked, and for
/// move it is the only pick.
List<int> pickedAfterCreate(List<int> picked, int id, {required bool multi}) =>
    multi ? (picked.contains(id) ? [...picked] : [...picked, id]) : [id];
