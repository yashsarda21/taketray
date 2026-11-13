import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/buttons.dart';
import 'package:taketray_ui/src/components/internal/dashed_border.dart';
import 'package:taketray_ui/src/components/internal/fit_height.dart';
import 'package:taketray_ui/src/components/internal/fit_or_fallback.dart';
import 'package:taketray_ui/src/components/internal/scrim.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_text_styles.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A label with an icon that covers a clip tile, such as "Skipped".
class TtClipMark {
  /// A mark showing [icon] and [label].
  const new({required this.icon, required this.label});

  /// The glyph, drawn filled.
  final IconData icon;

  /// The words; one line at normal text, wrapped between words at large text
  /// and shrunk to fit the tile as a last resort, never cut short.
  final String label;
}

/// A clip in a grid: a 3:4 thumbnail with the time it was shot (bottom left)
/// and its length (bottom right).
///
/// Badges: the number of reels the clip is in (top left, only from 2), a
/// horizontal-video mark (top right, only for a clip in fewer than 2 reels),
/// and an optional [vnLabel] mark for a clip already in the VN folder. A
/// [mark] covers the tile with a label and hides the time and length.
///
/// Giving [selected] puts the tile in selecting mode: a check circle appears
/// at the top right, and a selected tile shrinks its picture inside a
/// primary container frame. It is announced as a toggle then.
///
/// A thumbnail that fails to load shows a neutral placeholder.
/// [semanticLabel] is what a screen reader says for the whole tile (the
/// badges are not read on their own), so it should mention the time, length,
/// reel count, mark and VN folder.
class TtClipTile extends StatelessWidget {
  /// A tile showing [thumbnail], announced as [semanticLabel].
  const new({
    required this.thumbnail,
    required this.semanticLabel,
    this.timeText,
    this.durationText,
    this.reelCount = 1,
    this.horizontal = false,
    this.selected,
    this.mark,
    this.vnLabel,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  /// The picture.
  final ImageProvider thumbnail;

  /// What a screen reader says for the tile.
  final String semanticLabel;

  /// When the clip was shot, such as "9:41 AM", or null for none.
  final String? timeText;

  /// How long the clip is, such as "0:32", or null for none.
  final String? durationText;

  /// How many reels the clip is in; the layers badge shows from 2.
  final int reelCount;

  /// Whether the video is horizontal.
  final bool horizontal;

  /// Null outside selecting mode; otherwise whether this tile is selected.
  final bool? selected;

  /// A label over the whole tile, or null for none.
  final TtClipMark? mark;

  /// The text of the "already in the VN folder" mark, or null to hide it.
  final String? vnLabel;

  /// Whether taps and long presses are handled.
  final bool enabled;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Called when the tile is long pressed.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final selecting = selected != null;
    final isSelected = selected ?? false;
    final multi = reelCount >= 2;
    final showHorizontal = horizontal && !multi;
    final time = isSelected || mark != null ? null : timeText;
    final duration = isSelected || mark != null ? null : durationText;
    final vn = vnLabel;
    final tileMark = mark;

    // proto.css: .tile.sel { background: primary-container }
    final background = isSelected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      toggled: selected,
      label: semanticLabel,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: AspectRatio(
        aspectRatio: tt.sizes.clipTileAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tt.radii.m),
          child: ColoredBox(
            color: background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // proto.css: .tile .img, .tile.sel .img { scale(.86) }
                AnimatedScale(
                  scale: isSelected ? TtMetrics.clipTileSelectedScale : 1,
                  duration: tt.motion.short4,
                  curve: tt.motion.standard,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(tt.radii.m),
                    child: Image(
                      image: thumbnail,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const _Placeholder(),
                    ),
                  ),
                ),
                if (!isSelected) const _TileScrim(),
                if (multi)
                  PositionedDirectional(
                    start: TtMetrics.clipTileBadgeInset,
                    top: TtMetrics.clipTileBadgeInset,
                    child: _MultiBadge(count: reelCount),
                  ),
                if (showHorizontal)
                  const PositionedDirectional(
                    end: TtMetrics.clipTileBadgeInset,
                    top: TtMetrics.clipTileBadgeInset,
                    child: _HorizontalBadge(),
                  ),
                if (time != null || duration != null || vn != null)
                  // The VN mark sits above the time and length, and keeps its
                  // height off the bottom when they are hidden.
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: TtMetrics.clipTileTextBottom,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: TtMetrics.clipTileVnGap,
                      children: [
                        if (vn != null)
                          Padding(
                            // proto.css: .tile .vnmark { left: 5px } (no right
                            // limit: the label may run to the tile's edge).
                            padding: const EdgeInsetsDirectional.only(
                              start: TtMetrics.clipTileVnInsetStart,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _VnMark(label: vn),
                            ),
                          ),
                        if (time != null || duration != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: TtMetrics.clipTileTextInset,
                            ),
                            child: _TimeRow(time: time, duration: duration),
                          )
                        else
                          const SizedBox(height: TtMetrics.clipTileTextHeight),
                      ],
                    ),
                  ),
                if (tileMark != null) _MarkOverlay(mark: tileMark),
                if (selecting)
                  PositionedDirectional(
                    end: TtMetrics.clipTileSelectInset,
                    top: TtMetrics.clipTileSelectInset,
                    child: _SelectCircle(selected: isSelected),
                  ),
                // The ripple is drawn over the picture and the badges.
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: enabled ? onTap : null,
                      onLongPress: enabled ? onLongPress : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The neutral picture for a thumbnail that failed to load.
class _Placeholder extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Symbols.movie_rounded,
          size: tt.sizes.iconLarge,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The dark gradient over the bottom of the picture, behind the time and
/// length.
class _TileScrim extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    // proto.css: .tile .scr-b
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: TtMetrics.clipTileScrimHeightFactor,
        widthFactor: 1,
        child: Scrim(
          top: false,
          color: context.scheme.shadow.withValues(
            alpha: TtMetrics.clipTileScrimOpacity,
          ),
        ),
      ),
    );
  }
}

/// The time (start) and length (end) along the bottom of the tile.
class _TimeRow extends StatelessWidget {
  const new({required this.time, required this.duration});

  final String? time;
  final String? duration;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final time = this.time;
    final duration = this.duration;
    // proto.css: .tile .tm, .tile .du
    final style = tt.text
        .numeric(tt.text.material.bodySmall!)
        .merge(TtTextStyles.weight(TtMetrics.clipTileTextWeight))
        .copyWith(
          color: tt.colors.onMedia,
          letterSpacing: 0,
          shadows: [
            Shadow(
              color: context.scheme.shadow.withValues(
                alpha: TtMetrics.clipTileTextShadowOpacity,
              ),
              blurRadius: TtMetrics.clipTileTextShadowBlur,
              offset: const Offset(0, TtMetrics.clipTileTextShadowOffsetY),
            ),
          ],
        );
    // The two share the row in proportion to their length. At large text
    // sizes each shrinks to its share rather than being cut off.
    Widget part(String text, AlignmentGeometry alignment) => Flexible(
      flex: math.max(1, text.length),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: time == null
            ? MainAxisAlignment.end
            : MainAxisAlignment.spaceBetween,
        spacing: tt.spacing.xxs,
        children: [
          if (time != null) part(time, AlignmentDirectional.centerStart),
          if (duration != null) part(duration, AlignmentDirectional.centerEnd),
        ],
      ),
    );
  }
}

/// The dark rounded square that holds a badge on the picture.
class _BadgeBox extends StatelessWidget {
  const new({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // proto.css: .tile .multi, .tile .hz
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.tt.colors.glassOnMedia.withValues(
            alpha: TtMetrics.clipTileBadgeOpacity,
          ),
          borderRadius: BorderRadius.circular(TtMetrics.clipTileBadgeRadius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: TtMetrics.clipTileBadgeSize,
            minHeight: TtMetrics.clipTileBadgeSize,
          ),
          child: Padding(
            padding: padding,
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// Layers icon and the number of reels the clip is in.
class _MultiBadge extends StatelessWidget {
  const new({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // proto.css: .tile .multi { font: 700 11.5px/1 … }
    final style = tt.text.navLabel
        .merge(TtTextStyles.weight(TtMetrics.clipTileBadgeTextWeight))
        .copyWith(color: tt.colors.onMedia, letterSpacing: 0, height: 1);
    return _BadgeBox(
      padding: const EdgeInsetsDirectional.only(
        start: TtMetrics.clipTileMultiPaddingStart,
        end: TtMetrics.clipTileMultiPaddingEnd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: TtMetrics.clipTileMultiGap,
        children: [
          Icon(
            Symbols.layers_rounded,
            size: TtMetrics.clipTileMultiIconSize,
            color: tt.colors.onMedia,
            fill: 1,
          ),
          Text('$count', maxLines: 1, softWrap: false, style: style),
        ],
      ),
    );
  }
}

/// The mark on a horizontal video.
class _HorizontalBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => _BadgeBox(
    child: Icon(
      Symbols.crop_16_9_rounded,
      size: TtMetrics.clipTileHorizontalIconSize,
      color: context.tt.colors.onMedia,
    ),
  );
}

/// "Already in the VN folder": a small inverse pill above the time.
class _VnMark extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .pill.vn, with ui.js's height 20, font 11 and padding 0 6 0 4
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(tt.radii.s),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: TtMetrics.clipTileVnHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: TtMetrics.clipTileVnPaddingStart,
              end: TtMetrics.clipTileVnPaddingEnd,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: tt.spacing.xxs,
                children: [
                  Icon(
                    Symbols.folder_copy_rounded,
                    size: TtMetrics.clipTileVnIconSize,
                    color: scheme.onInverseSurface,
                  ),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.text.material.labelMedium!.copyWith(
                        fontSize: TtMetrics.clipTileVnFontSize,
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The label over a marked tile: the picture dims and the label sits at the
/// bottom.
class _MarkOverlay extends StatelessWidget {
  const new({required this.mark});

  final TtClipMark mark;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .tile .mark, .tile .mark > span
    final style = tt.text.navLabel
        .merge(TtTextStyles.weight(TtMetrics.clipTileBadgeTextWeight))
        .copyWith(color: scheme.onInverseSurface, letterSpacing: 0);
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: scheme.surface.withValues(
            alpha: TtMetrics.clipTileMarkScrimOpacity,
          ),
          child: Padding(
            padding: const EdgeInsets.all(TtMetrics.clipTileMarkInset),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(
                    TtMetrics.clipTileMarkRadius,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TtMetrics.clipTileMarkPaddingHorizontal,
                    vertical: TtMetrics.clipTileMarkPaddingVertical,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: TtMetrics.clipTileMarkGap,
                    children: [
                      Icon(
                        mark.icon,
                        size: TtMetrics.clipTileMarkIconSize,
                        color: scheme.onInverseSurface,
                        fill: 1,
                      ),
                      // The label wraps between words over as many lines as it
                      // takes (at 200 % text "In this reel" and "In To tag"
                      // must not both end up as "In t…"), and is shrunk, never
                      // cut, when it still does not fit the tile.
                      Flexible(
                        child: FitHeight(child: Text(mark.label, style: style)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round check in the corner while selecting.
class _SelectCircle extends StatelessWidget {
  const new({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .tile .selc, .tile.sel .selc
    return IgnorePointer(
      child: SizedBox.square(
        key: const ValueKey('tt-clip-select'),
        dimension: TtMetrics.clipTileSelectSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? scheme.primary
                : scheme.shadow.withValues(
                    alpha: TtMetrics.clipTileSelectFillOpacity,
                  ),
            border: Border.all(
              color: selected ? scheme.primary : tt.colors.onMedia,
              width: TtMetrics.clipTileSelectBorder,
            ),
          ),
          child: selected
              ? OverflowBox(
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: TtMetrics.clipTileSelectTickSize,
                  maxHeight: TtMetrics.clipTileSelectTickSize,
                  child: Icon(
                    Symbols.check_rounded,
                    size: TtMetrics.clipTileSelectTickSize,
                    weight: TtMetrics.clipTileSelectTickWeight,
                    color: scheme.onPrimary,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// A clip that is gone from the phone: a grey dashed tile with a camera-off
/// icon, [label], and, when [removeLabel] is given, a small Remove button.
///
/// The tile keeps its 3:4 shape. The label wraps over as many lines as it
/// needs, between words only. From a text scale of 1.5, or when the word
/// [removeLabel] does not fit the tile on one line, the Remove button is just
/// an icon (named by [removeLabel]), so it is never cut short. As
/// a last resort, when the content is still too big for the tile it shrinks to
/// fit, so nothing is cut off and the tile never overflows.
class TtMissingClipTile extends StatelessWidget {
  /// A missing-clip tile saying [label].
  const new({required this.label, this.removeLabel, this.onRemove, super.key});

  /// What the tile says, such as "Missing from phone".
  final String label;

  /// The text of the Remove button, or null for no button.
  final String? removeLabel;

  /// Called when Remove is tapped.
  final VoidCallback? onRemove;

  /// How tall a tile [width] dp wide must be to show its content at its real
  /// size: the icon, [label] over as many lines as it takes at the phone's
  /// text scale, and the Remove button when [removeLabel] is given.
  ///
  /// The tile keeps a 3:4 shape when the cell is that tall, and shrinks its
  /// content when the cell is shorter (see the class comment). A grid whose
  /// text may be large gives a row with a missing tile at least this height
  /// (`mainAxisExtent`), and the larger of the two is the row height. At the
  /// normal text size this is less than the 3:4 height, so nothing grows.
  ///
  /// Measured the way the tile lays itself out: the same paddings, gaps and
  /// text style, the label wrapped at the tile's inner width and scaled by
  /// `MediaQuery.textScalerOf`, and the button 48 dp high (its tap target)
  /// or, at normal text, as high as its label needs.
  static double heightFor(
    BuildContext context, {
    required double width,
    required String label,
    String? removeLabel,
  }) {
    final tt = context.tt;
    final scaler = MediaQuery.textScalerOf(context);
    final text = TextPainter(
      text: TextSpan(
        text: label,
        // The style the label is drawn in (the colour does not change a
        // measure).
        style: tt.text.material.labelMedium,
      ),
      textAlign: TextAlign.center,
      textDirection: Directionality.of(context),
      textScaler: scaler,
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: width - 2 * TtMetrics.clipTileMissingPaddingHorizontal);
    final labelHeight = text.height;
    text.dispose();

    var height = 2 * tt.spacing.xs + TtMetrics.clipTileMissingIconSize;
    height += tt.spacing.xxs + labelHeight;
    if (removeLabel != null) {
      final button = scaler.scale(1) >= TtMetrics.largeTextScale
          ? tt.sizes.touchTarget
          : math.max(
              tt.sizes.touchTarget,
              scaler.scale(TtMetrics.buttonMinHeightSmall),
            );
      height += tt.spacing.xxs + TtMetrics.clipTileMissingButtonGap + button;
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final removeLabel = this.removeLabel;
    final iconOnly =
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    final iconButton = removeLabel == null
        ? null
        : Tooltip(
            message: removeLabel,
            excludeFromSemantics: true,
            child: TtIconButton(
              icon: Symbols.playlist_remove_rounded,
              semanticLabel: removeLabel,
              onPressed: onRemove,
            ),
          );
    // proto.css: .tile.miss
    return AspectRatio(
      aspectRatio: tt.sizes.clipTileAspect,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: scheme.outline,
          radius: tt.radii.m,
          width: TtMetrics.clipTileMissingBorder,
          dash: TtMetrics.clipTileMissingDashLength,
          gap: TtMetrics.clipTileMissingDashGap,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tt.radii.m),
          child: ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: TtMetrics.clipTileMissingPaddingHorizontal,
                vertical: tt.spacing.xs,
              ),
              // The content is as wide as the tile and as tall as it needs,
              // and is scaled down, never up, to fit the tile's height.
              child: FitHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: tt.spacing.xxs,
                  children: [
                    Icon(
                      Symbols.videocam_off_rounded,
                      size: TtMetrics.clipTileMissingIconSize,
                      color: scheme.onSurfaceVariant,
                    ),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: tt.text.material.labelMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (removeLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: TtMetrics.clipTileMissingButtonGap,
                        ),
                        // The word "Remove" does not fit a narrow tile at
                        // large text without breaking in the middle, nor a
                        // long translation of it at normal text without an
                        // ellipsis, so the button is just its icon, still
                        // named "Remove", from the large-text scale and
                        // whenever the word does not fit.
                        child: iconOnly
                            ? iconButton!
                            : FitOrFallback(
                                preferred: TtButton(
                                  label: removeLabel,
                                  kind: TtButtonKind.tonal,
                                  size: TtButtonSize.small,
                                  onPressed: onRemove,
                                ),
                                fallback: iconButton!,
                              ),
                      ),
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
