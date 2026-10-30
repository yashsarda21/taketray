import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/buttons.dart';
import 'package:taketray_ui/src/components/rec_dot.dart';
import 'package:taketray_ui/src/components/selection.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The Shooting mode card at the top of Home.
///
/// Off, it is a quiet hairline card: a videocam tile, a [title] and
/// [subtitle], and a switch. On, it is a black "media hero": the [backdrop]
/// (the latest clip) at 62 % under a brand tint, the tile with a pulsing
/// record dot, the same texts in white, the inverted switch, a white
/// [cameraLabel] button, and below them up to two [rows] and the optional
/// [toTagStrip] (use [TtCardRow]).
///
/// A [backdrop] that fails to load leaves the plain black card.
class TtShootingModeCard extends StatelessWidget {
  /// A card for shooting mode being [on] or off.
  const new({
    required this.on,
    required this.title,
    required this.subtitle,
    required this.switchSemanticLabel,
    required this.onChanged,
    this.backdrop,
    this.cameraLabel,
    this.onOpenCamera,
    this.rows = const [],
    this.toTagStrip,
    super.key,
  }) : assert(rows.length <= 2, 'The card has room for two rows');

  /// Whether shooting mode is on.
  final bool on;

  /// The headline, such as "Shooting mode" or "Shooting mode on".
  final String title;

  /// The line under the title (any length; it wraps).
  final String subtitle;

  /// What a screen reader says for the switch.
  final String switchSemanticLabel;

  /// Called with the new value when the switch is tapped.
  final ValueChanged<bool> onChanged;

  /// The picture behind the "on" card, or null for plain black.
  final ImageProvider? backdrop;

  /// The camera button's text; with [on], null hides the button.
  final String? cameraLabel;

  /// Called when the camera button is tapped.
  final VoidCallback? onOpenCamera;

  /// Up to two [TtCardRow]s above the to-tag strip (on only), top to bottom:
  /// References, then Add earlier videos. Each is a frosted band with a
  /// hairline above it.
  final List<TtCardRow> rows;

  /// A [TtCardRow] with a trailing text, for clips waiting to be tagged (on
  /// only).
  final Widget? toTagStrip;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final corners = BorderRadius.circular(tt.radii.xxl);
    final label = cameraLabel;
    final strip = toTagStrip;

    final top = Padding(
      // proto.css: .shoot .top { padding: 16px 12px 16px 16px }
      padding: EdgeInsetsDirectional.only(
        start: tt.spacing.m,
        end: tt.spacing.s,
        top: tt.spacing.m,
        bottom: tt.spacing.m,
      ),
      child: Row(
        spacing: TtMetrics.shootingTopGap,
        children: [
          _IconTile(on: on),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: TtMetrics.shootingSubtitleGap,
              children: [
                Text(
                  title,
                  style: on
                      ? tt.text.shootTitle.copyWith(color: tt.colors.onMedia)
                      : tt.text.material.titleMedium,
                ),
                Text(
                  subtitle,
                  style: tt.text.material.bodyMedium!.copyWith(
                    color: on
                        ? tt.colors.onMedia.withValues(
                            alpha: TtMetrics.shootingSubtitleOpacity,
                          )
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TtSwitch(
            value: on,
            onChanged: onChanged,
            semanticLabel: switchSemanticLabel,
            inverted: on,
          ),
        ],
      ),
    );

    if (!on) {
      // proto.css: .shoot, tt-style.css: .shoot:not(.on) { inset hairline }
      return DecoratedBox(
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: corners,
            side: BorderSide(color: tt.colors.hairline),
          ),
        ),
        child: ClipRRect(borderRadius: corners, child: top),
      );
    }

    // tt-style.css: .style-tt .shoot.on
    final tint = scheme.brightness == Brightness.light
        ? scheme.primary
        : scheme.primaryContainer;
    final picture = backdrop;
    return ClipRRect(
      borderRadius: corners,
      child: ColoredBox(
        color: tt.colors.videoBackground,
        child: Stack(
          children: [
            if (picture != null)
              Positioned.fill(
                child: Opacity(
                  opacity: TtMetrics.shootingBackdropOpacity,
                  child: Image(
                    image: picture,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _TintPainter(tint: tint, black: scheme.shadow),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                top,
                if (label != null)
                  Padding(
                    // proto.css: .shoot .acts { padding: 0 16px 16px }
                    padding: EdgeInsetsDirectional.only(
                      start: tt.spacing.m,
                      end: tt.spacing.m,
                      bottom: tt.spacing.m,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _CameraButton(
                        label: label,
                        onPressed: onOpenCamera,
                      ),
                    ),
                  ),
                ...rows,
                ?strip,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The rounded icon tile with the videocam; on the "on" card it is frosted
/// white and carries the record dot.
class _IconTile extends StatelessWidget {
  const new({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final corners = BorderRadius.circular(TtMetrics.shootingIconRadius);
    final glyph = Icon(
      Symbols.videocam_rounded,
      fill: 1,
      color: on ? tt.colors.onMedia : scheme.onPrimaryContainer,
    );
    final tile = on
        ? ClipRRect(
            borderRadius: corners,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: TtMetrics.shootingIconBlur,
                sigmaY: TtMetrics.shootingIconBlur,
              ),
              child: ColoredBox(
                color: tt.colors.onMedia.withValues(
                  alpha: TtMetrics.shootingIconFillOpacity,
                ),
                child: Center(child: glyph),
              ),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: corners,
            ),
            child: Center(child: glyph),
          );
    return SizedBox.square(
      dimension: TtMetrics.shootingIconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: tile),
          if (on)
            PositionedDirectional(
              end: TtMetrics.shootingRecDotInset,
              top: TtMetrics.shootingRecDotInset,
              child: TtRecDot(outline: tt.colors.videoBackground),
            ),
        ],
      ),
    );
  }
}

/// The white "Open camera" button of the "on" card.
class _CameraButton extends StatelessWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = context.tt;
    // tt-style.css: .style-tt .shoot.on .camb { background: #fff; color: #111 }
    // A filled button takes primary and onPrimary, so give it white and black.
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: tt.colors.onMedia,
          onPrimary: tt.colors.videoBackground,
        ),
      ),
      child: TtButton(
        label: label,
        icon: Symbols.videocam_rounded,
        onPressed: onPressed,
      ),
    );
  }
}

/// The brand tint over the backdrop: a CSS `linear-gradient(160deg, …)`,
/// whose line is as long as the box needs rather than corner to corner.
class _TintPainter extends CustomPainter {
  const new({required this.tint, required this.black});

  final Color tint;
  final Color black;

  @override
  void paint(Canvas canvas, Size size) {
    const angle = TtMetrics.shootingTintAngle * math.pi / 180;
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final length =
        size.width * math.sin(angle).abs() +
        size.height * math.cos(angle).abs();
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        center - direction * (length / 2),
        center + direction * (length / 2),
        [
          tint.withValues(alpha: TtMetrics.shootingTintStartOpacity),
          tint.withValues(alpha: TtMetrics.shootingTintMiddleOpacity),
          black.withValues(alpha: TtMetrics.shootingTintEndOpacity),
        ],
        const [0, TtMetrics.shootingTintMiddleStop, 1],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_TintPainter oldDelegate) =>
      oldDelegate.tint != tint || oldDelegate.black != black;
}

/// A full-width row at the bottom of the "on" Shooting mode card.
///
/// Two looks, chosen by [trailingText]:
/// - without it, a references row: a frosted dark band with white text, an
///   optional [subtitle] and a chevron;
/// - with it, a to-tag strip: a tertiary container band, the text and an
///   arrow after the title.
///
/// The whole row is one button named [semanticLabel], or the title,
/// subtitle and trailing text joined by commas.
class TtCardRow extends StatelessWidget {
  /// A row showing [icon] and [title] that calls [onPressed] when tapped.
  const new({
    required this.icon,
    required this.title,
    required this.onPressed,
    this.subtitle,
    this.trailingText,
    this.semanticLabel,
    super.key,
  });

  /// The glyph before the title (drawn filled on a strip).
  final IconData icon;

  /// The headline; one line.
  final String title;

  /// A line under the title, or null for none.
  final String? subtitle;

  /// A word before the arrow, such as "Tag now"; giving it makes the row a
  /// to-tag strip.
  final String? trailingText;

  /// What a screen reader says instead of the texts, or null to read them.
  final String? semanticLabel;

  /// Called when the row is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final trailing = trailingText;
    final subtitle = this.subtitle;
    final strip = trailing != null;

    // proto.css: .shoot .strip / .refrow, tt-style.css: .shoot.on .refrow
    final color = strip ? tt.colors.onWaitingContainer : tt.colors.onMedia;
    final text = tt.text.material;
    final body = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: strip
            ? TtMetrics.cardStripMinHeight
            : TtMetrics.cardRowMinHeight,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: tt.spacing.m,
          end: tt.spacing.s,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: color, size: tt.sizes.icon),
          child: Row(
            spacing: strip ? TtMetrics.cardStripGap : TtMetrics.cardRowGap,
            children: [
              Icon(icon, fill: strip ? 1 : 0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall!.copyWith(color: color),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall!.copyWith(
                          color: color.withValues(
                            alpha: TtMetrics.cardRowSubtitleOpacity,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge!.copyWith(color: color),
                ),
              Icon(
                strip
                    ? Symbols.arrow_forward_rounded
                    : Symbols.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );

    final Widget band;
    if (strip) {
      band = Material(
        color: tt.colors.waitingContainer,
        child: InkWell(onTap: onPressed, child: body),
      );
    } else {
      band = ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: TtMetrics.cardRowBlur,
            sigmaY: TtMetrics.cardRowBlur,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.shadow.withValues(
                alpha: TtMetrics.cardRowFillOpacity,
              ),
              border: Border(
                top: BorderSide(
                  color: tt.colors.onMedia.withValues(
                    alpha: TtMetrics.cardRowBorderOpacity,
                  ),
                ),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onPressed, child: body),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      label: semanticLabel ?? [title, ?subtitle, ?trailing].join(', '),
      onTap: onPressed,
      child: band,
    );
  }
}
