import 'package:flutter/widgets.dart';
import 'package:taketray_ui/src/components/reel_chip.dart';

/// Lays [chips] out two to a row, or one per row at [large] text. A
/// full-width `TtNewReelChip` ends the row before it and takes its own.
///
/// A lone chip at the end of a row keeps its half width. Shared by the tag
/// panel and the reel dock (D-179).
List<Widget> chipGridRows(
  List<Widget> chips, {
  required bool large,
  required double gap,
}) {
  if (large) return chips;
  final rows = <Widget>[];
  Widget? waiting;
  Widget pair(Widget first, Widget? second) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: gap,
    children: [
      Expanded(child: first),
      Expanded(child: second ?? const SizedBox.shrink()),
    ],
  );
  for (final chip in chips) {
    if (chip is TtNewReelChip && chip.fullWidth) {
      if (waiting != null) rows.add(pair(waiting, null));
      waiting = null;
      rows.add(chip);
    } else if (waiting == null) {
      waiting = chip;
    } else {
      rows.add(pair(waiting, chip));
      waiting = null;
    }
  }
  if (waiting != null) rows.add(pair(waiting, null));
  return rows;
}
