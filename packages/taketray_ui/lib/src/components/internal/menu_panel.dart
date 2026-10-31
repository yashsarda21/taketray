import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_symbols_icons/symbols.dart';
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
    // .mi.on (the checked choice) is secondary-container; .mi.tall (one with
    // a subtitle) is 60 dp.
    ButtonStyle itemStyle(TtMenuItem<T> item) => ButtonStyle(
      backgroundColor: item.checked ?? false
          ? WidgetStatePropertyAll(scheme.secondaryContainer)
          : null,
      foregroundColor: WidgetStatePropertyAll(
        item.destructive
            ? scheme.error
            : item.checked ?? false
            ? scheme.onSecondaryContainer
            : scheme.onSurface,
      ),
      iconColor: WidgetStatePropertyAll(
        item.destructive ? scheme.error : scheme.onSurfaceVariant,
      ),
      textStyle: WidgetStatePropertyAll(tt.text.material.labelLarge),
      // The item fills the menu (`.mi { width: 100% }`), inside its padding.
      minimumSize: WidgetStatePropertyAll(
        Size(
          TtMetrics.menuMinWidth - 2 * TtMetrics.menuPadding,
          item.subtitle == null
              ? tt.sizes.touchTarget
              : TtMetrics.menuItemTallHeight,
        ),
      ),
      maximumSize: const WidgetStatePropertyAll(
        Size(
          TtMetrics.menuMaxWidth - 2 * TtMetrics.menuPadding,
          double.infinity,
        ),
      ),
      // A two-line item keeps some air above and below at large text, where
      // it grows past its 60 dp.
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: TtMetrics.menuItemPaddingHorizontal,
          vertical: item.subtitle == null ? 0 : tt.spacing.xs,
        ),
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
                for (final (index, item) in items.indexed)
                  MenuItemButton(
                    key: ValueKey('tt-menu-item-$index'),
                    style: itemStyle(item),
                    // Wrap a long label (what an open MenuAnchor sets too).
                    overflowAxis: Axis.vertical,
                    leadingIcon: item.icon == null
                        ? null
                        : Icon(item.icon, fill: item.iconFilled ? 1 : null),
                    trailingIcon: item.checked ?? false
                        ? const Icon(Symbols.check_rounded)
                        : null,
                    onPressed: () => onSelected(item.value),
                    child: _ItemText(item: item),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The label of a menu entry, over its subtitle when it has one. A choice
/// (`checked` not null) is announced as a radio menu item.
class _ItemText<T> extends StatelessWidget {
  const new({required this.item});

  final TtMenuItem<T> item;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.subtitle;
    final checked = item.checked;
    final label = Text(item.label);
    final text = subtitle == null
        ? label
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              // proto.css: .menu .mi .sub
              Text(
                subtitle,
                style: context.tt.text.material.bodySmall!.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
    if (checked == null) return text;
    return Semantics(
      role: SemanticsRole.menuItemRadio,
      checked: checked,
      inMutuallyExclusiveGroup: true,
      child: text,
    );
  }
}
