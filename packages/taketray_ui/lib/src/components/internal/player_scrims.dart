import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';

/// Paints [gradientFor] over the whole of its box, behind the child.
///
/// The two scrims of the full-screen tag player (D-179) are painters rather
/// than gradients with fixed stops because both have a length in dp in their
/// stops (26 dp, 24 dp), which a `LinearGradient` can only say as a share of
/// the height; so each one works its stops out from the height it is drawn
/// at. A painter takes no touches ([hitTest] is false) and is not announced
/// (no semantics builder), which is what a scrim must be.
abstract class _ScrimPainter extends CustomPainter {
  const new(this.color);

  /// The colour of the scrim at full strength; the stops set its alpha.
  final Color color;

  /// The gradient for a box [height] dp high, from its top to its bottom.
  LinearGradient gradientFor(double height);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = gradientFor(size.height).createShader(rect),
    );
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant _ScrimPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The scrim behind the reel dock: clear at the top, black at 74 % from
/// 26 dp down, 90 % from half way to the bottom.
///
/// The 26 dp stop is a share of the height, never past half way, so a dock
/// shorter than 52 dp still has stops that run forwards (an empty list of
/// chips is about 90 dp, but the clamp keeps a short one defined).
// player2.css:31: .p2-dock { background: linear-gradient(transparent 0,
// rgba(0,0,0,.74) 26px, rgba(0,0,0,.9) 50%) }
class DockScrimPainter extends _ScrimPainter {
  /// The dock's scrim in [color] (the player's black).
  const new(super.color);

  @override
  LinearGradient gradientFor(double height) {
    final mid = height <= 0
        ? TtMetrics.reelDockScrimEndStop
        : math.min(
            TtMetrics.reelDockScrimMidAt / height,
            TtMetrics.reelDockScrimEndStop,
          );
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: TtMetrics.reelDockScrimMidOpacity),
        color.withValues(alpha: TtMetrics.reelDockScrimEndOpacity),
        color.withValues(alpha: TtMetrics.reelDockScrimEndOpacity),
      ],
      stops: [0, mid, TtMetrics.reelDockScrimEndStop, 1],
    );
  }
}

/// The scrim behind the tag player's top bar: black at 78 % at the top, 70 %
/// until 24 dp above the bottom, then clear.
// player2.css:21: .p2-top { background: linear-gradient(rgba(0,0,0,.78) 0,
// rgba(0,0,0,.7) calc(100% - 24px), transparent 100%) }
class TopScrimPainter extends _ScrimPainter {
  /// The top bar's scrim in [color] (the player's black).
  const new(super.color);

  @override
  LinearGradient gradientFor(double height) {
    final hold = height <= 0
        ? 0.0
        : ((height - TtMetrics.playerTopScrimFade) / height).clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: TtMetrics.playerTopScrimStartOpacity),
        color.withValues(alpha: TtMetrics.playerTopScrimHoldOpacity),
        color.withValues(alpha: 0),
      ],
      stops: [0, hold, 1],
    );
  }
}
