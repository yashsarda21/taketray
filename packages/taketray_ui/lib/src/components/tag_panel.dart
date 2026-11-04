import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/reel_chip.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The panel at the bottom of the tag player: a [title] row, a two-column
/// grid of [chips], and an optional [footer].
///
/// A glass panel (surface container at 92 %, blurred) with a 28 dp radius at
/// the top, a highlight along its top edge, and 12 dp of padding (26 at the
/// bottom). It is at most 340 dp high; with more chips than fit, the grid
/// scrolls and the header and footer stay put. From a text scale of 1.5 the
/// chips are one per row and the cap grows with the scale, to 520 dp. The
/// title is announced as a heading. The panel takes the width it is given;
/// each chip gets half of it less the padding and the 8 dp gap (164 dp at
/// 360 dp), or all of it at large text. The whole panel is one semantics
/// group named [semanticLabel], with the header, the chips and the footer as
/// separate nodes inside it.
///
/// The scrolling part holds, in order, with 8 dp between rows:
/// 1. [emptyText], a centred message across the row (no reels yet);
/// 2. [chips], two to a row. A `TtNewReelChip` with `fullWidth` takes a row
///    of its own;
/// 3. [toggle], a whole row, such as "Other reels (4)";
/// 4. [foldedChips], two to a row again, but only while the [toggle] is
///    expanded, or when there is none.
///
/// [headerAction] sits at the end of the header, such as a "Pick several"
/// button, and [footer] under the grid, such as the multi-select "Add to 2
/// reels & next" button.
class TtTagPanel extends StatelessWidget {
  /// A panel titled [title], named [semanticLabel], with [chips] in two
  /// columns.
  const new({
    required this.title,
    required this.semanticLabel,
    required this.chips,
    this.headerAction,
    this.emptyText,
    this.toggle,
    this.foldedChips = const [],
    this.footer,
    super.key,
  });

  /// The header text, such as "Add to reel".
  final String title;

  /// What a screen reader says for the panel as a group, such as "Reels".
  final String semanticLabel;

  /// The chips of the open group (normally `TtReelChip`s, then perhaps a
  /// `TtNewReelChip`), laid out two to a row.
  final List<Widget> chips;

  /// A control at the end of the header, or null for none.
  final Widget? headerAction;

  /// A message across the whole row above the chips, such as "You don't have
  /// any reels yet. Create one and this clip goes into it."; none when null.
  final String? emptyText;

  /// The "Other reels" row between [chips] and [foldedChips], or null for
  /// none.
  final TtOtherReelsToggle? toggle;

  /// The chips under the [toggle], two to a row. Shown only while the toggle
  /// is expanded, or when there is no toggle, so what is on screen always
  /// agrees with what the toggle announces.
  final List<Widget> foldedChips;

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

    // At large text sizes a 164 dp cell shows too little of a name, so the
    // chips take a row each (D-47), and the panel may grow taller.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final large = scale >= TtMetrics.tagPanelSingleColumnTextScale;
    final maxHeight = math.min(
      TtMetrics.tagPanelMaxHeight * math.max(1, scale),
      TtMetrics.tagPanelMaxHeightLarge,
    );
    final showFolded = toggle?.expanded ?? true;
    final message = emptyText;
    final rows = <Widget>[
      if (message != null)
        // proto.css: the no-reels message, `padding: 8px 8px 4px`
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tt.spacing.xs,
            end: tt.spacing.xs,
            top: tt.spacing.xs,
            bottom: tt.spacing.xxs,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: tt.text.material.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ..._gridRows(chips, large: large, gap: tt.spacing.xs),
      ?toggle,
      if (showFolded)
        ..._gridRows(foldedChips, large: large, gap: tt.spacing.xs),
    ];

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                            child: Column(
                              spacing: tt.spacing.xs,
                              children: rows,
                            ),
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
      ),
    );
  }
}

/// Lays [chips] out two to a row, or one per row at [large] text. A
/// full-width `TtNewReelChip` ends the row before it and takes its own.
List<Widget> _gridRows(
  List<Widget> chips, {
  required bool large,
  required double gap,
}) {
  if (large) return chips;
  final rows = <Widget>[];
  Widget? waiting;
  Widget pair(Widget first, Widget? second) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: gap,
    children: [
      Expanded(child: first),
      Expanded(child: second ?? const SizedBox.shrink()),
    ],
  );
  for (final chip in chips) {
    if (chip is TtNewReelChip && chip.fullWidth) {
      if (waiting != null) rows.add(pair(waiting, null));
      waiting = null;
      rows.add(chip);
    } else if (waiting == null) {
      waiting = chip;
    } else {
      rows.add(pair(waiting, chip));
      waiting = null;
    }
  }
  if (waiting != null) rows.add(pair(waiting, null));
  return rows;
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
/// are one line with an ellipsis (the label may take two from
/// [TtMetrics.largeTextScale] up, and the button grows), so the button keeps
/// whatever width it is given (put it in an `Expanded`). A null [onPressed]
/// disables it and dims it.
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
    final large =
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
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
                          maxLines: large ? 2 : 1,
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

/// The "Other reels" row in the tag panel: a label, such as "Other reels (4)",
/// with an arrow that points down while the reels are folded and up while
/// they are shown.
///
/// The row is drawn 36 dp high and its tap target is 48 dp, the whole width
/// it is given. It is announced as a button that is expanded or collapsed.
/// The label is the caller's, and says the count while folded.
class TtOtherReelsToggle extends StatelessWidget {
  /// A toggle labelled [label] that calls [onToggle] when tapped.
  const new({
    required this.label,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  /// The text, such as "Other reels (4)" while folded and "Other reels" while
  /// open. It is also what a screen reader says.
  final String label;

  /// Whether the reels under the toggle are shown.
  final bool expanded;

  /// Called when the row is tapped.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .chipgrid .lbl, and the toggle's inline style
    final color = scheme.onSurfaceVariant;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      expanded: expanded,
      label: label,
      onTap: onToggle,
      child: Material(
        color: scheme.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(TtMetrics.otherReelsToggleRadius),
        clipBehavior: Clip.antiAlias,
        // The whole 48 dp takes the tap; the row inside is drawn 36 dp high.
        child: InkWell(
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                key: const ValueKey('tt-other-reels-row'),
                constraints: const BoxConstraints(
                  minHeight: TtMetrics.otherReelsToggleHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tt.spacing.xs),
                  child: Row(
                    spacing: TtMetrics.otherReelsToggleGap,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.text.material.labelMedium!.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                      Icon(
                        expanded
                            ? Symbols.expand_less_rounded
                            : Symbols.expand_more_rounded,
                        size: tt.sizes.iconSmall,
                        color: color,
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
