import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A frosted-glass panel for floating chrome: the nav pill, toasts, sheets.
///
/// Blurs what is behind it by [blur], fills with the theme's glass colour (or
/// [tint]), and draws a hairline border and, unless [shadow] is false, a soft
/// drop shadow. Put it over content or media; over a flat surface it is just
/// a tinted panel.
class TtGlass extends StatelessWidget {
  /// A glass panel with rounded corners of [radius] around [child].
  const new({
    required this.child,
    required this.radius,
    this.tint,
    this.blur = TtMetrics.glassBlur,
    this.shadow = true,
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

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final corners = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corners,
        // tt-style.css: .style-tt .navbar { box-shadow: 0 10px 30px -8px … }
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: context.scheme.shadow.withValues(
                    alpha: TtMetrics.glassShadowOpacity,
                  ),
                  blurRadius: TtMetrics.glassShadowBlur,
                  offset: const Offset(0, TtMetrics.glassShadowOffsetY),
                  spreadRadius: TtMetrics.glassShadowSpread,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: corners,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint ?? tt.colors.glass,
              borderRadius: corners,
              border: Border.all(color: tt.colors.hairline),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A small dark-glass badge on media: an [icon] and optional [text], as in
/// the status and reference marks on a reel cover.
class TtGlassPill extends StatelessWidget {
  /// A pill showing [icon] and, when given, [text].
  const new({required this.icon, this.iconColor, this.text, super.key});

  /// The glyph, drawn filled.
  final IconData icon;

  /// Colour of the glyph, or null for white.
  final Color? iconColor;

  /// Text after the icon, or null for an icon-only pill.
  final String? text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final label = text;
    return ClipRRect(
      borderRadius: BorderRadius.circular(tt.radii.s),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: TtMetrics.glassPillBlur,
          sigmaY: TtMetrics.glassPillBlur,
        ),
        child: ColoredBox(
          color: tt.colors.glassOnMedia,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TtMetrics.glassPillHeight,
            ),
            child: Padding(
              // proto.css: .pill { padding: 0 8px 0 6px }, 6 when icon-only.
              padding: EdgeInsetsDirectional.only(
                start: TtMetrics.glassPillPaddingStart,
                end: label == null
                    ? TtMetrics.glassPillPaddingStart
                    : tt.spacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: TtMetrics.glassPillIconSize,
                    color: iconColor ?? tt.colors.onMedia,
                    fill: 1,
                  ),
                  if (label != null) ...[
                    SizedBox(width: tt.spacing.xxs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.text
                            .numeric(tt.text.material.labelMedium!)
                            .copyWith(color: tt.colors.onMedia),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
