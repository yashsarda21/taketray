import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/buttons.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_text_styles.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// Which look and role a [TtBanner] has.
enum TtBannerKind {
  /// Something is wrong and needs the user: error container. Announced as an
  /// alert (a live region).
  warning,

  /// Calm information, such as a limited mode: the high surface container.
  info,

  /// Something is waiting for the user: tertiary container, usually tappable.
  attention,

  /// The "Editing in VN" status of a reel: secondary container, with its
  /// actions under the text.
  vn,
}

/// A full-width notice at the top of a screen: an [icon], a [title], an
/// optional [body] and an optional [action] (or, with [onTap], the whole
/// banner is a button and shows a chevron).
///
/// It is inset by the screen gutter, with 4 dp above and 8 dp below as in the
/// prototype's `.banner`, 20 dp round and at least 56 dp high. Title and body
/// wrap, so nothing is cut at large text; from a text scale of 1.5 the
/// [action] moves under the text instead of squeezing it. A [TtBannerKind.vn]
/// banner always puts its [action] (usually a `Wrap` of buttons) under the
/// text, indented to line up with it.
///
/// A text-style `TtButton` given as the [action] of a `warning`, `info` or
/// `attention` banner takes the banner's text colour, as in the prototype
/// (which also underlines it; here the button keeps its own text style).
class TtBanner extends StatelessWidget {
  /// A [kind] banner with the [icon] and [title].
  const new({
    required this.kind,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.onTap,
    this.iconFilled = true,
    super.key,
  }) : assert(
         onTap == null || action == null,
         'A banner with onTap is one button; give it onTap or an action, '
         'not both',
       );

  /// The look of the banner.
  final TtBannerKind kind;

  /// The glyph before the text.
  final IconData icon;

  /// Whether [icon] is drawn filled (the default) or outlined.
  ///
  /// The prototype fills the icon of a banner that stands for something to do
  /// (the "clips to tag" banner) and leaves the icon of a status banner
  /// (Manual mode, "can't see your videos") outlined.
  final bool iconFilled;

  /// What the banner says, in a line or more.
  final String title;

  /// A quieter line or more under the title, or null.
  final String? body;

  /// A widget after the text (under it for [TtBannerKind.vn] and at large
  /// text), usually a text-style `TtButton`, or null.
  final Widget? action;

  /// Called when the banner is tapped; makes it a button with a chevron.
  /// Not allowed together with an [action] (an assertion fails): a button
  /// inside a button would be two nested tap targets.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final action = this.action;
    final body = this.body;

    // proto.css: .banner.attn / .warn / .info / .vn
    final (fill, content, quiet) = switch (kind) {
      TtBannerKind.warning => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        scheme.onErrorContainer,
      ),
      TtBannerKind.info => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        scheme.onSurfaceVariant,
      ),
      TtBannerKind.attention => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      TtBannerKind.vn => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };
    final vn = kind == TtBannerKind.vn;
    final large =
        MediaQuery.textScalerOf(context).scale(1) >=
        TtMetrics.bannerActionBelowTextScale;
    final below = action != null && (vn || large);

    final shownAction = action == null
        ? null
        : vn
        ? action
        : _inheritColour(context, action, content);

    final row = Row(
      crossAxisAlignment: vn
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      spacing: tt.spacing.s,
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            fill: iconFilled ? 1 : 0,
            size: tt.sizes.icon,
            color: content,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: text.titleSmall!.copyWith(color: content)),
              if (body != null)
                Padding(
                  padding: const EdgeInsets.only(top: TtMetrics.bannerBodyGap),
                  child: Text(
                    body,
                    style: text.bodySmall!.copyWith(color: quiet),
                  ),
                ),
            ],
          ),
        ),
        if (shownAction != null && !below) shownAction,
        if (onTap != null && action == null)
          ExcludeSemantics(
            child: Icon(
              Symbols.chevron_right_rounded,
              size: tt.sizes.icon,
              color: content,
            ),
          ),
      ],
    );

    final inner = Padding(
      padding: vn
          ? EdgeInsets.symmetric(
              horizontal: tt.spacing.m,
              vertical: TtMetrics.bannerVnPaddingVertical,
            )
          : EdgeInsetsDirectional.fromSTEB(
              tt.spacing.m,
              tt.spacing.s,
              tt.spacing.xs,
              tt.spacing.s,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          if (shownAction != null && below)
            // proto.css: .banner.vn .acts { padding-left: 36px;
            // margin-top: 4px }
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: tt.sizes.icon + tt.spacing.s,
                top: tt.spacing.xxs,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: shownAction,
              ),
            ),
        ],
      ),
    );

    final box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TtMetrics.bannerMinHeight),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: inner,
      ),
    );

    // proto.css: .banner { margin: 4px 16px 8px; border-radius: 16px;
    // min-height: 56px }
    // tt-style.css: .style-tt .banner { border-radius: 20px }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.gutter,
        TtMetrics.bannerMarginTop,
        tt.spacing.gutter,
        tt.spacing.xs,
      ),
      child: Semantics(
        // A tappable banner is one node with its ink well.
        container: onTap == null,
        liveRegion: kind == TtBannerKind.warning,
        button: onTap != null,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(tt.radii.xl),
          clipBehavior: Clip.antiAlias,
          child: onTap == null ? box : InkWell(onTap: onTap, child: box),
        ),
      ),
    );
  }
}

/// A rounded note inside a page: an [icon], an optional [title] and the
/// text, given as [body] or, to put words in bold, as [richBody] (exactly one
/// of the two). An optional [action] sits under the text.
///
/// It sits on the high surface container with the icon in the accent colour;
/// a [warning] callout uses the tertiary container instead. It has no outer
/// margin (the page decides) and its text wraps at any size.
class TtCallout extends StatelessWidget {
  /// A callout with the [icon] and the text in [body] or [richBody].
  const new({
    required this.icon,
    this.title,
    this.body,
    this.richBody,
    this.warning = false,
    this.action,
    super.key,
  }) : assert(
         (body == null) != (richBody == null),
         'Give exactly one of body and richBody',
       );

  /// The glyph before the text, drawn filled.
  final IconData icon;

  /// A bold first line, or null.
  final String? title;

  /// The text as a plain string. Give this or [richBody].
  final String? body;

  /// The text with styled spans (for bold words; the font is variable, so a
  /// bold span sets both `fontWeight` and `FontVariation('wght', 700)`).
  /// Give this or [body].
  final InlineSpan? richBody;

  /// Whether this is the tertiary-container warning look.
  final bool warning;

  /// A widget under the text, usually a text-style `TtButton`, or null.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final title = this.title;
    final body = this.body;
    final richBody = this.richBody;
    final action = this.action;
    // proto.css: .callout, .callout.warn
    final fill = warning
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHigh;
    final content = warning ? scheme.onTertiaryContainer : scheme.onSurface;
    final iconColor = warning ? scheme.onTertiaryContainer : scheme.primary;
    final bodyStyle = text.bodyMedium!.copyWith(color: content);
    // A warning takes the container's text colour for a text button, for
    // contrast on the tertiary container.
    final shownAction = action == null || !warning
        ? action
        : _inheritColour(context, action, content);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(tt.radii.xl),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: TtMetrics.calloutPaddingHorizontal,
          vertical: tt.spacing.s,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: tt.spacing.s,
          children: [
            ExcludeSemantics(
              child: Icon(icon, fill: 1, size: tt.sizes.icon, color: iconColor),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: TtMetrics.calloutTitleGap,
                      ),
                      child: Text(
                        title,
                        style: text.titleSmall!.copyWith(color: content),
                      ),
                    ),
                  if (body != null)
                    Text(body, style: bodyStyle)
                  else
                    Text.rich(richBody!, style: bodyStyle),
                  ?shownAction,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-line note above a list: an 18 dp [icon] and a short [text] on the low
/// surface container, inset by the screen gutter, 20 dp round, with 8 dp
/// under it. The text wraps at large sizes.
class TtInfoBar extends StatelessWidget {
  /// An info bar with the [icon] and [text].
  const new({required this.icon, required this.text, super.key});

  /// The glyph before the text.
  final IconData icon;

  /// What the bar says.
  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .infobar; tt-style.css: .style-tt .infobar { 20px }
    return Padding(
      padding: EdgeInsets.only(
        left: tt.spacing.gutter,
        right: tt.spacing.gutter,
        bottom: tt.spacing.xs,
      ),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tt.radii.xl),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tt.spacing.m,
            vertical: TtMetrics.infoBarPaddingVertical,
          ),
          child: Row(
            spacing: TtMetrics.infoBarGap,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: tt.sizes.iconSmall,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: tt.text.material.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
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

/// [action] with its text-style buttons in [colour] and underlined, as in
/// the prototype's `.banner .btn.text { color: inherit; text-decoration:
/// underline }`, so the action reads as a link and not as more text.
///
/// Done through a copy of the theme, so `TtButton` keeps its API: the
/// scheme's `primary` becomes [colour] and the label style gets an underline
/// in [colour]. A `TtButton` of another kind is not underlined. Flutter has no
/// `text-underline-offset`, so the underline sits at its default distance.
Widget _inheritColour(BuildContext context, Widget action, Color colour) {
  final theme = Theme.of(context);
  final tt = context.tt;
  final underline = action is! TtButton || action.kind == TtButtonKind.text;
  final material = tt.text.material;
  final text = tt.text;
  final underlined = TtTextStyles(
    material: material.copyWith(
      labelLarge: material.labelLarge!.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: colour,
      ),
    ),
    pageTitle: text.pageTitle,
    detailTitle: text.detailTitle,
    screenTitle: text.screenTitle,
    dialogTitle: text.dialogTitle,
    shootTitle: text.shootTitle,
    cardTitle: text.cardTitle,
    groupLabel: text.groupLabel,
    navLabel: text.navLabel,
  );
  return Theme(
    data: theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(primary: colour),
      extensions: [
        for (final extension in theme.extensions.values)
          if (extension is! TtThemeData) extension,
        if (underline) tt.copyWith(text: underlined) else tt,
      ],
    ),
    child: action,
  );
}
