import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/internal/dashed_border.dart';
import 'package:taketray_ui/src/components/internal/glass_fill.dart';
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

/// Where a [TtReelChip] or [TtNewReelChip] sits.
enum TtReelChipStyle {
  /// On a panel surface (the tag panel of D-97): the theme's colours.
  surface,

  /// On the playing clip in the full-screen tag player (D-171, D-178): dark
  /// glass that blurs the clip by 14, with white text. The picked and done
  /// fills are the same as on a surface.
  onVideo,
}

/// A reel in the tag panel: tap it to put the current clip in that reel.
///
/// A small cover, the reel's [name] over its [countText], and in
/// [multiSelect] mode a check mark at the end. At least 56 dp high (58 with
/// the border), and a 164 dp wide cell in the panel's two columns. The name
/// and count are one line each with an ellipsis; at large text sizes the chip
/// grows taller and the cover stays centred, so nothing overlaps. From a text
/// scale of `TtMetrics.reelDockSingleColumnTextScale` the panel gives a chip
/// the whole row, and the name may take two lines.
///
/// Without a [cover], or when it fails to load, the cover shows a film icon.
/// [TtReelChipState.done] shows a check in place of the cover.
///
/// The whole chip is one control named [semanticLabel]. In [multiSelect] mode
/// it is a checkbox, checked while [state] is [TtReelChipState.picked];
/// otherwise a button. [onLongPress] is for the secondary action (the
/// prototype's "chipLong").
///
/// With [style] [TtReelChipStyle.onVideo] the chip is glass over the clip
/// (D-178): an idle fill of `TtColors.dockChipGlass` blurred by 14, a white
/// name and a count at 78 %, at least 52 dp high with a 30 x 40 cover. Picked
/// and done keep their primary-container and primary fills, with the count at
/// 85 %; the picked border is painted over the glass. The rest is the same:
/// semantics, the long press and the two-line name at large text.
class TtReelChip extends StatelessWidget {
  /// A chip for the reel [name] with [countText] under it.
  const new({
    required this.name,
    required this.countText,
    required this.semanticLabel,
    this.cover,
    this.state = TtReelChipState.idle,
    this.multiSelect = false,
    this.style = TtReelChipStyle.surface,
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

  /// Whether the chip sits on a panel or on the playing clip.
  final TtReelChipStyle style;

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

    final onVideo = style == TtReelChipStyle.onVideo;

    // proto.css: .rchip, .rchip.pick, .rchip.done; player2.css:44-49:
    // .rchip.dk, .rchip.dk.pick, .rchip.dk.done
    final (fill, content, edge, countColor) = switch (state) {
      TtReelChipState.idle when onVideo => (
        tt.colors.dockChipGlass,
        tt.colors.onVideo,
        scheme.primary.withValues(alpha: 0),
        tt.colors.onVideo.withValues(
          alpha: TtMetrics.reelChipOnVideoCountOpacity,
        ),
      ),
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
          alpha: onVideo
              ? TtMetrics.reelChipOnVideoStateCountOpacity
              : TtMetrics.reelChipPickedCountOpacity,
        ),
      ),
      TtReelChipState.done => (
        scheme.primary,
        scheme.onPrimary,
        scheme.primary.withValues(alpha: 0),
        scheme.onPrimary.withValues(
          alpha: onVideo
              ? TtMetrics.reelChipOnVideoStateCountOpacity
              : TtMetrics.reelChipDoneCountOpacity,
        ),
      ),
    };

    final text = tt.text.material;
    // At large text sizes the panel shows one chip per row, so there is room
    // for a second line of the name (D-47).
    final large =
        MediaQuery.textScalerOf(context).scale(1) >=
        TtMetrics.reelDockSingleColumnTextScale;
    const inset = TtMetrics.reelChipPaddingStart + TtMetrics.reelChipBorder;
    final radius = BorderRadius.circular(TtMetrics.reelChipRadius);

    final row = Padding(
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
          _Cover(
            cover: cover,
            done: done,
            width: onVideo
                ? TtMetrics.reelChipOnVideoCoverWidth
                : TtMetrics.reelChipCoverWidth,
            height: onVideo
                ? TtMetrics.reelChipOnVideoCoverHeight
                : TtMetrics.reelChipCoverHeight,
          ),
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
    );

    final Widget body;
    if (onVideo) {
      // Glass over the clip: the fill is a ColoredBox the BackdropFilter
      // paints first (D-173), and the picked border is painted over it.
      body = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          // 1 dp, `TtMetrics.reelChipBorder`: the default width.
          border: Border.all(color: edge),
        ),
        child: TtGlassFill(
          corners: radius,
          blur: TtMetrics.reelChipOnVideoBlur,
          fill: fill,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TtMetrics.reelChipOnVideoMinHeight,
              ),
              child: row,
            ),
          ),
        ),
      );
    } else {
      body = Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: edge),
        ),
        clipBehavior: Clip.antiAlias,
        animationDuration: tt.motion.short3,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tt.sizes.reelChip),
            child: row,
          ),
        ),
      );
    }

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
        child: body,
      ),
    );
  }
}

/// The cover (34 x 44, or 30 x 40 on video): the picture, a film icon, or
/// the check of a chip that has just been tagged.
class _Cover extends StatelessWidget {
  const new({
    required this.cover,
    required this.done,
    required this.width,
    required this.height,
  });

  final ImageProvider? cover;
  final bool done;
  final double width;
  final double height;

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
      width: width,
      height: height,
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
                    width: width,
                    height: height,
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
/// With [style] [TtReelChipStyle.onVideo] the chip is glass over the clip
/// (D-178): `TtColors.dockNewChipGlass` blurred by 14, a 1.5 dp dashed border
/// in `TtColors.dockNewChipBorder`, a white [title] and a [subtitle] at 78 %,
/// at least 52 dp high with the 30 x 40 cover (still the secondary container
/// and the plus).
///
/// One button named [semanticLabel], or [title] when that is null.
class TtNewReelChip extends StatelessWidget {
  /// A chip titled [title], with [subtitle] under it when given.
  const new({
    required this.title,
    this.subtitle,
    this.semanticLabel,
    this.fullWidth = false,
    this.style = TtReelChipStyle.surface,
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

  /// Whether the chip sits on a panel or on the playing clip.
  final TtReelChipStyle style;

  /// Called when the chip is tapped; null makes it inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final second = subtitle;
    final onVideo = style == TtReelChipStyle.onVideo;
    final large =
        MediaQuery.textScalerOf(context).scale(1) >=
        TtMetrics.reelDockSingleColumnTextScale;
    const inset = TtMetrics.reelChipPaddingStart + TtMetrics.reelChipBorder;
    final radius = BorderRadius.circular(TtMetrics.reelChipRadius);

    // proto.css: .rchip.new, .rchip.new .cv; player2.css:50: .rchip.new.dk
    final titleColor = onVideo ? tt.colors.onVideo : scheme.primary;
    final subtitleColor = onVideo
        ? tt.colors.onVideo.withValues(
            alpha: TtMetrics.reelChipOnVideoCountOpacity,
          )
        : scheme.onSurfaceVariant;
    final labels = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: large ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelLarge!.copyWith(color: titleColor),
        ),
        if (second != null)
          Text(
            second,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(color: subtitleColor),
          ),
      ],
    );

    final row = Padding(
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
            width: onVideo
                ? TtMetrics.reelChipOnVideoCoverWidth
                : TtMetrics.reelChipCoverWidth,
            height: onVideo
                ? TtMetrics.reelChipOnVideoCoverHeight
                : TtMetrics.reelChipCoverHeight,
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
          if (fullWidth) Flexible(child: labels) else Expanded(child: labels),
        ],
      ),
    );

    final Widget body;
    if (onVideo) {
      body = TtGlassFill(
        corners: radius,
        blur: TtMetrics.reelChipOnVideoBlur,
        fill: tt.colors.dockNewChipGlass,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TtMetrics.reelChipOnVideoMinHeight,
            ),
            child: row,
          ),
        ),
      );
    } else {
      body = Material(
        color: scheme.surface.withValues(alpha: 0),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tt.sizes.reelChip),
            child: row,
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: onTap != null,
      label: semanticLabel ?? title,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: onVideo ? tt.colors.dockNewChipBorder : scheme.outline,
          radius: TtMetrics.reelChipRadius,
          width: TtMetrics.newReelChipBorder,
          dash: TtMetrics.newReelChipDash,
          gap: TtMetrics.newReelChipDashGap,
        ),
        child: body,
      ),
    );
  }
}
