import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The progress bar along the top of the tag player: one segment per clip.
///
/// The segment at [current] is white, a segment whose index is in [done] is
/// the accent colour (the clip is tagged or skipped), and the rest are dim.
/// With more than 40 clips single segments would be too thin to see, so the
/// bar collapses to three: the clips before [current] (done), [current]
/// itself, and the clips after it.
///
/// Drawn 3 dp high with 16 dp at each side; hidden from screen readers,
/// because the header already says where the user is.
class TtSegmentBar extends StatelessWidget {
  /// A bar for [total] clips with the clip at index [current] showing.
  const new({
    required this.total,
    required this.current,
    required this.done,
    super.key,
  });

  /// How many clips there are.
  final int total;

  /// The index of the clip being tagged.
  final int current;

  /// The indexes of clips already dealt with (used up to 40 clips).
  final Set<int> done;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .player .pbar i, i.done, i.cur
    final waiting = tt.colors.onVideo.withValues(
      alpha: TtMetrics.segmentBarTrackOpacity,
    );
    final doneColor = scheme.tertiaryContainer;
    final currentColor = tt.colors.onVideo;

    // (flex, colour) for each segment that has any width.
    final segments = <(int, Color)>[];
    if (total <= TtMetrics.segmentBarMaxClips) {
      for (var i = 0; i < total; i++) {
        segments.add((
          1,
          i == current
              ? currentColor
              : done.contains(i)
              ? doneColor
              : waiting,
        ));
      }
    } else {
      // screens.js: the clips before, the current one, the clips after.
      final at = current.clamp(0, total - 1);
      final before = at;
      final after = total - at - 1;
      if (before > 0) segments.add((before, doneColor));
      segments.add((1, currentColor));
      if (after > 0) segments.add((after, waiting));
    }

    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
        child: SizedBox(
          height: TtMetrics.segmentBarHeight,
          child: Row(
            spacing: TtMetrics.segmentBarGap,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (flex, color) in segments)
                Expanded(
                  flex: flex,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(
                        TtMetrics.segmentBarRadius,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row above the video in the tag player: a [leading] control, a centred
/// [title] over an optional [subtitle], and a [trailing] control.
///
/// At least 56 dp high with 4 dp at the sides. The title and subtitle are
/// one line each with an ellipsis; at large text sizes the header grows
/// rather than clip. The text is a live region, so a screen reader says the
/// new position each time the clip changes. Without a [trailing] control the
/// title stays centred.
class TtPlayerHeader extends StatelessWidget {
  /// A header showing [title] and [subtitle] between two controls.
  const new({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// The control at the start, such as a close button.
  final Widget leading;

  /// The main line, such as "5 of 12".
  final String title;

  /// A smaller line under the title, such as the scene.
  final String? subtitle;

  /// The control at the end, such as a mute button; none keeps the title
  /// centred.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final sub = subtitle;
    // proto.css: .player .ptop, .ptop .mid b / span
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: TtMetrics.playerHeaderHeight,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tt.spacing.xxs),
        child: Row(
          spacing: tt.spacing.xxs,
          children: [
            leading,
            Expanded(
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tt.text.material.titleSmall!.copyWith(
                        color: tt.colors.onVideo,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: tt.text.material.bodySmall!.copyWith(
                          color: tt.colors.onVideoVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            trailing ?? SizedBox.square(dimension: tt.sizes.touchTarget),
          ],
        ),
      ),
    );
  }
}

/// Which way a [TtStageArrow] points.
enum TtArrowSide {
  /// Back to the previous clip; points to the start.
  previous,

  /// On to the next clip; points to the end.
  next,
}

/// A round arrow at the side of the video that moves to the previous or next
/// clip.
///
/// A 48 dp disc of translucent black with a white chevron. A null
/// [onPressed] disables it and dims it to 30 %. It has no position of its
/// own: the player places it at the edge of the stage. The chevron icons
/// mirror themselves in right-to-left text.
class TtStageArrow extends StatelessWidget {
  /// An arrow on [side] that a screen reader calls [semanticLabel].
  const new({
    required this.side,
    required this.semanticLabel,
    this.onPressed,
    super.key,
  });

  /// Which way it points.
  final TtArrowSide side;

  /// What a screen reader says, such as "Previous clip".
  final String semanticLabel;

  /// Called when the arrow is tapped; null disables it.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final enabled = onPressed != null;
    // proto.css: .stage .arrow, .arrow[disabled]
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : TtMetrics.stageArrowDisabledOpacity,
        child: SizedBox.square(
          dimension: tt.sizes.touchTarget,
          child: Material(
            color: tt.colors.videoBackground.withValues(
              alpha: TtMetrics.stageArrowFillOpacity,
            ),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: Icon(
                  side == TtArrowSide.previous
                      ? Symbols.chevron_left_rounded
                      : Symbols.chevron_right_rounded,
                  size: tt.sizes.icon,
                  color: tt.colors.onVideo,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The seek bar under the video: the time so far, a track with a thumb, and
/// the length of the clip.
///
/// [progress] runs from 0.0 to 1.0 and is clamped (NaN counts as 0).
/// [onSeek] gets the fraction from a tap or a drag anywhere on the track;
/// without it the bar only shows. The whole bar is 48 dp high so it is easy
/// to hit, though the track itself is 4 dp, or 6 dp with [large]. [large]
/// also gives the thumb a halo: it is for long clips, where a drag skims.
/// [hint] floats a small label above the track, such as "Drag to skim".
///
/// A screen reader finds a slider named by the two times, which it can step
/// forward and back.
class TtScrubBar extends StatelessWidget {
  /// A bar at [progress] showing [positionText] and [durationText].
  const new({
    required this.progress,
    required this.positionText,
    required this.durationText,
    this.large = false,
    this.hint,
    this.onSeek,
    super.key,
  });

  /// How far through the clip, from 0.0 to 1.0.
  final double progress;

  /// The time so far, such as "1:12".
  final String positionText;

  /// The length of the clip, such as "4:32".
  final String durationText;

  /// Whether the track and thumb are larger, for long clips.
  final bool large;

  /// A label floating above the track, or null for none.
  final String? hint;

  /// Called with the fraction (0.0 to 1.0) the user taps or drags to.
  final ValueChanged<double>? onSeek;

  double get _clamped => progress.isNaN ? 0 : progress.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final label = hint;
    final seek = onSeek;
    final value = _clamped;
    // proto.css: .scrub { font: 600 12px/1 }, .scrub .hint
    final textStyle = tt.text
        .numeric(tt.text.material.labelMedium!)
        .copyWith(
          color: tt.colors.onVideo.withValues(
            alpha: TtMetrics.scrubTextOpacity,
          ),
          fontWeight: FontWeight.w600,
          fontVariations: const [
            FontVariation('wght', TtMetrics.scrubTextWeight),
          ],
          letterSpacing: 0,
          height: 1,
        );

    void step(double by) => seek?.call((value + by).clamp(0.0, 1.0));

    return Semantics(
      container: true,
      excludeSemantics: true,
      slider: true,
      label: '$positionText / $durationText',
      hint: label,
      onIncrease: seek == null ? null : () => step(TtMetrics.scrubSemanticStep),
      onDecrease: seek == null
          ? null
          : () => step(-TtMetrics.scrubSemanticStep),
      child: RepaintBoundary(
        child: SizedBox(
          height: tt.sizes.touchTarget,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
                  child: Row(
                    spacing: TtMetrics.scrubGap,
                    children: [
                      Text(positionText, maxLines: 1, style: textStyle),
                      Expanded(
                        child: _Track(
                          progress: value,
                          large: large,
                          onSeek: seek,
                        ),
                      ),
                      Text(durationText, maxLines: 1, style: textStyle),
                    ],
                  ),
                ),
              ),
              if (label != null)
                Positioned(
                  left: tt.spacing.gutter,
                  right: tt.spacing.gutter,
                  bottom: tt.sizes.touchTarget / 2 + TtMetrics.scrubHintLift,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tt.colors.videoBackground.withValues(
                                alpha: TtMetrics.scrubHintOpacity,
                              ),
                              borderRadius: BorderRadius.circular(
                                TtMetrics.scrubHintRadius,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: tt.spacing.xs,
                                vertical: tt.spacing.xxs,
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textStyle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The track, fill and thumb of the scrub bar, and the gestures on them.
class _Track extends StatelessWidget {
  const new({
    required this.progress,
    required this.large,
    required this.onSeek,
  });

  final double progress;
  final bool large;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final trackHeight = large
        ? TtMetrics.scrubTrackHeightLarge
        : TtMetrics.scrubTrackHeight;
    final thumbSize = large
        ? TtMetrics.scrubThumbSizeLarge
        : TtMetrics.scrubThumbSize;
    final white = tt.colors.onVideo;
    final radius = BorderRadius.circular(TtMetrics.scrubTrackRadius);
    final seek = onSeek;

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        void seekTo(Offset at) {
          if (seek == null || width <= 0) return;
          final fraction = (at.dx / width).clamp(0.0, 1.0);
          seek(rtl ? 1 - fraction : fraction);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: seek == null ? null : (d) => seekTo(d.localPosition),
          onHorizontalDragStart: seek == null
              ? null
              : (d) => seekTo(d.localPosition),
          onHorizontalDragUpdate: seek == null
              ? null
              : (d) => seekTo(d.localPosition),
          child: SizedBox(
            height: box.maxHeight,
            child: SizedBox(
              height: box.maxHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    key: const ValueKey('tt-scrub-track'),
                    width: double.infinity,
                    height: trackHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: white.withValues(
                          alpha: TtMetrics.scrubTrackOpacity,
                        ),
                        borderRadius: radius,
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      key: const ValueKey('tt-scrub-fill'),
                      widthFactor: progress,
                      child: SizedBox(
                        height: trackHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: radius,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: width * progress - thumbSize / 2,
                    top: (box.maxHeight - thumbSize) / 2,
                    child: SizedBox.square(
                      key: const ValueKey('tt-scrub-thumb'),
                      dimension: thumbSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: white,
                          shape: BoxShape.circle,
                          boxShadow: large
                              ? [
                                  BoxShadow(
                                    color: white.withValues(
                                      alpha: TtMetrics.scrubThumbHaloOpacity,
                                    ),
                                    spreadRadius: TtMetrics.scrubThumbHalo,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
