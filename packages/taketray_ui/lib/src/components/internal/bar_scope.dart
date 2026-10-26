import 'package:flutter/widgets.dart';

/// Tells the icon buttons inside a `TtAppBar` whether the bar is in
/// selection mode, where they are drawn without their glass circle and in
/// `onSecondaryContainer` (`.appbar:not(.sel) .ib::before`,
/// `.appbar.sel .ib`).
class TtBarScope extends InheritedWidget {
  /// A scope for [child] in or out of selection mode.
  const new({required this.selection, required super.child, super.key});

  /// Whether the bar is a contextual selection bar.
  final bool selection;

  /// Whether the nearest bar above [context] is in selection mode.
  static bool selectionOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TtBarScope>()?.selection ??
      false;

  @override
  bool updateShouldNotify(TtBarScope oldWidget) =>
      selection != oldWidget.selection;
}
