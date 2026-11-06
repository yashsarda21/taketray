import 'dart:math' as math;
import 'dart:ui';

/// One look at the open shade: the screen bounds (in the real display's
/// pixels) of the views that carry each of three exact texts. Nothing here
/// holds or reads any text.
class ShadeLook {
  const ShadeLook({
    required this.anchors,
    required this.buttons,
    required this.siblings,
  });

  /// The views with TakeTray's own notification text (`OwnText`).
  final List<Rect> anchors;

  /// The views with the label of the button to tap ("Turn off").
  final List<Rect> buttons;

  /// The views with the label of the button next to it ("Keep on").
  final List<Rect> siblings;

  Iterable<Rect> get _all => [...anchors, ...buttons, ...siblings];
}

/// Which of [ShadeLook.buttons] (every "Turn off" in the shade) is the button
/// of TakeTray's own notification, or null when that is not certain.
///
/// It is ours only when all of these hold; otherwise nothing is tapped and the
/// test fails (the phone rule: never touch another app's notification):
/// - exactly one view has TakeTray's text (two would leave it unclear whose
///   button it is; the same view reported twice counts once);
/// - the button sits below the middle of that text, and its top is no
///   further below the text's bottom than its own height: the action row of
///   the same notification, not a row of the notification under it, which
///   starts with that notification's header and title;
/// - a separate sibling ("Keep on") is on the same row (the vertical centres
///   closer than half the smaller height), not overlapping it;
/// - it is not empty, and no other button fits as well.
Rect? ownButton(ShadeLook look) => _own(look)?.button;

/// Where to tap TakeTray's own button: the centre of the button that [first]
/// and [second] (two looks, the second just before the tap) both find, as a
/// fraction of the [screen] (Patrol's `tapAt` multiplies it back by the real
/// display size, `UiDevice.getDisplayWidth/Height`).
///
/// Null, so that nothing is tapped, when either look finds no own button,
/// when the two disagree (the shade was still moving), when the screen has
/// no size, or when a view lies outside the screen (the sizes are not in the
/// same pixels, so the fraction would land somewhere else).
Offset? ownButtonTapPoint({
  required ShadeLook first,
  required ShadeLook second,
  required Size screen,
}) {
  if (screen.isEmpty) return null;
  final display = Offset.zero & screen;
  final inside = [...first._all, ...second._all].every(
    (r) =>
        r.left >= display.left &&
        r.top >= display.top &&
        r.right <= display.right &&
        r.bottom <= display.bottom,
  );
  if (!inside) return null;
  final a = _own(first);
  final b = _own(second);
  if (a == null || b == null || a != b) return null;
  final centre = a.button.center;
  return Offset(centre.dx / screen.width, centre.dy / screen.height);
}

({Rect anchor, Rect button})? _own(ShadeLook look) {
  final anchors = look.anchors.toSet();
  if (anchors.length != 1) return null;
  final anchor = anchors.single;
  final fits = <Rect>[
    for (final button in look.buttons.toSet())
      if (!button.isEmpty &&
          button.top >= anchor.center.dy &&
          button.top - anchor.bottom <= button.height &&
          look.siblings.any(
            (s) =>
                !s.isEmpty &&
                !s.overlaps(button) &&
                (s.center.dy - button.center.dy).abs() <
                    math.min(s.height, button.height) / 2,
          ))
        button,
  ];
  return fits.length == 1 ? (anchor: anchor, button: fits.single) : null;
}
