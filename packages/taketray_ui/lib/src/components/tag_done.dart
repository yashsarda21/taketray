import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/buttons.dart';
import 'package:taketray_ui/src/components/video_surface.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// One line of the summary on the "All done!" screen: a reel and how many
/// clips went into it.
class TtTagDoneRow {
  /// A row showing [name] and [count].
  const new({required this.name, required this.count});

  /// The label, such as a reel's name or "Skipped".
  final String name;

  /// The number at the end, written by the caller, such as "+5" or "3".
  final String count;
}

/// The "All done!" screen at the end of the tag player.
///
/// A green round check badge that pops in, the [title] and the [body] line,
/// a summary list of [rows] (a name and a count each), and two actions: a
/// filled [primaryLabel] button and a text [secondaryLabel] button under it.
/// Always dark: it draws on black under `TakeTrayTheme.video`, whatever the
/// app theme is, like the player it follows. With no rows the summary is
/// left out.
///
/// The content is centred in the space it is given and scrolls when there
/// are more rows than fit, so the buttons stay reachable at large text. The
/// screen adds no room for the status bar: put it under a `SafeArea`.
///
/// Each row is read as its name, then its count. The badge is only decoration
/// and is not announced; the title is a heading.
class TtTagDone extends StatelessWidget {
  /// A screen titled [title] with [body] and a summary of [rows].
  const new({
    required this.title,
    required this.body,
    required this.rows,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    super.key,
  });

  /// The headline, such as "All done!".
  final String title;

  /// The line under it, such as "12 clips sorted. Nice work.".
  final String body;

  /// The summary: one row per reel, and perhaps one for skipped clips.
  final List<TtTagDoneRow> rows;

  /// The label of the main button, such as "See your reels".
  final String primaryLabel;

  /// Called when the main button is tapped.
  final VoidCallback onPrimary;

  /// The label of the text button, such as "Back to To tag".
  final String secondaryLabel;

  /// Called when the text button is tapped.
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return TtVideoSurface(
      child: Builder(
        builder: (context) {
          final tt = context.tt;
          final text = tt.text.material;
          final white = tt.colors.onVideo;
          // proto.css: .done-scr
          final content = Padding(
            padding: EdgeInsets.all(tt.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: TtMetrics.tagDoneGap,
              children: [
                const _Badge(),
                Padding(
                  padding: const EdgeInsets.only(
                    top: TtMetrics.tagDoneTitleTop,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: text.headlineMedium!.copyWith(color: white),
                    ),
                  ),
                ),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge!.copyWith(
                    color: white.withValues(
                      alpha: TtMetrics.tagDoneBodyOpacity,
                    ),
                  ),
                ),
                if (rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: TtMetrics.tagDoneSummaryMarginTop,
                      bottom: TtMetrics.tagDoneSummaryMarginBottom,
                    ),
                    child: _Summary(rows: rows),
                  ),
                TtButton(
                  label: primaryLabel,
                  size: TtButtonSize.large,
                  onPressed: onPrimary,
                ),
                // .done-scr .btn.text { color: #fff }
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme
                        .copyWith(primary: white),
                  ),
                  child: TtButton(
                    label: secondaryLabel,
                    kind: TtButtonKind.text,
                    onPressed: onSecondary,
                  ),
                ),
              ],
            ),
          );
          return LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: box.hasBoundedHeight ? box.maxHeight : 0,
                  minWidth: box.maxWidth,
                ),
                child: Center(child: content),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The round check badge, which pops in from 40 % size.
class _Badge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // proto.css: .done-scr .big, @keyframes pop
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: tt.motion.long2,
        curve: tt.motion.emphasizedDecelerate,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(
            scale:
                TtMetrics.tagDoneBadgePopScale +
                (1 - TtMetrics.tagDoneBadgePopScale) * t,
            child: child,
          ),
        ),
        child: DecoratedBox(
          key: const ValueKey('tt-done-badge'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tt.colors.success,
          ),
          child: SizedBox.square(
            dimension: TtMetrics.tagDoneBadgeSize,
            child: Icon(
              Symbols.check_rounded,
              size: TtMetrics.tagDoneBadgeIconSize,
              color: tt.colors.onSuccess,
            ),
          ),
        ),
      ),
    );
  }
}

/// The translucent list of names and counts.
class _Summary extends StatelessWidget {
  const new({required this.rows});

  final List<TtTagDoneRow> rows;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final white = tt.colors.onVideo;
    final text = tt.text.material.bodyMedium!.copyWith(color: white);
    // proto.css: .done-scr .sum, .done-scr .sum div, tt-style.css radius 22
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: TtMetrics.tagDoneSummaryMaxWidth,
      ),
      child: SizedBox(
        key: const ValueKey('tt-done-summary'),
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: white.withValues(alpha: TtMetrics.tagDoneSummaryFillOpacity),
            borderRadius: BorderRadius.circular(TtMetrics.tagDoneSummaryRadius),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tt.spacing.m,
              vertical: TtMetrics.tagDoneSummaryPaddingVertical,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: white.withValues(
                        alpha: TtMetrics.tagDoneDividerOpacity,
                      ),
                    ),
                  MergeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: TtMetrics.tagDoneRowPaddingVertical,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: TtMetrics.tagDoneRowGap,
                        children: [
                          Expanded(child: Text(rows[i].name, style: text)),
                          Text(rows[i].count, style: tt.text.numeric(text)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
