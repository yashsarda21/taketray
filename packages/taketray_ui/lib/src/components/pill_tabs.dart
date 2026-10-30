import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// One tab of a [TtPillTabs]: the [value] it stands for and its [label].
class TtPillTab<T> {
  /// A tab for [value] showing [label]; a screen reader says [semanticLabel]
  /// instead when it is given.
  const new(this.value, this.label, {this.semanticLabel});

  /// What [TtPillTabs.onChanged] receives when this tab is tapped.
  final T value;

  /// The text on the tab; one line.
  final String label;

  /// What a screen reader says instead of [label], or null to say [label].
  final String? semanticLabel;
}

/// A horizontal scroller of single-select pill tabs.
///
/// The selected tab is `inverseSurface`, the others `surfaceContainerHigh`.
/// Each tab is 36 dp tall (more at large text) with a 48 dp tap target, and
/// only the selected one is announced as selected. A [value] that no tab has
/// selects none.
///
/// With [wrapAtLargeText] the tabs wrap onto more rows from a text scale of
/// 1.5 instead of scrolling sideways, for a short fixed set (the date range
/// picker's quick ranges) that must all stay in view.
class TtPillTabs<T> extends StatelessWidget {
  /// Tabs for [tabs] with [value] selected, calling [onChanged] with the
  /// tapped tab's value.
  const new({
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.wrapAtLargeText = false,
    super.key,
  });

  /// Whether the tabs wrap instead of scrolling from a text scale of
  /// [TtMetrics.largeTextScale].
  final bool wrapAtLargeText;

  /// The tabs, in order.
  final List<TtPillTab<T>> tabs;

  /// The value of the selected tab.
  final T value;

  /// Called with the value of the tapped tab.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // tt-style.css: .style-tt .fchip, .style-tt .fchip.on
    final label = tt.text.numeric(tt.text.material.labelLarge!);
    Widget tab(int i) => _PillTab(
      label: tabs[i].label,
      semanticLabel: tabs[i].semanticLabel,
      selected: tabs[i].value == value,
      fill: tabs[i].value == value
          ? scheme.inverseSurface
          : scheme.surfaceContainerHigh,
      textStyle: label.copyWith(
        color: tabs[i].value == value
            ? scheme.onInverseSurface
            : scheme.onSurfaceVariant,
      ),
      onPressed: () => onChanged(tabs[i].value),
    );
    final wrap =
        wrapAtLargeText &&
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    if (wrap) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tt.spacing.gutter,
          vertical: tt.spacing.xxs,
        ),
        child: Wrap(
          spacing: tt.spacing.xs,
          children: [for (var i = 0; i < tabs.length; i++) tab(i)],
        ),
      );
    }
    // Align: shrink to the tabs' height even where the parent is tight.
    return Align(
      heightFactor: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: tt.spacing.gutter,
          vertical: tt.spacing.xxs,
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) SizedBox(width: tt.spacing.xs),
              tab(i),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const new({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.fill,
    required this.textStyle,
    required this.onPressed,
  });

  final String label;
  final String? semanticLabel;
  final bool selected;
  final Color fill;
  final TextStyle textStyle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _ChipTapTarget(
      label: semanticLabel ?? label,
      selected: selected,
      onPressed: onPressed,
      child: Material(
        color: fill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TtMetrics.pillTabHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TtMetrics.pillTabPaddingHorizontal,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed-outline chip that suggests something to add, such as an idea for
/// a reel name.
///
/// 36 dp tall with a 48 dp tap target. Shows a plus before the label.
class TtSuggestionChip extends StatelessWidget {
  /// A chip showing [label] that calls [onPressed] when tapped.
  const new({required this.label, required this.onPressed, super.key});

  /// The suggestion; one line, with an ellipsis if too long.
  final String label;

  /// Called when the chip is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // tt-style.css: .style-tt .sugg .fchip
    return _ChipTapTarget(
      label: label,
      onPressed: onPressed,
      child: CustomPaint(
        foregroundPainter: _DashedStadiumPainter(color: scheme.outlineVariant),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TtMetrics.pillTabHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TtMetrics.pillTabPaddingHorizontal,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: scheme.onSurfaceVariant,
                    size: tt.sizes.iconSmall,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.add_rounded),
                      const SizedBox(width: TtMetrics.pillTabIconGap),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.text.material.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gives a chip button semantics and a 48 dp tall tap target around it.
class _ChipTapTarget extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    required this.child,
    this.selected,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      selected: selected,
      label: label,
      onTap: onPressed,
      // The chip is shorter than the target; a tap in the margin above or
      // below it still counts.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: context.tt.sizes.touchTarget,
            minHeight: context.tt.sizes.touchTarget,
          ),
          child: Center(heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// Strokes a dashed stadium outline just inside its bounds.
class _DashedStadiumPainter extends CustomPainter {
  const new({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const width = TtMetrics.suggestionBorderWidth;
    final path = const StadiumBorder().getOuterPath(
      (Offset.zero & size).deflate(width / 2),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(
          metric.extractPath(at, at + TtMetrics.suggestionDashLength),
          paint,
        );
        at += TtMetrics.suggestionDashLength + TtMetrics.suggestionDashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadiumPainter oldDelegate) =>
      oldDelegate.color != color;
}
