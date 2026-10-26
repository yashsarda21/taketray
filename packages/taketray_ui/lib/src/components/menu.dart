import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/menu_panel.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// One entry of a [TtMenuButton]: a [label] with an optional [icon] that
/// selects [value].
@immutable
class TtMenuItem<T> {
  /// An entry labelled [label] that selects [value].
  const new(this.value, this.label, {this.icon, this.destructive = false});

  /// What `onSelected` receives when the entry is chosen.
  final T value;

  /// The text of the entry.
  final String label;

  /// A glyph before the label, or null for none.
  final IconData? icon;

  /// Whether the entry deletes or discards something (error colour).
  final bool destructive;
}

/// A button that opens a menu of [items].
///
/// [builder] draws the anchor (typically a `TtIconButton`) and receives an
/// `open` callback that toggles the menu. Choosing an item calls
/// [onSelected] with its value and closes the menu; tapping elsewhere closes
/// it without a selection. Built on Material's `MenuAnchor`, so keyboard
/// and screen-reader navigation come with it. The panel is 200 to 300 dp
/// wide with 20 dp corners, and its 48 dp items have 14 dp corners; a long
/// label wraps.
class TtMenuButton<T> extends StatelessWidget {
  /// A menu button showing [items].
  const new({
    required this.items,
    required this.onSelected,
    required this.builder,
    super.key,
  });

  /// The entries, top to bottom.
  final List<TtMenuItem<T>> items;

  /// Called with the value of the chosen item.
  final ValueChanged<T> onSelected;

  /// Builds the anchor; call `open` to open (or close) the menu.
  final Widget Function(BuildContext context, VoidCallback open) builder;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final clear = scheme.surfaceContainer.withValues(alpha: 0);
    // The panel draws itself (TtMenuPanel); MenuAnchor's own surface only
    // casts the shadow, in the panel's shape.
    // tt-style.css: .style-tt .menu { box-shadow: 0 12px 30px -6px … }
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(clear),
      surfaceTintColor: WidgetStatePropertyAll(clear),
      shadowColor: WidgetStatePropertyAll(scheme.shadow),
      elevation: const WidgetStatePropertyAll(TtMetrics.menuElevation),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtMetrics.menuRadius),
        ),
      ),
    );

    return MenuAnchor(
      style: menuStyle,
      menuChildren: [TtMenuPanel<T>(items: items, onSelected: onSelected)],
      builder: (context, controller, _) => builder(
        context,
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
