import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';

/// Blurs what is behind [barrier] by [TtMetrics.scrimBlur], the same from the
/// route's first frame to the last frame of its close.
///
/// Used by the dialog and sheet routes (`buildModalBarrier`, around
/// `super.buildModalBarrier()`) for the prototype's
/// `.scrim { backdrop-filter: blur(3px) }`. Only the dim of [barrier] fades
/// (Flutter's `AnimatedModalBarrier`, on the `Curves.ease` ramp): a blur that
/// grew with the route's animation was drawn as "only darker" on the S24 when
/// it met the TakeTray dialog, and a steady one was drawn soft (D-172).
Widget ttBlurredBarrier({required Widget barrier}) => BackdropFilter(
  filter: ui.ImageFilter.blur(
    sigmaX: TtMetrics.scrimBlur,
    sigmaY: TtMetrics.scrimBlur,
  ),
  child: barrier,
);
