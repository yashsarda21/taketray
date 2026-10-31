import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/internal/equal_columns.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A small chip on the clip viewer naming a reel the clip is in: a
/// video-library icon and the reel's [name], white on a 16 % white fill.
///
/// For the dark, black viewer (put it under a `TtVideoSurface`); its colours
/// are the video ones, whatever the app theme is. Not interactive. At least
/// 28 dp high, 8 dp corners; the name is one line with an ellipsis, and the
/// chip grows taller at large text. A screen reader reads the [name].
class TtReelTag extends StatelessWidget {
  /// A tag for the reel called [name].
  const new({required this.name, super.key});

  /// The reel's name.
  final String name;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // proto.css: .viewer .inreels .tagc
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: name,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tt.colors.onVideo.withValues(
            alpha: TtMetrics.reelTagFillOpacity,
          ),
          borderRadius: BorderRadius.circular(tt.radii.s),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TtMetrics.reelTagHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TtMetrics.reelTagPaddingHorizontal,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: tt.spacing.xxs,
              children: [
                Icon(
                  Symbols.video_library_rounded,
                  size: TtMetrics.reelTagIconSize,
                  color: tt.colors.onVideo,
                ),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.text.material.labelMedium!.copyWith(
                      color: tt.colors.onVideo,
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

/// The "In" row of the clip viewer: a [label] such as "In" followed by one
/// [TtReelTag] for each of [names], wrapping onto more lines when they do not
/// fit.
///
/// 16 dp from the screen's sides, 6 dp between items. The label is white at
/// 80 %.
class TtReelTagRow extends StatelessWidget {
  /// A row of tags for [names], introduced by [label].
  const new({required this.label, required this.names, super.key});

  /// The word before the tags, such as "In".
  final String label;

  /// The names of the reels the clip is in.
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // proto.css: .viewer .inreels
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
      child: Wrap(
        spacing: TtMetrics.reelTagGap,
        runSpacing: TtMetrics.reelTagGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            label,
            style: tt.text.material.bodySmall!.copyWith(
              color: tt.colors.onVideo.withValues(
                alpha: TtMetrics.reelTagLabelOpacity,
              ),
            ),
          ),
          for (final name in names) TtReelTag(name: name),
        ],
      ),
    );
  }
}

/// One action of a [TtViewerActions] bar.
@immutable
class TtViewerAction {
  /// An action that shows [icon] over [label] and calls [onPressed].
  const new({required this.icon, required this.label, required this.onPressed});

  /// The glyph.
  final IconData icon;

  /// The word under the glyph, such as "Move"; also what a screen reader
  /// says.
  final String label;

  /// Called when the action is tapped.
  final VoidCallback onPressed;
}

/// The row of actions under a clip in the viewer: three or four equal
/// columns, each an icon over a label.
///
/// For the dark, black viewer (put it under a `TtVideoSurface`). Each action
/// is a button at least 64 dp high and as wide as its column (a 48 dp target
/// at every text size), with 16 dp corners and white content; a label that
/// does not fit wraps, and at large text the bar grows taller rather than cut
/// anything. When even the widest single word does not fit its column, every
/// action shrinks by the same amount (`EqualColumns`), so no label is smaller
/// than another. The bar is 8 dp from the screen's sides.
class TtViewerActions extends StatelessWidget {
  /// A bar of [actions], three or four of them.
  const new({required this.actions, super.key})
    : assert(
        actions.length >= TtMetrics.viewerActionsMin &&
            actions.length <= TtMetrics.viewerActionsMax,
        'The viewer bar holds 3 or 4 actions',
      );

  /// The actions, first to last (3 or 4).
  final List<TtViewerAction> actions;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // proto.css: .viewer .vacts
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tt.spacing.xs),
      child: EqualColumns(
        minHeight: TtMetrics.viewerActionMinHeight,
        children: [for (final action in actions) _ActionButton(action: action)],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const new({required this.action});

  final TtViewerAction action;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final radius = BorderRadius.circular(tt.radii.l);
    // proto.css: .viewer .vacts button
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      label: action.label,
      onTap: action.onPressed,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onPressed,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.all(tt.spacing.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: tt.spacing.xxs,
              children: [
                Icon(
                  action.icon,
                  size: tt.sizes.icon,
                  color: tt.colors.onVideo,
                ),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: tt.text.material.labelMedium!.copyWith(
                    color: tt.colors.onVideo,
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
