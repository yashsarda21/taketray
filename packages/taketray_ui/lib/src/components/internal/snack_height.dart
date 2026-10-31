import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// How tall the snack that is showing is, so a floating button can rise
/// above it.
///
/// There is one value for each `ScaffoldMessenger`, because a messenger shows
/// one snack at a time. It is the height of the `TtSnack`'s own panel (not the
/// space around it), and 0 while no snack shows. `TtFab` listens to it by
/// itself; a screen only needs `of` to make room for a snack in some other
/// way. Outside a `ScaffoldMessenger` the value is always 0.
abstract final class TtSnackHeight {
  static final Expando<ValueNotifier<double>> _heights = Expando();
  static final ValueNotifier<double> _none = ValueNotifier<double>(0);

  /// The height of the snack the nearest `ScaffoldMessenger` shows, in dp;
  /// 0 when there is none. Changes when a snack appears, changes size (a
  /// longer message, a larger text scale) or goes.
  static ValueListenable<double> of(BuildContext context) =>
      _notifier(ScaffoldMessenger.maybeOf(context)) ?? _none;

  static ValueNotifier<double>? _notifier(ScaffoldMessengerState? messenger) =>
      messenger == null
      ? null
      : (_heights[messenger] ??= ValueNotifier<double>(0));
}

/// Reports the height of [child] to the messenger's [TtSnackHeight] while
/// it is in the tree, when it is in a snack bar; and 0 when it leaves.
///
/// A `TtSnack` drawn on its own (a catalogue page, a golden) is not a snack
/// that is showing, so it reports nothing.
class SnackHeightReporter extends SingleChildRenderObjectWidget {
  /// Reports the height of [child].
  const new({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) {
    final inSnackBar =
        context.findAncestorWidgetOfExactType<SnackBar>() != null;
    return _RenderReporter(
      inSnackBar
          ? TtSnackHeight._notifier(ScaffoldMessenger.maybeOf(context))
          : null,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final inSnackBar =
        context.findAncestorWidgetOfExactType<SnackBar>() != null;
    (renderObject as _RenderReporter).target = inSnackBar
        ? TtSnackHeight._notifier(ScaffoldMessenger.maybeOf(context))
        : null;
  }

  @override
  void didUnmountRenderObject(RenderObject renderObject) {
    (renderObject as _RenderReporter).leave();
  }
}

class _RenderReporter extends RenderProxyBox {
  new(this.target);

  /// Which reporter spoke last for each notifier. A snack that is replaced
  /// by the next one goes after the next one has measured itself, and must
  /// not reset the height the next one reported.
  static final Expando<_RenderReporter> _owners = Expando();

  ValueNotifier<double>? target;
  double _reported = 0;

  @override
  void performLayout() {
    super.performLayout();
    final notifier = target;
    if (notifier == null) return;
    _owners[notifier] = this;
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    _publish(notifier, height);
  }

  /// The snack is gone: the lift goes back to 0, unless another snack has
  /// taken over.
  void leave() {
    final notifier = target;
    if (notifier == null) return;
    _reported = 0;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (identical(_owners[notifier], this) && notifier.value != 0) {
        notifier.value = 0;
      }
    });
  }

  // Layout is in the middle of a frame; the listeners (the FAB) rebuild after
  // it.
  void _publish(ValueNotifier<double> notifier, double height) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (identical(_owners[notifier], this) && notifier.value != height) {
        notifier.value = height;
      }
    });
  }
}
