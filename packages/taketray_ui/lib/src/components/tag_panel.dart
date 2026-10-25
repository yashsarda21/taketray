import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The panel at the bottom of the tag player: a [title] row, a two-column
/// grid of [chips], and an optional [footer].
///
/// A glass panel (surface container at 92 %, blurred) with a 28 dp radius at
/// the top, a highlight along its top edge, and 12 dp of padding (26 at the
/// bottom). It is at most 340 dp high; with more chips than fit, the grid
/// scrolls and the header and footer stay put. The title is announced as a
/// heading. The panel takes the width it is given; each chip gets half of it
/// less the padding and the 8 dp gap (164 dp at 360 dp).
///
/// [headerAction] sits at the end of the header, such as a "Pick several"
/// button, and [footer] under the grid, such as the multi-select "Add to 2
/// reels & next" button.
class TtTagPanel extends StatelessWidget {
  /// A panel titled [title] with [chips] in two columns.
  const new({
    required this.title,
    required this.chips,
    this.headerAction,
    this.footer,
    super.key,
  });

  /// The header text, such as "Add to reel".
  final String title;

  /// The chips (normally `TtReelChip`s), laid out two to a row.
  final List<Widget> chips;

  /// A control at the end of the header, or null for none.
  final Widget? headerAction;

  /// A widget under the grid, or null for none.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final radius = BorderRadius.vertical(top: Radius.circular(tt.radii.xxl));
    final action = headerAction;
    final bottom = footer;

    // proto.css: .tagpanel, .ph-h; tt-style.css: .style-tt .tagpanel
    final header = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: TtMetrics.tagPanelHeaderHeight,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: tt.spacing.xs,
          end: tt.spacing.xxs,
        ),
        child: Row(
          spacing: tt.spacing.xs,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.text.material.titleSmall!.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );

    final rows = <Widget>[
      for (var i = 0; i < chips.length; i += 2)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: tt.spacing.xs,
          children: [
            Expanded(child: chips[i]),
            Expanded(
              child: i + 1 < chips.length
                  ? chips[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
    ];

    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: TtMetrics.tagPanelMaxHeight,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: TtMetrics.tagPanelBlur,
              sigmaY: TtMetrics.tagPanelBlur,
            ),
            child: CustomPaint(
              foregroundPainter: _TopHighlight(
                color: tt.colors.hairline,
                radius: radius,
              ),
              child: ColoredBox(
                color: scheme.surfaceContainer.withValues(
                  alpha: TtMetrics.tagPanelOpacity,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tt.spacing.s,
                    tt.spacing.s,
                    tt.spacing.s,
                    TtMetrics.tagPanelPaddingBottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: tt.spacing.xs,
                    children: [
                      header,
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: tt.spacing.xxs),
                          child: Column(spacing: tt.spacing.xs, children: rows),
                        ),
                      ),
                      if (bottom != null)
                        Padding(
                          padding: EdgeInsets.only(top: tt.spacing.xxs),
                          child: bottom,
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

/// The 1 dp highlight that follows the panel's rounded top edge: the panel's
/// shape minus the same shape moved down by 1 dp.
class _TopHighlight extends CustomPainter {
  const new({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRRect(radius.toRRect(Offset.zero & size));
    final inner = Path()
      ..addRRect(
        radius.toRRect(const Offset(0, TtMetrics.tagPanelHairline) & size),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TopHighlight old) =>
      old.color != color || old.radius != radius;
}

/// The "Same as previous" button in the quick row under the video: it tags
/// the clip with the reels of the last one.
///
/// A translucent white pill, 48 dp high at least, with a repeat icon and two
/// lines: [label] over a smaller [detail] (such as the reel names). Both
/// lines are one line with an ellipsis, so the button keeps whatever width it
/// is given (put it in an `Expanded`). A null [onPressed] disables it and
/// dims it.
class TtSameAsPreviousButton extends StatelessWidget {
  /// A button showing [label] and [detail].
  const new({
    required this.label,
    required this.semanticLabel,
    this.detail,
    this.onPressed,
    super.key,
  });

  /// The first line, such as "Same as previous".
  final String label;

  /// The smaller second line, such as the names of the reels; none when null.
  final String? detail;

  /// What a screen reader says; it should include the reels.
  final String semanticLabel;

  /// Called when the button is tapped; null disables it.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final enabled = onPressed != null;
    final second = detail;
    // proto.css: .qrow .btn.same; disabled follows .btn[disabled] with white
    // in place of on-surface.
    final content = tt.colors.onVideo.withValues(
      alpha: enabled ? 1 : TtMetrics.disabledContentOpacity,
    );
    final fill = tt.colors.onVideo.withValues(
      alpha: enabled
          ? TtMetrics.sameButtonFillOpacity
          : TtMetrics.disabledContainerOpacity,
    );
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: onPressed,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtMetrics.sameButtonRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tt.spacing.m,
                vertical: tt.spacing.xxs,
              ),
              child: Row(
                spacing: tt.spacing.xs,
                children: [
                  Icon(
                    Symbols.repeat_rounded,
                    size: tt.sizes.iconSmall,
                    color: content,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.text.material.labelLarge!.copyWith(
                            color: content,
                            height: TtMetrics.sameButtonLabelHeight,
                          ),
                        ),
                        if (second != null)
                          Text(
                            second,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.text.material.bodySmall!.copyWith(
                              color: content.withValues(
                                alpha:
                                    content.a *
                                    TtMetrics.sameButtonDetailOpacity,
                              ),
                            ),
                          ),
                      ],
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
