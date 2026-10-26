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
    super.key,
  });

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
        : DefaultTextStyle.merge(
            style: text.labelMedium!.copyWith(color: quiet),
            child: IconTheme.merge(
              data: IconThemeData(color: quiet),
              child: trailing,
            ),
          );
    // proto.css: .li, .li .txt b / span, .li .trail
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TtMetrics.listRowMinHeight),
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
                    style: text.bodyLarge!.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontVariations: const [
                        FontVariation('wght', TtMetrics.listRowTitleWeight),
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
      return content;
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      // The ink well supplies the tap action, unless it is excluded.
      onTap: semanticLabel == null ? null : onTap,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
