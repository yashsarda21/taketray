import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/buttons.dart';
import 'package:taketray_ui/src/components/internal/dashed_border.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A reference to a video to recreate: a striped art tile with the source's
/// app icon, a title and subtitle, and an "Open" mark. An optional more
/// button follows.
///
/// TakeTray never fetches the referenced video, so this is a designed card,
/// not a thumbnail. The title clamps to 2 lines and the subtitle to 1.
///
/// The main part is one button named [openSemanticLabel] (it should say what
/// opens, and where). The more button, shown only when [onMore] is given, is
/// a separate 48 dp button named [moreSemanticLabel].
class TtReferenceCard extends StatelessWidget {
  /// A card for the reference [title] that calls [onOpen] when tapped.
  const new({
    required this.title,
    required this.subtitle,
    required this.sourceIcon,
    required this.openLabel,
    required this.openSemanticLabel,
    required this.onOpen,
    this.moreSemanticLabel,
    this.onMore,
    super.key,
  }) : assert(
         onMore == null || moreSemanticLabel != null,
         'The more button needs a semantics label',
       );

  /// The reference's name, or its link when it has none; two lines at most.
  final String title;

  /// The source and the link, such as "Instagram · instagram.com/reel/abc";
  /// one line.
  final String subtitle;

  /// The source's app icon, 18 dp. It hangs off the bottom end corner of the
  /// art, so it should carry its own ring in the card's colour.
  final Widget sourceIcon;

  /// The word after the open icon, such as "Open".
  final String openLabel;

  /// What a screen reader says for the main button.
  final String openSemanticLabel;

  /// Called when the main part is tapped.
  final VoidCallback onOpen;

  /// What a screen reader says for the more button.
  final String? moreSemanticLabel;

  /// Called when the more button is tapped; null hides the button.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final more = onMore;
    // proto.css: .refcard, tt-style.css: .style-tt .refcard
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tt.radii.xl),
        side: BorderSide(color: tt.colors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              enabled: true,
              label: openSemanticLabel,
              onTap: onOpen,
              child: InkWell(
                onTap: onOpen,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: TtMetrics.referenceCardMinHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: TtMetrics.referenceCardPaddingStart,
                      end: TtMetrics.referenceCardPaddingEnd,
                      top: tt.spacing.xs,
                      bottom: tt.spacing.xs,
                    ),
                    child: Row(
                      spacing: tt.spacing.s,
                      children: [
                        _Art(sourceIcon: sourceIcon),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: TtMetrics.referenceSubtitleGap,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.text.material.titleSmall,
                              ),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.text.material.bodySmall!.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: TtMetrics.referenceOpenMaxWidth,
                          ),
                          child: _OpenMark(label: openLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (more != null)
            TtIconButton(
              icon: Symbols.more_vert_rounded,
              semanticLabel: moreSemanticLabel!,
              onPressed: more,
            ),
        ],
      ),
    );
  }
}

/// "Open" with the open-in-new icon, in the primary colour.
class _OpenMark extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final color = context.scheme.primary;
    // proto.css: .ref-open
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tt.spacing.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: tt.spacing.xxs,
        children: [
          Icon(
            Symbols.open_in_new_rounded,
            size: tt.sizes.iconSmall,
            color: color,
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.text.material.labelLarge!.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference's art: diagonal secondary-container stripes with a play icon
/// and the source's app icon on the bottom end corner.
class _Art extends StatelessWidget {
  const new({required this.sourceIcon});

  final Widget sourceIcon;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .ref-art, .ref-src
    return SizedBox(
      width: TtMetrics.referenceArtWidth,
      height: TtMetrics.referenceArtHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tt.radii.s),
              child: CustomPaint(
                painter: _StripesPainter(
                  light: scheme.secondaryContainer,
                  dark: Color.lerp(
                    scheme.surfaceContainerLow,
                    scheme.secondaryContainer,
                    TtMetrics.referenceArtStripeMix,
                  )!,
                ),
                child: Center(
                  child: Icon(
                    Symbols.play_arrow_rounded,
                    fill: 1,
                    size: TtMetrics.referenceArtIconSize,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: -TtMetrics.referenceSourceOffset,
            bottom: -TtMetrics.referenceSourceOffset,
            child: sourceIcon,
          ),
        ],
      ),
    );
  }
}

/// Paints `repeating-linear-gradient(135deg, a 0 5px, b 5px 10px)`.
class _StripesPainter extends CustomPainter {
  const new({required this.light, required this.dark});

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    const stripe = TtMetrics.referenceArtStripe;
    const angle = TtMetrics.referenceArtStripeAngle * math.pi / 180;
    // CSS angles run clockwise from "up".
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final length =
        size.width * math.sin(angle).abs() +
        size.height * math.cos(angle).abs();
    final start = size.center(Offset.zero) - direction * (length / 2);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        start,
        start + direction * (stripe * 2),
        [light, light, dark, dark],
        const [0, 0.5, 0.5, 1],
        TileMode.repeated,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) =>
      oldDelegate.light != light || oldDelegate.dark != dark;
}

/// The "Add reference" tile: a dashed outline around an add-link icon, a
/// title and subtitle, and a plus.
///
/// One button named by [semanticLabel], which should say [title] and
/// [subtitle] together.
class TtAddReferenceTile extends StatelessWidget {
  /// A tile saying [title] and [subtitle] that calls [onPressed] when tapped.
  const new({
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  /// The action, such as "Add reference".
  final String title;

  /// A hint under the title.
  final String subtitle;

  /// What a screen reader says for the tile.
  final String semanticLabel;

  /// Called when the tile is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final corners = BorderRadius.circular(tt.radii.xl);
    // proto.css: .ref-add, tt-style.css: .style-tt .ref-add
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      label: semanticLabel,
      onTap: onPressed,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: scheme.outlineVariant,
          radius: tt.radii.xl,
          width: TtMetrics.addReferenceBorder,
          dash: TtMetrics.addReferenceDash,
          gap: TtMetrics.addReferenceDashGap,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: corners,
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TtMetrics.addReferenceMinHeight,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: tt.spacing.m,
                  end: TtMetrics.addReferencePaddingEnd,
                  top: tt.spacing.xs,
                  bottom: tt.spacing.xs,
                ),
                child: Row(
                  spacing: tt.spacing.s,
                  children: [
                    Icon(Symbols.add_link_rounded, color: scheme.primary),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, style: tt.text.material.titleSmall),
                          Text(
                            subtitle,
                            style: tt.text.material.bodySmall!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Symbols.add_rounded, color: scheme.onSurface),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
