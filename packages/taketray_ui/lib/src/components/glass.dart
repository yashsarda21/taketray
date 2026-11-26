import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/outside_shadow.dart';
import 'package:taketray_ui/src/components/internal/saturation.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A frosted-glass panel for floating chrome: the nav pill, toasts, sheets.
///
/// Blurs what is behind it by [blur] (and saturates the blurred colours by
/// [saturation], when that is not 1), fills with the theme's glass colour (or
/// [tint]), and draws a hairline border and, unless [shadow] is false, a soft
/// drop shadow. The shadow is painted only outside the panel, as CSS
/// `box-shadow` is, so it does not show through the translucent fill (D-175).
/// Put it over content or media; over a flat surface it is just a tinted
/// panel.
class TtGlass extends StatelessWidget {
  /// A glass panel with rounded corners of [radius] around [child].
  const new({
    required this.child,
    required this.radius,
    this.tint,
    this.blur = TtMetrics.glassBlur,
    this.shadow = true,
    this.saturation = 1,
    super.key,
  });

  /// What is drawn on the glass.
  final Widget child;

  /// Corner radius of the panel.
  final double radius;

  /// Fill colour, or null for the theme's glass colour.
  final Color? tint;

  /// Standard deviation of the background blur.
  final double blur;

  /// Whether the panel casts a drop shadow.
  final bool shadow;

  /// How much the blurred backdrop is saturated, after the blur (CSS
  /// `saturate()`); 1 leaves its colours as they are and the filter is only
  /// the blur.
  final double saturation;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final corners = BorderRadius.circular(radius);
    final blurFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
    final glass = ClipRRect(
      borderRadius: corners,
      child: BackdropFilter(
        // CSS applies `blur()` then `saturate()`: the blur is the inner filter.
        filter: saturation == 1
            ? blurFilter
            : ui.ImageFilter.compose(
                outer: ui.ColorFilter.matrix(ttSaturationMatrix(saturation)),
                inner: blurFilter,
              ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? tt.colors.glass,
            borderRadius: corners,
            border: Border.all(color: tt.colors.hairline),
          ),
          child: child,
        ),
      ),
    );
    if (!shadow) return glass;
    return CustomPaint(
      painter: OutsideShadowPainter(
        borderRadius: corners,
        shadows: [
          // tt-style.css: .style-tt .navbar { box-shadow: 0 10px 30px -8px … }
          BoxShadow(
            color: context.scheme.shadow.withValues(
              alpha: TtMetrics.glassShadowOpacity,
            ),
            blurRadius: TtMetrics.glassShadowBlur,
            offset: const Offset(0, TtMetrics.glassShadowOffsetY),
            spreadRadius: TtMetrics.glassShadowSpread,
          ),
        ],
      ),
      child: glass,
    );
  }
}
