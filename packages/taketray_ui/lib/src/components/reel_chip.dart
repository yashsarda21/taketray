import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
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
/// grows taller and the cover stays centred, so nothing overlaps.
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
                            maxLines: 1,
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
