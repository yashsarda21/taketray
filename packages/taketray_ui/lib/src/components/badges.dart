import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A "clips waiting" count in the marigold waiting colours.
///
/// Draws nothing at 0 or below, the number up to 99 and "99+" above. A ring
/// in the surface colour separates it from what it sits on.
class TtCountBadge extends StatelessWidget {
  /// A badge showing [count].
  const new({required this.count, super.key});

  /// How many; the badge is hidden at 0 or below.
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final tt = context.tt;
    final label = count > 99 ? '99+' : '$count';
    // proto.css: .badge { font: 700 11.5px/18px … }
    final style = tt.text
        .numeric(tt.text.navLabel)
        .copyWith(
          color: tt.colors.onWaiting,
          fontWeight: FontWeight.w700,
          fontVariations: const [
            FontVariation('wght', TtMetrics.badgeFontWeight),
          ],
        );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tt.colors.waiting,
        shape: const StadiumBorder(),
        // tt-style.css: .style-tt .badge { box-shadow: 0 0 0 2px … }
        shadows: [
          BoxShadow(
            color: context.scheme.surfaceContainerHigh,
            spreadRadius: TtMetrics.badgeRingWidth,
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: TtMetrics.badgeMinWidth,
          minHeight: TtMetrics.badgeMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TtMetrics.badgePaddingHorizontal,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            // Not in the prototype: decorative overlay. The number stops
            // growing at TtMetrics.badgeMaxTextScale so the badge does not
            // cover the icon it sits on at large text.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: TtMetrics.badgeMaxTextScale,
              child: Text(label, maxLines: 1, softWrap: false, style: style),
            ),
          ),
        ),
      ),
    );
  }
}
