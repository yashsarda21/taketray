import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/badges.dart';
import 'package:taketray_ui/src/components/glass.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// One destination of a [TtNavPill].
class TtNavItem {
  /// A destination called [label], drawn with [icon].
  const new({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.badgeSemanticLabel,
  });

  /// The glyph; the pill draws it filled while the item is selected.
  final IconData icon;

  /// The name under the icon, and what a screen reader says.
  final String label;

  /// A count on the icon (clips waiting); hidden at 0, "99+" above 99.
  final int badgeCount;

  /// What a screen reader says instead of [label] while [badgeCount] is
  /// above 0, such as "To tag, 7 clips waiting"; null to say [label].
  final String? badgeSemanticLabel;
}

/// The floating glass navigation pill of the main tabs.
///
/// A 64 dp frosted pill, 20 dp from the sides and 10 dp above the safe area
/// at the bottom of the screen, holding one equal-width item per
/// [TtNavItem]. The item at [currentIndex] has a `primaryContainer` fill and
/// a filled icon; the fill changes over `motion.short4` (not at all under
/// "remove animations"). Tapping an item, selected or not, calls
/// [onSelected] with its index.
///
/// Use it as `Scaffold.bottomNavigationBar` with `extendBody: true`, so the
/// screen shows through the glass. A scrollable tab screen adds
/// [reservedHeight] to its bottom padding so its last row can scroll clear
/// of the pill. Labels are drawn at no more than
/// [TtMetrics.navPillMaxTextScale] to stay inside the fixed height.
class TtNavPill extends StatelessWidget {
  /// A pill of [items] with the one at [currentIndex] selected.
  const new({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  /// The destinations, first to last.
  final List<TtNavItem> items;

  /// Which item is selected.
  final int currentIndex;

  /// Called with an item's index when it is tapped.
  final ValueChanged<int> onSelected;

  /// How much of the bottom of the screen the pill takes: its height, the
  /// gap under it and the bottom safe area. Add it to the bottom padding of
  /// a scrollable screen behind the pill.
  ///
  /// It reads the bottom padding of the nearest `MediaQuery`, so call it
  /// where that is the device's safe area. A `Scaffold` with `extendBody`
  /// adds the pill's height to its body's padding, so the body of a shell
  /// that uses [reservedHeight] must put the plain safe-area padding back
  /// (the app's `AppShell` does).
  static double reservedHeight(BuildContext context) =>
      TtMetrics.navPillHeight +
      TtMetrics.navPillInsetBottom +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: tt.spacing.l,
          end: tt.spacing.l,
          bottom: TtMetrics.navPillInsetBottom,
        ),
        child: TtGlass(
          radius: TtMetrics.navPillRadius,
          child: SizedBox(
            height: TtMetrics.navPillHeight,
            child: Padding(
              padding: const EdgeInsets.all(TtMetrics.navPillPadding),
              child: Row(
                spacing: tt.spacing.xxs,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItemView(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () => onSelected(i),
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

class _NavItemView extends StatelessWidget {
  const new({required this.item, required this.selected, required this.onTap});

  final TtNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final color = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(TtMetrics.navItemRadius);
    final badgeLabel = item.badgeSemanticLabel;
    final label = item.badgeCount > 0 && badgeLabel != null
        ? badgeLabel
        : item.label;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: tt.motion.short4,
        curve: tt.motion.standard,
        decoration: BoxDecoration(
          // tt-style.css: .navbar .it.on { background: primary-container }
          color: scheme.primaryContainer.withValues(alpha: selected ? 1 : 0),
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: TtMetrics.navItemGap,
              children: [
                // .ind is as wide as the icon; the badge hangs off its
                // top right corner (tt-style.css: .badge { left: calc(50% +
                // 4px); top: -4px }).
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      size: tt.sizes.icon,
                      color: color,
                      fill: selected ? 1 : 0,
                    ),
                    PositionedDirectional(
                      start: tt.sizes.icon / 2 + TtMetrics.navBadgeOffsetX,
                      top: TtMetrics.navBadgeOffsetY,
                      child: TtCountBadge(count: item.badgeCount),
                    ),
                  ],
                ),
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: TtMetrics.navPillMaxTextScale,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.text.navLabel.copyWith(color: color),
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
