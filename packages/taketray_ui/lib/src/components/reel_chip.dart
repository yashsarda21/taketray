import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/internal/dashed_border.dart';
import 'package:taketray_ui/src/components/selection.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// What a [TtReelChip] looks like.
enum TtReelChipState {
  /// Not chosen.
  idle,

  /// Chosen in multi-select: primary container with a primary border.
  picked,

  /// The clip has just been added to this reel: primary fill, with a check
  /// in place of the cover.
  done,
}

/// A reel in the tag panel: tap it to put the current clip in that reel.
///
/// A small cover, the reel's [name] over its [countText], and in
/// [multiSelect] mode a check mark at the end. At least 56 dp high (58 with
/// the border), and a 164 dp wide cell in the panel's two columns. The name
/// and count are one line each with an ellipsis; at large text sizes the chip
/// grows taller and the cover stays centred, so nothing overlaps. From a text
/// scale of `TtMetrics.tagPanelSingleColumnTextScale` the panel gives a chip
/// the whole row, and the name may take two lines.
///
/// Without a [cover], or when it fails to load, the cover shows a film icon.
/// [TtReelChipState.done] shows a check in place of the cover.
///
/// The whole chip is one control named [semanticLabel]. In [multiSelect] mode
/// it is a checkbox, checked while [state] is [TtReelChipState.picked];
/// otherwise a button. [onLongPress] is for the secondary action (the
/// prototype's "chipLong").
class TtReelChip extends StatelessWidget {
  /// A chip for the reel [name] with [countText] under it.
  const new({
    required this.name,
    required this.countText,
    required this.semanticLabel,
    this.cover,
    this.state = TtReelChipState.idle,
    this.multiSelect = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  /// The reel's name; one line.
  final String name;

  /// The line under the name, such as "12 clips".
  final String countText;

  /// What a screen reader says for the chip.
  final String semanticLabel;

  /// The cover picture, or null for the film icon.
  final ImageProvider? cover;

  /// Whether the chip is idle, picked or just done.
  final TtReelChipState state;

  /// Whether the chip is one of several choices: it shows a check mark and
  /// is announced as a checkbox.
  final bool multiSelect;

  /// Called when the chip is tapped.
  final VoidCallback? onTap;

  /// Called when the chip is pressed and held.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final picked = state == TtReelChipState.picked;
    final done = state == TtReelChipState.done;

    // proto.css: .rchip, .rchip.pick, .rchip.done
    final (fill, content, edge, countColor) = switch (state) {
      TtReelChipState.idle => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        scheme.primary.withValues(alpha: 0),
        scheme.onSurfaceVariant,
      ),
      TtReelChipState.picked => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primary,
        scheme.onPrimaryContainer.withValues(
          alpha: TtMetrics.reelChipPickedCountOpacity,
        ),
      ),
      TtReelChipState.done => (
        scheme.primary,
        scheme.onPrimary,
        scheme.primary.withValues(alpha: 0),
        scheme.onPrimary.withValues(alpha: TtMetrics.reelChipDoneCountOpacity),
      ),
    };

    final text = tt.text.material;
    // At large text sizes the panel shows one chip per row, so there is room
    // for a second line of the name (D-47).
    final large =
        MediaQuery.textScalerOf(context).scale(1) >=
        TtMetrics.tagPanelSingleColumnTextScale;
    const inset = TtMetrics.reelChipPaddingStart + TtMetrics.reelChipBorder;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TtMetrics.reelChipRadius),
      side: BorderSide(color: edge),
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: multiSelect ? null : true,
      checked: multiSelect ? picked : null,
      enabled: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: done ? TtMetrics.reelChipDoneScale : 1,
        duration: tt.motion.short3,
        curve: tt.motion.standard,
        child: Material(
          color: fill,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          animationDuration: tt.motion.short3,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tt.sizes.reelChip),
              child: Padding(
                // The border is part of the chip's box, so it is added to the
                // padding.
                padding: const EdgeInsetsDirectional.fromSTEB(
                  inset,
                  inset,
                  TtMetrics.reelChipPaddingEnd + TtMetrics.reelChipBorder,
                  inset,
                ),
                child: Row(
                  spacing: TtMetrics.reelChipGap,
                  children: [
                    _Cover(cover: cover, done: done),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: large ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge!.copyWith(color: content),
                          ),
                          Text(
                            countText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall!.copyWith(color: countColor),
                          ),
                        ],
                      ),
                    ),
                    if (multiSelect && !done) TtCheckMark(checked: picked),
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

/// The 34 x 44 cover: the picture, a film icon, or the check of a chip that
/// has just been tagged.
class _Cover extends StatelessWidget {
  const new({required this.cover, required this.done});

  final ImageProvider? cover;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final picture = cover;
    // proto.css: .rchip .cv, .rchip.done .cv
    final film = Icon(
      Symbols.movie_rounded,
      size: TtMetrics.reelChipCoverIconSize,
      color: scheme.onSurfaceVariant,
    );
    return SizedBox(
      key: const ValueKey('tt-chip-cover'),
      width: TtMetrics.reelChipCoverWidth,
      height: TtMetrics.reelChipCoverHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TtMetrics.reelChipCoverRadius),
        child: ColoredBox(
          color: done ? scheme.onPrimary : scheme.surfaceContainerHigh,
          child: Center(
            child: done
                ? Icon(
                    Symbols.check_rounded,
                    size: TtMetrics.reelChipDoneIconSize,
                    weight: TtMetrics.reelChipDoneIconWeight,
                    color: scheme.primary,
                  )
                : picture == null
                ? film
                : Image(
                    image: picture,
                    width: TtMetrics.reelChipCoverWidth,
                    height: TtMetrics.reelChipCoverHeight,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) => film,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The dashed "New reel" chip in the tag panel: tap it to make a reel and put
/// the current clip in it.
///
/// Drawn like a [TtReelChip] without a fill: the same size, padding and 34 x
/// 44 cover (a plus on the secondary container), a 1.5 dp dashed outline in
/// the outline colour, and the [title] in the primary colour over the smaller
/// [subtitle]. It is as tall as a reel chip (58 dp at 1x), so the two line up
/// in a row; the outline is painted over the same 1 dp inset, which is half a
/// dp less than the prototype's 1.5 dp border and does not move the cover.
///
/// With [fullWidth] it is the one chip of the "no reels yet" panel: the panel
/// gives it a whole row (see `TtTagPanel`) and the cover and title sit in the
/// middle of it. Leave the [subtitle] out there, as the prototype does. At
/// large text the title may take two lines, as a reel chip's name does.
///
/// One button named [semanticLabel], or [title] when that is null.
class TtNewReelChip extends StatelessWidget {
  /// A chip titled [title], with [subtitle] under it when given.
  const new({
    required this.title,
    this.subtitle,
    this.semanticLabel,
    this.fullWidth = false,
    this.onTap,
    super.key,
  });

  /// The first line, such as "New reel".
  final String title;

  /// The smaller line under it, such as "Add this clip to it"; none when null.
  final String? subtitle;

  /// What a screen reader says, or null to say [title].
  final String? semanticLabel;

  /// Whether this is the only chip of the panel: it takes a whole row and
  /// its content is centred.
  final bool fullWidth;

  /// Called when the chip is tapped; null makes it inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final second = subtitle;
    final large =
        MediaQuery.textScalerOf(context).scale(1) >=
        TtMetrics.tagPanelSingleColumnTextScale;
    const inset = TtMetrics.reelChipPaddingStart + TtMetrics.reelChipBorder;
    final radius = BorderRadius.circular(TtMetrics.reelChipRadius);

    // proto.css: .rchip.new, .rchip.new .cv
    final labels = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: large ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelLarge!.copyWith(color: scheme.primary),
        ),
        if (second != null)
          Text(
            second,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: onTap != null,
      label: semanticLabel ?? title,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: scheme.outline,
          radius: TtMetrics.reelChipRadius,
          width: TtMetrics.newReelChipBorder,
          dash: TtMetrics.newReelChipDash,
          gap: TtMetrics.newReelChipDashGap,
        ),
        child: Material(
          color: scheme.surface.withValues(alpha: 0),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tt.sizes.reelChip),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  inset,
                  inset,
                  TtMetrics.reelChipPaddingEnd + TtMetrics.reelChipBorder,
                  inset,
                ),
                child: Row(
                  mainAxisAlignment: fullWidth
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  spacing: TtMetrics.reelChipGap,
                  children: [
                    SizedBox(
                      key: const ValueKey('tt-chip-cover'),
                      width: TtMetrics.reelChipCoverWidth,
                      height: TtMetrics.reelChipCoverHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          TtMetrics.reelChipCoverRadius,
                        ),
                        child: ColoredBox(
                          color: scheme.secondaryContainer,
                          child: Icon(
                            Symbols.add_rounded,
                            size: TtMetrics.newReelChipIconSize,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                    if (fullWidth)
                      Flexible(child: labels)
                    else
                      Expanded(child: labels),
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
