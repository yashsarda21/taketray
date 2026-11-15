import 'dart:math' as math;

import 'package:flutter/material.dart';

// The launcher icon's own colours: the graphite palette of the app icon
// (`design/handoff/icons/tray/ic_launcher_{background,foreground}.svg`). They
// are the brand's, not a theme's, so they are the same in light and dark.
// style-check: allow the launcher icon's brand colours, not theme colours
const Color _background = Color(0xFF516072);
// style-check: allow the launcher icon's brand colours, not theme colours
const Color _backClip = Color(0xFFB8C8DD);
// style-check: allow the launcher icon's brand colours, not theme colours
const Color _frontClip = Color(0xFFFFFFFF);
// style-check: allow the launcher icon's brand colours, not theme colours
const Color _trayBody = Color(0xFFFFB952);
// style-check: allow the launcher icon's brand colours, not theme colours
const Color _trayRim = Color(0xFFE89B00);

/// The TakeTray launcher icon in a circle: the tray with two takes standing
/// in it, on the graphite background (`h.brandIcon(size, 'tray', 'circle')` of
/// the prototype).
///
/// Painted from the paths of `ic_launcher_foreground.svg` (a 108 x 108
/// viewport) and the colour of `ic_launcher_background.svg`, so it is the
/// same picture as the icon on the home screen. It is a decoration: the
/// wordmark or the screen's text beside it says "TakeTray", so a screen
/// reader skips it. It keeps its [size] at large text.
class TtBrandMark extends StatelessWidget {
  /// The mark, [size] dp across.
  const new({required this.size, super.key})
    : assert(size >= 0, 'A size is not negative');

  /// Width and height in dp.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _BrandMarkPainter()),
    ),
  );
}

/// The launcher icon's viewport is 108 x 108.
// style-check: allow the icon's own viewport, from the SVG
const double _viewport = 108;

class _BrandMarkPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas
      ..save()
      ..scale(size.width / _viewport, size.height / _viewport)
      // The circle mask, then the background.
      ..clipPath(
        Path()..addOval(
          Rect.fromCircle(
            center: const Offset(_viewport / 2, _viewport / 2),
            radius: _viewport / 2,
          ),
        ),
      )
      ..drawRect(
        const Rect.fromLTWH(0, 0, _viewport, _viewport),
        Paint()..color = _background,
      );

    // The back take, leaning left: rotate(-12 52 47).
    _rotated(canvas, -12, const Offset(52, 47), () {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(40, 28, 64, 66),
          // style-check: allow the icon's own path geometry (the SVG's 4 / 4.5 / 0.8)
          const Radius.circular(4),
        ),
        Paint()..color = _backClip,
      );
    });

    // The front take and its play mark, leaning right: rotate(7 61 52).
    _rotated(canvas, 7, const Offset(61, 52), () {
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(48, 32, 74, 72),
            // style-check: allow the icon's own path geometry (the SVG's 4 / 4.5 / 0.8)
            const Radius.circular(4.5),
          ),
          Paint()..color = _frontClip,
        )
        ..drawPath(
          Path()
            ..moveTo(57, 45.5)
            ..lineTo(67, 52)
            ..lineTo(57, 58.5)
            ..close(),
          Paint()..color = _background,
        );
    });

    // The tray body: M24,63H84L78.6,80.2C78.2,81.3 77.2,82 76,82H32
    // C30.8,82 29.8,81.3 29.4,80.2Z
    canvas
      ..drawPath(
        Path()
          ..moveTo(24, 63)
          ..lineTo(84, 63)
          ..lineTo(78.6, 80.2)
          ..cubicTo(78.2, 81.3, 77.2, 82, 76, 82)
          ..lineTo(32, 82)
          ..cubicTo(30.8, 82, 29.8, 81.3, 29.4, 80.2)
          ..close(),
        Paint()..color = _trayBody,
      )
      // Its rim line: a 48 x 1.6 pill at 30,68.
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(30, 68, 78, 69.6),
          // style-check: allow the icon's own path geometry (the SVG's 4 / 4.5 / 0.8)
          const Radius.circular(0.8),
        ),
        Paint()..color = _trayRim,
      )
      ..restore();
  }

  void _rotated(
    Canvas canvas,
    double degrees,
    Offset about,
    VoidCallback draw,
  ) {
    canvas
      ..save()
      ..translate(about.dx, about.dy)
      ..rotate(degrees * math.pi / 180)
      ..translate(-about.dx, -about.dy);
    draw();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
