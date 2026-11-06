import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A card that opens and closes: a header with a [title], an optional [badge]
/// and an arrow, and, while [expanded], the [child] under the header.
///
/// It is 16 dp round on the low surface container and has no outer margin
/// (the page decides). The header is at least 56 dp high and takes the whole
/// card width as its tap target; the title wraps at large text, and from a
/// text scale of 1.5 the badge moves under the title. The body sits
/// under the header with 16 dp at the sides and the bottom, in body medium.
/// A collapsed card does not build its body at all.
///
/// The card does not keep its own state: the caller holds [expanded] and
/// flips it in [onToggle]. A screen reader hears one button, labelled with the
/// [title] and the [badge] ("Samsung, Your phone") and reported as expanded or
/// collapsed.
class TtExpandCard extends StatelessWidget {
  /// A card headed [title], showing [child] while [expanded].
  const new({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.badge,
    super.key,
  });

  /// The header text, such as a phone brand.
  final String title;

  /// A small label after the title, such as "Your phone", or null.
  final String? badge;

  /// Whether [child] is shown.
  final bool expanded;

  /// Called when the header is tapped.
  final VoidCallback onToggle;

  /// The body, built only while [expanded].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final badge = this.badge;
    // proto.css: .acc, .acc .ah, .acc .ab, .acc .you
    final titleText = Text(
      title,
      style: text.titleSmall!.copyWith(color: scheme.onSurface),
    );
    final badgeChip = badge == null
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(
                TtMetrics.expandCardBadgeRadius,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tt.spacing.xs,
                vertical: TtMetrics.expandCardBadgePaddingVertical,
              ),
              child: Text(
                badge,
                style: text.labelMedium!.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
          );
    // Beside the title the badge would squeeze it to a few letters per line
    // at large text, so it moves under the title (not in the prototype, which
    // has no text scaling).
    final badgeBelow =
        badgeChip != null &&
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(tt.radii.l),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            expanded: expanded,
            label: [title, ?badge].join(', '),
            onTap: onToggle,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TtMetrics.expandCardHeaderMinHeight,
                ),
                child: Padding(
                  // The prototype has no vertical padding; a title that wraps
                  // at large text would touch the card's edge without it.
                  padding: EdgeInsetsDirectional.fromSTEB(
                    tt.spacing.m,
                    tt.spacing.xs,
                    tt.spacing.s,
                    tt.spacing.xs,
                  ),
                  child: Row(
                    spacing: tt.spacing.s,
                    children: [
                      Expanded(
                        child: badgeBelow
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                spacing: tt.spacing.xs,
                                children: [titleText, badgeChip],
                              )
                            : titleText,
                      ),
                      if (badgeChip != null && !badgeBelow) badgeChip,
                      Icon(
                        expanded
                            ? Symbols.expand_less_rounded
                            : Symbols.expand_more_rounded,
                        size: tt.sizes.icon,
                        color: scheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                tt.spacing.m,
                tt.spacing.none,
                tt.spacing.m,
                tt.spacing.m,
              ),
              child: DefaultTextStyle.merge(
                style: text.bodyMedium!.copyWith(color: scheme.onSurface),
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}
