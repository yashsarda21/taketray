import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/bar_scope.dart';
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
    super.key,
  });

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
    final titleBlock = Semantics(
      header: true,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle.copyWith(color: onBar),
          ),
          if (subtitle != null && !single)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.text.material.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    final bar = SizedBox(
      height: preferredSize.height,
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
                child: MediaQuery.withClampedTextScaling(
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
    return ColoredBox(
      color: selection ? scheme.secondaryContainer : scheme.surface,
      child: SafeArea(
        bottom: false,
        child: TtBarScope(selection: selection, child: bar),
      ),
    );
  }
}
