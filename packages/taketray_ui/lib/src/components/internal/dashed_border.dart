import 'package:flutter/widgets.dart';

/// Strokes a dashed rounded-rectangle outline just inside its bounds.
///
/// The outline is [width] thick, drawn as dashes [dash] long with [gap]
/// between them, along a rounded rectangle whose corners are [radius] (the
/// radius of the box it surrounds). Use it as a `CustomPaint`'s
/// `foregroundPainter`. It repaints only when one of its values changes.
class DashedBorderPainter extends CustomPainter {
  /// A dashed outline in [color] around a box with corners of [radius].
  const new({
    required this.color,
    required this.radius,
    required this.width,
    required this.dash,
    required this.gap,
  });

  /// The colour of the dashes.
  final Color color;

  /// The corner radius of the box the outline surrounds.
  final double radius;

  /// How thick the line is.
  final double width;

  /// How long each dash is, measured along the outline.
  final double dash;

  /// How long the space between two dashes is.
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(width / 2),
          Radius.circular(radius - width / 2),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, at + dash), paint);
        at += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.width != width ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}
