import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The bar at the bottom of a picking screen: what is picked, on the left in
/// two lines, and the [action] button on the right.
///
/// It has the surface-container colour, a 1 dp line on top, and 16 dp at the
/// sides and 12 dp above and below, plus the system bars' inset below. The
/// two lines wrap at large text and the bar grows with them; the [action]
/// keeps its own size (a `TtButton` is 48 dp high). A screen reader hears the
/// two lines as one node and is told when they change (a live region), so a
/// count that changes is read out.
///
/// Both texts are parameters: the package has no wording of its own. Put the
/// bar in a `Scaffold`'s `bottomNavigationBar`.
class TtBottomBar extends StatelessWidget {
  /// A bar saying [title] and [subtitle], with [action] at its end.
  const new({
    required this.title,
    required this.subtitle,
    required this.action,
    super.key,
  });

  /// The first line, such as "3 videos picked".
  final String title;

  /// The second line, such as "1 min 20 s · added in shooting order".
  final String subtitle;

  /// The button at the end of the bar, usually a `TtButton`.
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .bottombar { padding: 12px 16px; gap: 12px; background:
    // surface-container; border-top: 1px solid outline-variant }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          // 1 px (Flutter's default side width).
          top: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tt.spacing.gutter,
            vertical: tt.spacing.s,
          ),
          child: Row(
            spacing: tt.spacing.s,
            children: [
              Expanded(
                child: Semantics(
                  // The count is read out each time it changes.
                  liveRegion: true,
                  container: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: tt.text.material.titleSmall!.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: tt.text.material.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              action,
            ],
          ),
        ),
      ),
    );
  }
}
