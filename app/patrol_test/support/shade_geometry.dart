import 'dart:math' as math;
import 'dart:ui';

/// Which of the views called [candidates] (for example every "Turn off" in
/// the notification shade) is the button of the notification whose text is
/// [anchor] (TakeTray's own notification, found by its text): the one that
/// sits below the anchor's top, no further below it than [maxBelow] pixels,
/// on the same row as one of [siblings] (for example every "Keep on", the
/// button next to it). Several fit: the nearest one. None: null.
///
/// This stops a test tapping another app's "Turn off" (the phone rule: only
/// TakeTray's own notifications are ever touched). All numbers are screen
/// pixels from the native views' bounds; nothing here reads any text.
int? ownButtonIndex({
  required Rect anchor,
  required List<Rect> candidates,
  required List<Rect> siblings,
  double maxBelow = 600,
}) {
  int? best;
  var bestDistance = double.infinity;
  for (var i = 0; i < candidates.length; i++) {
    final candidate = candidates[i];
    final below = candidate.top - anchor.top;
    if (below < 0 || below > maxBelow) continue;
    // The same row: the vertical centres are closer than half the smaller
    // height.
    final row = siblings.any(
      (s) =>
          (s.center.dy - candidate.center.dy).abs() <
          math.min(s.height, candidate.height) / 2,
    );
    if (!row) continue;
    if (below < bestDistance) {
      best = i;
      bestDistance = below;
    }
  }
  return best;
}
