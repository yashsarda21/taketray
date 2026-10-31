import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:taketray_ui/src/components/internal/menu_panel.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

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
/// `open` callback that toggles the menu. Choosing an item calls
/// [onSelected] with its value and closes the menu; tapping elsewhere closes
/// it without a selection. Built on Material's `MenuAnchor`, so keyboard
/// and screen-reader navigation come with it. The panel is 200 to 300 dp
/// wide with 20 dp corners, and its 48 dp items have 14 dp corners; a long
/// label wraps.
///
/// While the menu is open, Android back closes it instead of leaving the
/// screen (a `PopScope` with `canPop: false`, so it works under any
/// `Navigator` or `Router`).
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

  /// Builds the anchor; call `open` to open (or close) the menu.
  final Widget Function(BuildContext context, VoidCallback open) builder;

  @override
  State<TtMenuButton<T>> createState() => _TtMenuButtonState<T>();
}

class _TtMenuButtonState<T> extends State<TtMenuButton<T>> {
  final MenuController _controller = MenuController();
  bool _open = false;

  void _setOpen({required bool open}) {
    if (mounted && _open != open) setState(() => _open = open);
  }

  /// MenuAnchor closes an open menu from inside a build when the window
  /// changes size, and `setState` is not allowed there (a debug-only assert).
  /// In a build the change waits for the end of the frame.
  void _setOpenSafely({required bool open}) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _setOpen(open: open),
      );
    } else {
      _setOpen(open: open);
    }
  }

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

    return PopScope(
      // Back closes an open menu first; the page underneath stays.
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.close();
      },
      child: MenuAnchor(
        controller: _controller,
        style: menuStyle,
        onOpen: () => _setOpenSafely(open: true),
        onClose: () => _setOpenSafely(open: false),
        menuChildren: [
          TtMenuPanel<T>(items: widget.items, onSelected: widget.onSelected),
        ],
        builder: (context, controller, _) => widget.builder(
          context,
          () => controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}
