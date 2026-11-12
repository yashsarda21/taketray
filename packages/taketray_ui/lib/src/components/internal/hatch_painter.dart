import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Fills its area with diagonal stripes: stripes of [color] alternating with
/// stripes of [color] at [shade] opacity, each [stripe] thick.
///
/// This is the CSS `repeating-linear-gradient(45deg, c 0 6px, c70% 6px 12px)`
/// of the storage bar's shortfall: the colour changes along a line that runs
/// from the bottom left corner to the top right, so the stripes themselves
/// run from the top left down to the bottom right, starting at the bottom left
/// corner. Use it as a `CustomPaint`'s painter; it repaints only when one of
/// its values changes.
class HatchPainter extends CustomPainter {
  /// A hatch of [color] with stripes [stripe] wide.
  const new({required this.color, required this.stripe, required this.shade});

  /// The colour of the first stripe of each pair.
  final Color color;

  /// The width of a stripe, measured along the horizontal edge.
  final double stripe;

  /// The opacity of [color] in the second stripe of each pair, 0 to 1.
  final double shade;

  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()..color = color;
    final shaded = Paint()..color = color.withValues(alpha: shade);
    // The gradient line passes through the centre of the area; its length is
    // |w sin a| + |h cos a| for 45 degrees: (w + h) / sqrt2.
    final length = (size.width + size.height) / math.sqrt2;
    final pairs = (length / (2 * stripe)).ceil();
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(size.width / 2, size.height / 2)
      // Rotate so the gradient axis is the x axis: up and to the right.
      ..rotate(-math.pi / 4);
    for (var i = 0; i < pairs; i++) {
      // Each pair in axis coordinates from the start of the line at
      // -length / 2: a stripe of the colour, then one of its shade.
      final start = -length / 2 + 2 * i * stripe;
      canvas
        ..drawRect(Rect.fromLTWH(start, -length, stripe, 2 * length), solid)
        ..drawRect(
          Rect.fromLTWH(start + stripe, -length, stripe, 2 * length),
          shaded,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HatchPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.stripe != stripe ||
      oldDelegate.shade != shade;
}
