import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A settings-style group: [children] (usually [TtListRow]s) stacked 2 dp
/// apart on the low surface container, inset by the screen gutter.
///
/// The group's outer corners are 22 dp round and the corners between rows
/// 6 dp, so a group of one row is a 22 dp rounded card. Each child sits on
/// its own [Material], so a row's ripple follows its corners.
class TtGroupedRows extends StatelessWidget {
  /// A group of [children], first to last.
  const new({required this.children, super.key});

  /// The rows, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final fill = context.scheme.surfaceContainerLow;
    // tt-style.css: .style-tt .scroll > .li (+ the first and last row)
    const outer = Radius.circular(TtMetrics.groupedRowsOuterRadius);
    const inner = Radius.circular(TtMetrics.groupedRowsInnerRadius);
    final last = children.length - 1;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TtMetrics.groupedRowsGap,
        children: [
          for (final (index, child) in children.indexed)
            Material(
              color: fill,
              borderRadius: BorderRadius.vertical(
                top: index == 0 ? outer : inner,
                bottom: index == last ? outer : inner,
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
        ],
      ),
    );
  }
}

/// The small upper-case heading above a [TtGroupedRows], announced as a
/// heading. [text] is given in normal case and shown in capitals.
class TtGroupLabel extends StatelessWidget {
  /// A label reading [text].
  const new(this.text, {super.key});

  /// The heading, such as "Shooting mode".
  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // tt-style.css: .style-tt .li-h { padding: 22px 28px 8px }
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        TtMetrics.groupLabelPaddingHorizontal,
        TtMetrics.groupLabelPaddingTop,
        TtMetrics.groupLabelPaddingHorizontal,
        tt.spacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          semanticsLabel: text,
          style: tt.text.groupLabel.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The icon at the start of a [TtListRow].
///
/// [boxed] puts a filled glyph on a 40 dp rounded square in the highest
/// surface container (`.lead.box`); otherwise it is a bare 24 dp icon
/// (`.lead`). Both are in the quiet content colour and hidden from screen
/// readers: the row's text says what it is.
class TtRowIcon extends StatelessWidget {
  /// A row icon showing [icon].
  const new({required this.icon, this.boxed = true, super.key});

  /// The glyph.
  final IconData icon;

  /// Whether the glyph sits on a rounded square.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final sizes = context.tt.sizes;
    final scheme = context.scheme;
    final glyph = ExcludeSemantics(
      child: Icon(
        icon,
        fill: boxed ? 1 : 0,
        size: sizes.icon,
        color: scheme.onSurfaceVariant,
      ),
    );
    if (!boxed) {
      return SizedBox.square(dimension: sizes.icon, child: glyph);
    }
    // proto.css: .li .lead.box, tt-style.css: .style-tt .li .lead.box
    return SizedBox.square(
      dimension: TtMetrics.rowIconBoxSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(TtMetrics.rowIconBoxRadius),
        ),
        child: Center(child: glyph),
      ),
    );
  }
}

/// A row of a list: an optional [leading] widget (a [TtRowIcon] or a
/// thumbnail), a [title] with an optional [subtitle], and an optional
/// [trailing] widget (a chevron, a value, a switch or a button).
///
/// It is at least 56 dp high and grows with the text: the title and subtitle
/// wrap, never ending in an ellipsis. With [onTap] the whole row is a
/// button; without it the row is plain, so a trailing switch or button is
/// the only control in it. [trailing] gets the quiet content colour and the
/// small label style, so a bare `Text` is a value and an `Icon` a chevron.
///
/// [semanticLabel] replaces what a screen reader says for a tappable row
/// (the title and subtitle by default).
///
/// Variants (D-79):
/// - [tall] makes the row at least 72 dp high (two lines and a count).
/// - [off] is a row that cannot be used now: it has no [onTap], reads as a
///   disabled button named [semanticLabel], and is drawn with AA contrast, not
///   faded: the title is `onSurfaceVariant` at weight 400, and a [TtRowCount]
///   in it turns outlined.
/// - [TtRowCount] and [TtRowSpinner] are the trailing parts of a row that
///   counts, or is busy.
class TtListRow extends StatelessWidget {
  /// A row titled [title].
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.stackTrailingAtLargeText = false,
    this.tall = false,
    this.off = false,
    this.focusNode,
    super.key,
  }) : assert(!off || onTap == null, 'An off row cannot be tapped');

  /// The focus of a tappable row, so a screen can give it back the focus
  /// (after a page it opened closes), or null.
  final FocusNode? focusNode;

  /// Whether the row is at least 72 dp high instead of 56 dp.
  final bool tall;

  /// Whether the row cannot be used now (see the class comment). Needs a null
  /// [onTap].
  final bool off;

  /// The main text.
  final String title;

  /// A quieter line under the title, or null.
  final String? subtitle;

  /// The widget before the text, or null.
  final Widget? leading;

  /// The widget after the text, or null.
  final Widget? trailing;

  /// Called when the row is tapped; null makes the row not tappable.
  final VoidCallback? onTap;

  /// What a screen reader says for a tappable row instead of the text, or
  /// null for the text. Ignored when [onTap] is null, so it cannot hide a
  /// trailing control.
  final String? semanticLabel;

  /// Whether [trailing] moves under the subtitle from a text scale of 1.5,
  /// instead of staying beside the text. Set it for a trailing value, a
  /// value with a chevron or a button, which would squeeze the title into
  /// broken words at large text; leave it off for a switch or a lone
  /// chevron, which are narrow. The call site decides, so any widget works.
  final bool stackTrailingAtLargeText;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final leading = this.leading;
    final trailing = this.trailing;
    final subtitle = this.subtitle;
    final quiet = scheme.onSurfaceVariant;
    // A wide trailing beside the text would squeeze it into broken words at
    // large text: from 1.5x it goes under the text instead, if asked.
    final stacked =
        trailing != null &&
        stackTrailingAtLargeText &&
        MediaQuery.textScalerOf(context).scale(1) >=
            TtMetrics.listRowStackTrailingTextScale;
    final trailingBox = trailing == null
        ? null
        : _RowOff(
            off: off,
            child: DefaultTextStyle.merge(
              style: text.labelMedium!.copyWith(color: quiet),
              child: IconTheme.merge(
                data: IconThemeData(color: quiet),
                child: trailing,
              ),
            ),
          );
    // proto.css: .li, .li .txt b / span, .li .trail
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: tall
            ? TtMetrics.listRowTallMinHeight
            : TtMetrics.listRowMinHeight,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tt.spacing.m,
          vertical: tt.spacing.xs,
        ),
        child: Row(
          spacing: tt.spacing.m,
          children: [
            ?leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    // An off row: onSurfaceVariant at weight 400, no fade.
                    style: text.bodyLarge!.copyWith(
                      color: off ? quiet : scheme.onSurface,
                      fontWeight: off ? FontWeight.w400 : FontWeight.w500,
                      fontVariations: [
                        FontVariation(
                          'wght',
                          off
                              ? TtMetrics.listRowOffTitleWeight
                              : TtMetrics.listRowTitleWeight,
                        ),
                      ],
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: text.bodyMedium!.copyWith(color: quiet),
                    ),
                  if (stacked)
                    Padding(
                      padding: EdgeInsets.only(top: tt.spacing.xxs),
                      child: trailingBox,
                    ),
                ],
              ),
            ),
            if (!stacked) ?trailingBox,
          ],
        ),
      ),
    );
    if (onTap == null) {
      if (!off) return content;
      // Off: a disabled button that still says what it is.
      return Semantics(
        container: true,
        button: true,
        enabled: false,
        excludeSemantics: semanticLabel != null,
        label: semanticLabel,
        child: content,
      );
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      // The ink well supplies the tap action, unless it is excluded.
      onTap: semanticLabel == null ? null : onTap,
      child: InkWell(focusNode: focusNode, onTap: onTap, child: content),
    );
  }
}

/// Tells a [TtRowCount] inside a row whether the row is off.
class _RowOff extends InheritedWidget {
  const new({required this.off, required super.child});

  final bool off;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowOff>()?.off ?? false;

  @override
  bool updateShouldNotify(_RowOff oldWidget) => off != oldWidget.off;
}

/// How many videos a row would add, at the end of a [TtListRow].
///
/// With [pill] (the default) it is "N new" in a `secondaryContainer` pill, at
/// least 28 dp high with 12 dp sides; without it, a plain word such as
/// "none" or "Adding…" in `onSurfaceVariant`. Both are `labelLarge`. In an
/// [TtListRow.off] row the pill has no fill and a 1 dp `outlineVariant`
/// outline, and the text is `onSurfaceVariant`, so it stays readable
/// (AA contrast) with no fade.
class TtRowCount extends StatelessWidget {
  /// A count showing [text].
  const new(this.text, {this.pill = true, super.key});

  /// What it says, such as "3 new" or "none".
  final String text;

  /// Whether it sits in a pill.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final off = _RowOff.of(context);
    final label = tt.text.material.labelLarge!;
    if (!pill) {
      return Text(text, style: label.copyWith(color: scheme.onSurfaceVariant));
    }
    // proto.css: .ev-row .ev-trail .n, and the same when the row is off
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: off ? null : scheme.secondaryContainer,
        shape: StadiumBorder(
          side: off
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: TtMetrics.rowCountMinHeight,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tt.spacing.s),
          child: Center(
            widthFactor: 1,
            child: Text(
              text,
              style: label.copyWith(
                color: off
                    ? scheme.onSurfaceVariant
                    : scheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 20 dp spinner (2 dp stroke, `primary`) that takes the place of a row's
/// chevron while it works. A screen reader hears [semanticLabel].
///
/// Without animations it stands still as a quarter arc.
class TtRowSpinner extends StatelessWidget {
  /// A spinner a screen reader calls [semanticLabel].
  const new({required this.semanticLabel, super.key});

  /// What a screen reader says, such as "Checking your videos from Oct 8".
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final still = context.tt.motion.isReduced;
    // proto.css: .ev-spin
    return Semantics(
      label: semanticLabel,
      role: ui.SemanticsRole.loadingSpinner,
      child: SizedBox.square(
        dimension: TtMetrics.rowSpinnerSize,
        child: ExcludeSemantics(
          child: CircularProgressIndicator(
            strokeWidth: TtMetrics.rowSpinnerStroke,
            color: context.scheme.primary,
            value: still ? TtMetrics.rowSpinnerStillValue : null,
          ),
        ),
      ),
    );
  }
}
