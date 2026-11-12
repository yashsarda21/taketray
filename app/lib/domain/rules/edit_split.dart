/// A reel's clips while it is being edited, in two parts (D-119).
class EditSplit<T> {
  const EditSplit({required this.newClips, required this.inEdit});

  /// "New since you started editing": not sent and no copy in the folder.
  final List<T> newClips;

  /// "In your edit": sent to the editor, or with a copy in the folder.
  final List<T> inEdit;
}

/// Splits [clips] (in the order given, which both parts keep) by what the
/// editor already has. [sentIds] are clips sent to CapCut or Edits;
/// [liveCopyIds] are clips whose copy still exists in the folder. A copy
/// that is gone is not in [liveCopyIds], so a copied clip that was never
/// sent is new again. Ids in the sets that are not in [clips] are ignored.
EditSplit<T> splitForEditing<T>(
  List<T> clips,
  int Function(T) idOf, {
  required Set<int> sentIds,
  required Set<int> liveCopyIds,
}) {
  final newClips = <T>[];
  final inEdit = <T>[];
  for (final clip in clips) {
    final id = idOf(clip);
    (sentIds.contains(id) || liveCopyIds.contains(id) ? inEdit : newClips).add(
      clip,
    );
  }
  return EditSplit(newClips: newClips, inEdit: inEdit);
}

/// What the add-later picker shows for a clip (owner decision 7, D-118).
enum AddPick {
  /// Neither sent nor copied: pre-ticked.
  fresh,

  /// Sent before but no copy in the folder: selectable, ticking copies it.
  sentNotCopied,

  /// A live copy is in the folder: "In the folder", nothing to copy.
  inFolder,
}

/// The [AddPick] of each of [liveClipIds], in the order given. A live copy
/// wins over sent.
Map<int, AddPick> addPicks(
  List<int> liveClipIds, {
  required Set<int> sentIds,
  required Set<int> liveCopyIds,
}) => {
  for (final id in liveClipIds)
    id: liveCopyIds.contains(id)
        ? AddPick.inFolder
        : sentIds.contains(id)
        ? AddPick.sentNotCopied
        : AddPick.fresh,
};
