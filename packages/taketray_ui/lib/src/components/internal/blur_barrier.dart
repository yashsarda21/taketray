import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';

/// Blurs what is behind [barrier] by [TtMetrics.scrimBlur], growing with the
/// route's [animation] so the blur fades in and out with the dimming.
///
/// Used by the sheet and dialog routes (`buildModalBarrier`) for the
/// prototype's `.scrim { backdrop-filter: blur(3px) }`.
Widget ttBlurredBarrier({
  required Animation<double> animation,
  required Widget barrier,
}) => AnimatedBuilder(
  animation: animation,
  child: barrier,
  builder: (context, child) {
    final sigma = TtMetrics.scrimBlur * animation.value;
    if (sigma <= 0) return child!;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  },
);
