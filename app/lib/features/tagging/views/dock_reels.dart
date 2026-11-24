import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_summary.dart';

/// How many Collecting reels the tag player's dock shows (D-181).
const int dockCollectingReels = 3;

/// What the dock shows, from the reels in Home's order (newest first).
///
/// - `grid`: the reels in the dock's grid, in that order;
/// - `newReel`: whether New reel follows them;
/// - `allReels`: whether the dock offers **All reels**, the sheet with every
///   reel;
/// - `pickSeveral`: whether it offers **Pick several**.
typedef DockReels = ({
  List<ReelSummary> grid,
  bool newReel,
  bool allReels,
  bool pickSeveral,
});

/// The full-screen tag player's dock (D-181, the handoff's "Dock",
/// `player2.js` `full()`), from [ordered], the reels in Home's order (newest
/// first):
///
/// - the grid is the first [dockCollectingReels] Collecting reels; in Pick
///   several ([multi]) it is followed by every other reel in [picked] (picked
///   from All reels), in [ordered]'s order, each once. A picked id that is no
///   reel any more is left out;
/// - New reel is in the dock unless picking (it is in All reels then);
/// - All reels is offered when more than three reels are Collecting, or any
///   reel is Ready or Published: when a reel is not in the dock;
/// - Pick several is offered with two reels or more.
DockReels dockReels(
  List<ReelSummary> ordered, {
  required bool multi,
  required List<int> picked,
}) {
  final collecting = [
    for (final s in ordered)
      if (s.reel.status == ReelStatus.collecting) s,
  ];
  final shown = collecting.take(dockCollectingReels).toList();
  final inGrid = {for (final s in shown) s.reel.id};
  final pickedIds = picked.toSet();
  return (
    grid: [
      ...shown,
      if (multi)
        for (final s in ordered)
          if (pickedIds.contains(s.reel.id) && !inGrid.contains(s.reel.id)) s,
    ],
    newReel: !multi,
    allReels:
        collecting.length > dockCollectingReels ||
        collecting.length < ordered.length,
    pickSeveral: ordered.length >= 2,
  );
}
