import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The share of [clip] that `BoxFit.cover` in [area] cuts off, from 0 (none)
/// to below 1: the handoff's sum (D-171), with
/// `s = max(aw / cw, ah / ch)` and `crop = 1 − min(aw / (cw · s), ah / (ch · s))`.
///
/// 0 when either size is empty, negative or not a number, or the area is
/// unbounded: nothing is known to be cut.
double coverCrop({required Size area, required Size clip}) {
  if (!_known(area) || !_known(clip)) return 0;
  final s = math.max(area.width / clip.width, area.height / clip.height);
  return 1 -
      math.min(area.width / (clip.width * s), area.height / (clip.height * s));
}

/// How the tag player's stage shows [clip] in [area] (D-180): `BoxFit.cover`,
/// as in Instagram Reels, unless covering cuts more than
/// `TtMetrics.tagStageMaxCoverCrop` of it; then `BoxFit.contain`, whole on
/// black. Exactly the limit still covers (a 9:16 clip on a 360 × 800 screen
/// loses exactly 20 %): the comparison allows for rounding. An empty or
/// unknown size covers.
BoxFit stageFit({required Size area, required Size clip}) =>
    coverCrop(area: area, clip: clip) >
        TtMetrics.tagStageMaxCoverCrop + _rounding
    ? BoxFit.contain
    : BoxFit.cover;

/// What floating point may add to a crop that is exactly the limit.
const double _rounding = 1e-9;

/// A size with a finite, positive width and height.
bool _known(Size size) =>
    size.width.isFinite &&
    size.height.isFinite &&
    size.width > 0 &&
    size.height > 0;
