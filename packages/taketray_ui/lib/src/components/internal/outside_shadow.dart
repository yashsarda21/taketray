import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints [shadows] of a rounded box, and only outside the box (D-175).
///
/// A `BoxShadow` on a `DecoratedBox` is drawn under the whole box, so it shows
/// through a translucent fill: under the nav pill's 78 % glass it darkened the
/// pill's inside. CSS `box-shadow` is not painted inside the border box. This
/// painter draws each shadow as `BoxShadow.toPaint()` would, as the box's
/// rounded rectangle moved by `offset` and grown by `spreadRadius`, but with
/// the canvas clipped to everything around the box's own rounded rectangle.
///
/// Put it as the `painter` of a `CustomPaint` whose child is the box, so the
/// painter's size is the box's and the child draws over it.
///
/// The clip's path (a combined path, costly to build) is kept for the size it
/// was built for and built again only when the size changes; the shadows and
/// the corners are final, so a change in them makes a new painter.
class OutsideShadowPainter extends CustomPainter {
  /// A painter for the box of [borderRadius] corners, casting [shadows].
  new({required this.shadows, required this.borderRadius});

  /// The shadows, painted first to last (the first ends up underneath).
  final List<BoxShadow> shadows;

  /// The box's corners.
  final BorderRadius borderRadius;

  Size? _outsideSize;
  late Path _outside;
  int _builds = 0;

  /// How many times the clip's path has been built (for tests).
  @visibleForTesting
  int get outsidePathBuilds => _builds;

  /// Everything around the box of [size]. It reaches far enough out that no
  /// shadow is cut off by the clip's outer edge: a blur reaches about 2 sigma
  /// = blurRadius from its shape. Kept for the last size it was built for.
  Path _outsideOf(Size size, RRect box) {
    if (_outsideSize == size) return _outside;
    var reach = 0.0;
    for (final shadow in shadows) {
      reach = math.max(
        reach,
        2 * shadow.blurRadius +
            shadow.offset.distance +
            shadow.spreadRadius.abs(),
      );
    }
    _builds++;
    _outsideSize = size;
    return _outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(box.outerRect.inflate(reach)),
      Path()..addRRect(box),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final box = borderRadius.toRRect(Offset.zero & size);
    canvas
      ..save()
      ..clipPath(_outsideOf(size, box));
    for (final shadow in shadows) {
      canvas.drawRRect(
        box.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OutsideShadowPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      !listEquals(oldDelegate.shadows, shadows);
}
