import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A blurred pane of glass: what is behind it, blurred by [blur], under a
/// plain [fill], clipped to [corners]; [child] sits on it.
///
/// The build order is the point (D-173): `ClipRRect`, then `BackdropFilter`,
/// then a `ColoredBox` as the first thing the filter paints, then a
/// transparent `Material` for the ink, then [child]. A `Material` that is
/// itself the filter's first child (`Material(color: fill)`) lost the blur on
/// the S24 (the reel cover's status pill was sharp); the same values over a
/// `ColoredBox` blurred. An `InkWell` in [child] draws its ripple on the
/// transparent `Material`, over the fill.
///
/// For glass that is not a plain rounded rectangle (the nav pill's hairline
/// border, a card row's top border) keep the same order: the fill is a
/// `ColoredBox` or a coloured `DecoratedBox`, and the ink goes in a transparent
/// `Material` inside it.
class TtGlassFill extends StatelessWidget {
  /// Glass of [fill] over a blur of [blur], with rounded [corners].
  const new({
    required this.corners,
    required this.blur,
    required this.fill,
    required this.child,
    super.key,
  });

  /// The shape the glass is clipped to.
  final BorderRadius corners;

  /// Standard deviation of the background blur.
  final double blur;

  /// The colour laid over the blurred backdrop (usually translucent).
  final Color fill;

  /// What is drawn on the glass; may hold an `InkWell`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: corners,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: ColoredBox(
          color: fill,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
