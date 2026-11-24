import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/menu_panel.dart';
import 'package:taketray_ui/src/components/internal/menu_route.dart';

/// One entry of a [TtMenuButton]: a [label] with an optional [icon] that
/// selects [value].
///
/// A [subtitle] makes the entry two lines (60 dp high), and a [checked] makes
/// it one of a set of choices, as the status menu of a reel is.
@immutable
class TtMenuItem<T> {
  /// An entry labelled [label] that selects [value].
  const new(
    this.value,
    this.label, {
    this.icon,
    this.iconFilled = false,
    this.destructive = false,
    this.subtitle,
    this.checked,
  });

  /// What `onSelected` receives when the entry is chosen.
  final T value;

  /// The text of the entry.
  final String label;

  /// A glyph before the label, or null for none.
  final IconData? icon;

  /// Whether [icon] is drawn in its filled variant.
  final bool iconFilled;

  /// Whether the entry deletes or discards something (error colour).
  final bool destructive;

  /// A smaller line under the label, such as "Still shooting clips for it";
  /// null for none.
  final String? subtitle;

  /// Whether this is the current one of a set of choices (a screen reader
  /// calls it a radio menu item, checked or not), or null for an entry that
  /// is not a choice. The checked one is drawn on `secondaryContainer` with a
  /// check after the label.
  final bool? checked;
}

/// A button that opens a menu of [items].
///
/// [builder] draws the anchor (typically a `TtIconButton`) and receives an
/// `open` callback that opens the menu (and does nothing while it is open).
/// Choosing an item closes the menu and then calls [onSelected] with its
/// value, once; tapping elsewhere, Android back or Escape closes it without
/// a selection. The menu is a route on the root navigator (D-176), so the
/// whole page behind it is blurred by 3 dp (not dimmed), Back closes it
/// before the page, keyboard and screen-reader navigation work as in a
/// dialog, and it counts as an open popup. The panel is 200 to 300 dp wide
/// with 20 dp corners, and its 48 dp items have 14 dp corners; a long label
/// wraps.
class TtMenuButton<T> extends StatefulWidget {
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

  /// Builds the anchor; call `open` to open the menu.
  final Widget Function(BuildContext context, VoidCallback open) builder;

  @override
  State<TtMenuButton<T>> createState() => _TtMenuButtonState<T>();
}

class _TtMenuButtonState<T> extends State<TtMenuButton<T>> {
  /// The open menu, or null.
  TtMenuRoute<T>? _route;

  Future<void> _open() async {
    // A second open while it is open does nothing.
    if (_route != null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlay = navigator.context.findRenderObject();
    final box = context.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;

    late final TtMenuRoute<T> route;
    route = TtMenuRoute<T>(
      anchor: anchor,
      textDirection: Directionality.of(context),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierLabel: MaterialLocalizations.of(context).menuDismissLabel,
      builder: (menuContext) => TtMenuPanel<T>(
        items: widget.items,
        onSelected: (value) {
          // A second tap before the frame that removes the menu does not
          // pop the page under it.
          if (route.isCurrent) Navigator.pop(menuContext, (value: value));
        },
      ),
    );
    _route = route;
    final chosen = await navigator.push(route);
    _route = null;
    // Nothing is selected when the anchor went away meanwhile.
    if (chosen != null && mounted) widget.onSelected(chosen.value);
  }

  @override
  void dispose() {
    // The page under the menu went away: close the menu too, after this
    // frame (a navigator cannot change while the tree is being torn down).
    final route = _route;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _open);
}
