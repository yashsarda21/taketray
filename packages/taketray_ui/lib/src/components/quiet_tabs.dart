import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/pill_tap_target.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// One tab of a [TtQuietTabs]: the [value] it stands for, its [label] and the
/// [count] after it.
class TtQuietTab<T> {
  /// A tab for [value] showing [label] and [count]; a screen reader says
  /// [semanticLabel] instead of both.
  const new(this.value, this.label, this.count, {required this.semanticLabel});

  /// What [TtQuietTabs.onChanged] receives when this tab is tapped.
  final T value;

  /// The text on the tab; one line.
  final String label;

  /// The number shown after the label.
  final int count;

  /// What a screen reader says: the label and the count in a sentence
  /// ("Show Ready reels, 4").
  final String semanticLabel;
}

/// A row of quiet tabs: the chosen one filled, the others plain text.
///
/// For a filter whose choices are few and have counts (Home's All,
/// Collecting, Ready and Published). Each tab is a 40 dp pill with a 48 dp
/// tap target: the chosen one `secondaryContainer` with `onSecondaryContainer`
/// text, the others transparent with `onSurfaceVariant` text; the label then
/// the count (tabular figures, at 80 %). The row scrolls sideways without a
/// scrollbar when the tabs do not fit.
///
/// A screen reader finds one group named [semanticLabel] ("Show reels"); each
/// tab is a toggle button named its own [TtQuietTab.semanticLabel] that is on
/// when chosen (the prototype's `aria-pressed`). A [value] that no tab has
/// chooses none.
///
/// `TtPillTabs` is the other look (inverse fill, no count); the date range
/// picker keeps it.
class TtQuietTabs<T> extends StatelessWidget {
  /// Tabs for [tabs] with [value] chosen, calling [onChanged] with the value
  /// of the tapped tab.
  const new({
    required this.tabs,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  /// The tabs, in order.
  final List<TtQuietTab<T>> tabs;

  /// The value of the chosen tab.
  final T value;

  /// Called with the value of the tapped tab.
  final ValueChanged<T> onChanged;

  /// The name of the group ("Show reels").
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // home2.css:50: .h2-tabs { display: flex; gap: 4px; padding: 0 12px 10px;
    //   overflow-x: auto; scrollbar-width: none }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        // Align: shrink to the tabs' height even where the parent is tight.
        child: Align(
          heightFactor: 1,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(
              start: TtMetrics.quietTabsPaddingHorizontal,
              end: TtMetrics.quietTabsPaddingHorizontal,
              bottom: TtMetrics.quietTabsPaddingBottom,
            ),
            child: Row(
              spacing: TtMetrics.quietTabsGap,
              children: [
                for (final tab in tabs)
                  _QuietTab(
                    tab: tab,
                    chosen: tab.value == value,
                    onPressed: () => onChanged(tab.value),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietTab<T> extends StatelessWidget {
  const new({required this.tab, required this.chosen, required this.onPressed});

  final TtQuietTab<T> tab;
  final bool chosen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // home2.css:52: .h2-tab { color: on-surface-variant; font: label-large },
    // .h2-tab.on { background: secondary-container;
    //   color: on-secondary-container }
    final color = chosen
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final label = tt.text.material.labelLarge!.copyWith(color: color);
    // home2.css:53: .h2-tab span { font-variant-numeric: tabular-nums;
    //   opacity: .8 }. The opacity is in the colour: one text, no layer.
    final count = tt.text
        .numeric(label)
        .copyWith(
          color: color.withValues(alpha: TtMetrics.quietTabCountOpacity),
        );
    return TtPillTapTarget(
      label: tab.semanticLabel,
      toggled: chosen,
      onPressed: onPressed,
      // The fill is Material's own colour change, 200 ms (a fade, so it stays
      // with reduced motion).
      child: Material(
        color: scheme.secondaryContainer.withValues(alpha: chosen ? 1 : 0),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TtMetrics.quietPillHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TtMetrics.quietTabPaddingHorizontal,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: TtMetrics.quietTabCountGap,
                children: [
                  Text(tab.label, maxLines: 1, softWrap: false, style: label),
                  Text(
                    '${tab.count}',
                    maxLines: 1,
                    softWrap: false,
                    style: count,
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
