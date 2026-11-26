import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taketray_ui/src/components/internal/bar_scope.dart';
import 'package:taketray_ui/src/components/internal/pill_tap_target.dart';
import 'package:taketray_ui/src/components/internal/system_ui.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_sizes.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The top app bar of a screen.
///
/// 64 dp high with a [title] (and an optional [subtitle]) in the screen
/// title style, or, when [large], 80 dp with the big page title of a tab
/// screen. An optional [leading] widget (a back or close button) comes
/// first and the [actions] come last. Give icon buttons the
/// `TtIconButtonStyle.circle` style: they then sit on small circles.
///
/// [selection] turns it into the contextual bar of a multi-select: a
/// `secondaryContainer` background, a one-line medium title and plain
/// (circle-less) icons.
///
/// A [selection] bar's title is a count ("3 selected") that changes under the
/// user's finger. Set [liveRegion] to have a screen reader say the new count
/// when it changes.
///
/// It fills the width it is given, adds the status bar's height above
/// itself, and can be used as `Scaffold.appBar` or at the top of a column.
/// Its text is drawn at no more than [TtMetrics.appBarMaxTextScale] so it
/// stays inside the fixed height; a long title ends in an ellipsis.
class TtAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// A bar showing [title].
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.large = false,
    this.selection = false,
    this.liveRegion = false,
    this.titleFocusNode,
    this.wrapTitle = false,
    super.key,
  });

  /// Whether a long title wraps onto more lines, and the bar grows to hold
  /// it (at least 64 dp), instead of ending in an ellipsis inside a fixed
  /// bar. The title is then drawn at the phone's text scale, not clamped to
  /// [TtMetrics.appBarMaxTextScale]. For a screen whose title must be read in
  /// full at large text (the date range picker, D-79); the prototype's
  /// `.fs2 .appbar { height: auto; min-height: 64px }`.
  final bool wrapTitle;

  /// A focus node for the title, so a screen can move focus to it when it
  /// opens (a screen reader then starts at the title). Null for none.
  final FocusNode? titleFocusNode;

  /// The screen's name; one line, with an ellipsis if too long.
  final String title;

  /// A line under the title, or null for none. Ignored when [large] or in
  /// [selection] mode.
  final String? subtitle;

  /// A widget before the title, usually a back or close icon button.
  final Widget? leading;

  /// Widgets after the title, usually icon buttons, first to last.
  final List<Widget> actions;

  /// Whether this is the large page-title bar of a tab screen (80 dp).
  final bool large;

  /// Whether this is the contextual bar of a multi-select.
  final bool selection;

  /// Whether a screen reader announces the title each time it changes (the
  /// count of a multi-select: "2 selected"). Only a [selection] bar's title
  /// is a live region; the titles of other bars are headings that do not
  /// change while the screen is open, so this is ignored for them.
  final bool liveRegion;

  @override
  Size get preferredSize => Size.fromHeight(
    large ? TtMetrics.appBarLargeHeight : const TtSizes().topAppBar,
  );

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final onBar = selection ? scheme.onSecondaryContainer : scheme.onSurface;
    final single = selection || large;

    // proto.css: .appbar .title { padding: 0 12px }, .appbar.big .title
    // { padding: 0 }, .appbar.sel h1 { title-medium; nowrap }
    final titleStyle = selection
        ? tt.text.material.titleMedium!
        : large
        ? tt.text.pageTitle
        : tt.text.screenTitle;
    final subtitle = this.subtitle;
    final focusNode = titleFocusNode;
    final titleText = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: wrapTitle ? null : 1,
          overflow: wrapTitle ? TextOverflow.visible : TextOverflow.ellipsis,
          style: titleStyle.copyWith(color: onBar),
        ),
        if (subtitle != null && !single)
          Text(
            subtitle,
            maxLines: wrapTitle ? null : 1,
            overflow: wrapTitle ? TextOverflow.visible : TextOverflow.ellipsis,
            style: tt.text.material.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    final titleBlock = Semantics(
      header: true,
      container: true,
      liveRegion: selection && liveRegion,
      child: focusNode == null
          ? titleText
          : Focus(focusNode: focusNode, child: titleText),
    );

    final bar = ConstrainedBox(
      constraints: wrapTitle
          ? BoxConstraints(minHeight: preferredSize.height)
          : BoxConstraints.tightFor(height: preferredSize.height),
      child: Padding(
        // tt-style.css: .appbar.big { padding-top: 10px }; proto.css:
        // .appbar { padding: 0 4px }, .appbar.big { padding-left: 16px }
        padding: EdgeInsetsDirectional.only(
          top: large ? TtMetrics.appBarLargePaddingTop : 0,
          start: large ? tt.spacing.m : tt.spacing.xxs,
          end: tt.spacing.xxs,
        ),
        child: Row(
          spacing: tt.spacing.xxs,
          children: [
            ?leading,
            Expanded(
              child: Padding(
                padding: large
                    ? EdgeInsets.zero
                    : EdgeInsets.symmetric(horizontal: tt.spacing.s),
                child: wrapTitle
                    ? titleBlock
                    : MediaQuery.withClampedTextScaling(
                        maxScaleFactor: TtMetrics.appBarMaxTextScale,
                        child: titleBlock,
                      ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );

    // The background reaches under the status bar; the content sits below.
    // Material's AppBar picks the status bar icon colour from its
    // background; this bar replaces it, so it does the same (D-51).
    final background = selection ? scheme.secondaryContainer : scheme.surface;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ttSystemUiStyle(background),
      child: ColoredBox(
        color: background,
        child: SafeArea(
          bottom: false,
          child: TtBarScope(selection: selection, child: bar),
        ),
      ),
    );
  }
}

/// The tonal button at the end of a header: an [icon] and a short [label]
/// ("+ New") on a `secondaryContainer` pill.
///
/// The pill is 40 dp high (more at large text) with a 48 dp tap target and
/// `labelLarge` text, and carries its own 12 dp margin on the trailing side,
/// so as the last action of a [TtLargeSliverAppBar] it sits 12 dp from the
/// edge of the screen. A screen reader says [semanticLabel] ("New reel") as
/// one button.
class TtHeaderPill extends StatelessWidget {
  /// A pill showing [icon] and [label] that calls [onPressed] when tapped.
  const new({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  /// The icon before the label, drawn at 20 dp.
  final IconData icon;

  /// The text; one line.
  final String label;

  /// What a screen reader says instead of [label].
  final String semanticLabel;

  /// Called when the pill is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // home2.css:4: .h2 .appbar .h2-new { gap: 4px; min-height: 40px;
    //   padding: 0 16px 0 12px; margin-right: 12px; border-radius: 999px;
    //   background: secondary-container; color: on-secondary-container;
    //   font: label-large }
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        end: TtMetrics.headerPillMarginEnd,
      ),
      child: TtPillTapTarget(
        label: semanticLabel,
        onPressed: onPressed,
        child: Material(
          color: scheme.secondaryContainer,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TtMetrics.quietPillHeight,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: TtMetrics.headerPillPaddingStart,
                  end: TtMetrics.headerPillPaddingEnd,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: TtMetrics.headerPillGap,
                  children: [
                    // home2.css:5: .h2-new .ms { font-size: 20px }
                    Icon(
                      icon,
                      size: TtMetrics.headerPillIconSize,
                      color: scheme.onSecondaryContainer,
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: tt.text.material.labelLarge!.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
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

/// A large page title that shrinks into a pinned bar as the page scrolls:
/// Home's header.
///
/// A [SliverAppBar.large] for a `CustomScrollView`: 152 dp with the page title
/// (`tt.text.pageTitle`, as `TtAppBar(large: true)`) while the page is at
/// the top, then 64 dp with the screen title when scrolled. It stays pinned,
/// so the [actions] (a [TtHeaderPill]) stay in reach. It is `surface` with no
/// tint and no shadow, and sets the status bar icons for it like [TtAppBar].
/// A long title ends in an ellipsis before the actions.
class TtLargeSliverAppBar extends StatelessWidget {
  /// A header showing [title] with [actions] at its end.
  const new({required this.title, this.actions = const [], super.key});

  /// The screen's name; one line, with an ellipsis if too long.
  final String title;

  /// Widgets at the end of the bar, first to last.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // `SliverAppBar.large` is pinned by default; the pill must stay in reach.
    return SliverAppBar.large(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface.withValues(alpha: 0),
      scrolledUnderElevation: 0,
      systemOverlayStyle: ttSystemUiStyle(scheme.surface),
      title: _LargeTitle(title),
      actions: actions,
    );
  }
}

/// The title of a [TtLargeSliverAppBar]. Material builds it twice: in the
/// bar's toolbar (the screen title, from the theme) and in the flexible space
/// under it (the page title, while expanded). Only the first sits in a
/// [NavigationToolbar].
class _LargeTitle extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final inToolbar =
        context.findAncestorWidgetOfExactType<NavigationToolbar>() != null;
    final tt = context.tt;
    final color = context.scheme.onSurface;
    final text = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (inToolbar ? tt.text.screenTitle : tt.text.pageTitle).copyWith(
        color: color,
      ),
    );
    // The toolbar's title is already a heading (and hidden while expanded);
    // the expanded one is not, so a screen reader at the top of the page
    // finds one.
    return inToolbar ? text : Semantics(header: true, child: text);
  }
}
