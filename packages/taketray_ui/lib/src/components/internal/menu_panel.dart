import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/menu.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The drawn panel of an open `TtMenuButton`: [items] as 48 dp menu entries
/// on a rounded, hairlined surface.
///
/// Not exported: `TtMenuButton` shows it in its menu, and the golden test
/// draws it directly (a menu's overlay cannot be captured in a golden).
class TtMenuPanel<T> extends StatelessWidget {
  /// A panel listing [items]; choosing one calls [onSelected] with its value.
  const new({required this.items, required this.onSelected, super.key});

  /// The entries, top to bottom.
  final List<TtMenuItem<T>> items;

  /// Called with the value of the chosen item.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final radius = BorderRadius.circular(TtMetrics.menuRadius);

    // proto.css: .menu .mi (48 dp, label-large, 16 dp sides, 12 dp gap, icon
    // in the variant colour), .mi.danger (error); tt-style: radius 14.
    ButtonStyle itemStyle(TtMenuItem<T> item) => ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(
        item.destructive ? scheme.error : scheme.onSurface,
      ),
      iconColor: WidgetStatePropertyAll(
        item.destructive ? scheme.error : scheme.onSurfaceVariant,
      ),
      textStyle: WidgetStatePropertyAll(tt.text.material.labelLarge),
      // The item fills the menu (`.mi { width: 100% }`), inside its padding.
      minimumSize: WidgetStatePropertyAll(
        Size(
          TtMetrics.menuMinWidth - 2 * TtMetrics.menuPadding,
          tt.sizes.touchTarget,
        ),
      ),
      maximumSize: const WidgetStatePropertyAll(
        Size(
          TtMetrics.menuMaxWidth - 2 * TtMetrics.menuPadding,
          double.infinity,
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: TtMetrics.menuItemPaddingHorizontal),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtMetrics.menuItemRadius),
        ),
      ),
    );

    // tt-style.css: .style-tt .menu { border-radius: 20px; padding: 6px;
    // inset 0 0 0 1px hair }. The shadow is the menu's elevation, drawn by
    // `MenuAnchor` outside the panel (its scroll view clips the panel).
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TtMetrics.menuMinWidth,
        maxWidth: TtMetrics.menuMaxWidth,
      ),
      child: Material(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tt.colors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(TtMetrics.menuPadding),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  MenuItemButton(
                    style: itemStyle(item),
                    // Wrap a long label (what an open MenuAnchor sets too).
                    overflowAxis: Axis.vertical,
                    leadingIcon: item.icon == null ? null : Icon(item.icon),
                    onPressed: () => onSelected(item.value),
                    child: Text(item.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
