import 'dart:math' as math;
import 'dart:ui';

import 'package:meta/meta.dart';

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

  /// What the look measured, for a test's log: pixel rectangles
  /// (left, top, right, bottom), and for each button how far below TakeTray's
  /// text it starts (the gap `ownButton` limits to one button height) and how
  /// far its centre is from the nearest sibling's (the row). Numbers only,
  /// never a text.
  String get numbers {
    String r(Rect v) =>
        '${v.left.round()},${v.top.round()},${v.right.round()},'
        '${v.bottom.round()}';
    String all(Iterable<Rect> v) => '[${v.map(r).join('; ')}]';
    final anchor = anchors.isEmpty ? null : anchors.first;
    final gaps = anchor == null
        ? 'none'
        : buttons.isEmpty
        ? 'none'
        : buttons.map((b) => (b.top - anchor.bottom).round()).join(' ');
    final rows = buttons.isEmpty || siblings.isEmpty
        ? 'none'
        : buttons
              .map(
                (b) => siblings
                    .map((s) => (s.center.dy - b.center.dy).abs())
                    .reduce(math.min)
                    .round(),
              )
              .join(' ');
    return 'text ${all(anchors)}, buttons ${all(buttons)}, '
        'siblings ${all(siblings)}, gap below the text $gaps, '
        'row offset $rows';
  }
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

/// The phone's default display as `TestBackground.display` reads it at tap
/// time: `Display.getRealSize` (the whole display in its current rotation,
/// in the pixels the shade's views and uiautomator's `tapAt` use) and
/// `Display.getRotation` (0 is upright). Numbers only.
@immutable
class PhoneDisplay {
  const PhoneDisplay({
    required this.width,
    required this.height,
    required this.rotation,
  });

  /// The hook's reply, `{width, height, rotation}`; null for anything else
  /// (an unknown size never becomes a guess).
  static PhoneDisplay? fromReply(Object? reply) {
    if (reply is! Map) return null;
    final width = reply['width'];
    final height = reply['height'];
    final rotation = reply['rotation'];
    if (width is! int || height is! int || rotation is! int) return null;
    return PhoneDisplay(width: width, height: height, rotation: rotation);
  }

  final int width;
  final int height;
  final int rotation;

  @override
  bool operator ==(Object other) =>
      other is PhoneDisplay &&
      other.width == width &&
      other.height == height &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(width, height, rotation);
}

/// Where to tap TakeTray's own button: the centre of the button that [first]
/// and [second] (two looks, the second just before the tap) both find, as a
/// fraction of the real [display] read at tap time (Patrol's `tapAt`
/// multiplies it back by `UiDevice.getDisplayWidth/Height`, which is
/// `Display.getRealSize` too).
///
/// Null, so that nothing is tapped, unless all of these hold:
/// - the size was read ([display] is not null) and is not empty;
/// - the phone is upright: rotation 0 and taller than wide (the shade and
///   the launcher are portrait; a rotated phone is refused rather than
///   reasoned about);
/// - the real size is Flutter's display size [flutterDisplay] in either
///   orientation, within a pixel (the same display, the same pixels; Flutter's
///   own orientation may be stale from before the app went to the background,
///   so only the two numbers are compared);
/// - every view of both looks lies inside the real display;
/// - both looks find the same own text and button (`ownButton`).
Offset? ownButtonTapPoint({
  required ShadeLook first,
  required ShadeLook second,
  required PhoneDisplay? display,
  required Size flutterDisplay,
}) {
  if (display == null) return null;
  final width = display.width.toDouble();
  final height = display.height.toDouble();
  if (width <= 0 || height <= 0) return null;
  if (display.rotation != 0 || height <= width) return null;
  // The same two numbers, whichever way round each side holds them.
  final flutterShort = math.min(flutterDisplay.width, flutterDisplay.height);
  final flutterLong = math.max(flutterDisplay.width, flutterDisplay.height);
  if ((flutterShort - math.min(width, height)).abs() >= 1 ||
      (flutterLong - math.max(width, height)).abs() >= 1) {
    return null;
  }
  final screen = Rect.fromLTWH(0, 0, width, height);
  final inside = [...first._all, ...second._all].every(
    (r) =>
        r.left >= screen.left &&
        r.top >= screen.top &&
        r.right <= screen.right &&
        r.bottom <= screen.bottom,
  );
  if (!inside) return null;
  final a = _own(first);
  final b = _own(second);
  if (a == null || b == null || a != b) return null;
  final centre = a.button.center;
  return Offset(centre.dx / width, centre.dy / height);
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
