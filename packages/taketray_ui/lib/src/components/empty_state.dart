import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_colors.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// Which of the seven flat illustrations a [TtIllustration] draws.
enum TtIllustrationKind {
  /// Three clip tiles with a green check: nothing left to tag.
  caught,

  /// A phone with a switch turned off and a red dot: Shooting mode is off.
  shootOff,

  /// Two empty reel cards with a plus: no reels yet.
  noReels,

  /// One reel card with a play triangle and a plus: no clips in the reel.
  emptyReel,

  /// A folder: no videos in the folder.
  folder,

  /// A grid of clips behind a lock: access not given.
  permission,

  /// Two clip tiles with a forward arrow: nothing skipped.
  skipped,
}

/// A small flat illustration, 168 x 140 dp, drawn from the theme's colours so
/// it follows light and dark. It is decorative and hidden from screen
/// readers; the text beside it says what it means.
class TtIllustration extends StatelessWidget {
  /// The illustration of [kind].
  const new(this.kind, {super.key});

  /// Which picture to draw.
  final TtIllustrationKind kind;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: TtMetrics.illustrationWidth,
      height: TtMetrics.illustrationHeight,
      child: CustomPaint(
        painter: _IllustrationPainter(
          kind: kind,
          scheme: context.scheme,
          colors: context.tt.colors,
        ),
      ),
    ),
  );
}

/// A centred empty state: an [illustration], a [title], a [body] and a
/// column of [actions] (usually `TtButton`s), 8 dp apart.
///
/// It has 40 / 32 / 24 dp padding, the body is at most 280 dp wide, and the
/// title and body wrap at large text. The title is announced as a heading.
class TtEmptyState extends StatelessWidget {
  /// An empty state with the [illustration], [title] and [body].
  const new({
    required this.illustration,
    required this.title,
    required this.body,
    this.actions = const [],
    super.key,
  });

  /// The picture on top.
  final TtIllustrationKind illustration;

  /// What is empty, such as "All caught up".
  final String title;

  /// A sentence or two that says what to do or what will show up here.
  final String body;

  /// Buttons under the text, top to bottom; none by default.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    // proto.css: .empty { padding: 40px 32px 24px; gap: 8px }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.xxl,
        tt.spacing.x3l,
        tt.spacing.xxl,
        tt.spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: tt.spacing.xs,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              bottom: TtMetrics.emptyIllustrationMargin,
            ),
            child: TtIllustration(illustration),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleLarge!.copyWith(color: scheme.onSurface),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: TtMetrics.emptyBodyMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TtMetrics.emptyBodyMaxWidth,
              ),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: tt.spacing.xs,
            children: actions,
          ),
        ],
      ),
    );
  }
}

/// Draws the illustration of [kind] with the geometry of `h.illus` in the
/// prototype's `ui.js` (viewBox 0 0 168 140, drawn 1:1). The numbers below are
/// that SVG's coordinates, not styling; the colours are the scheme roles and
/// [TtColors] the SVG's CSS variables map to.
class _IllustrationPainter extends CustomPainter {
  const new({required this.kind, required this.scheme, required this.colors});

  final TtIllustrationKind kind;
  final ColorScheme scheme;
  final TtColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final art = _Art(canvas);
    switch (kind) {
      case TtIllustrationKind.caught:
        art
          ..tile(30, 30, 48, 64, scheme.surfaceContainerHighest)
          ..tile(60, 22, 48, 64, scheme.surfaceContainerHigh)
          ..tile(90, 30, 48, 64, scheme.surfaceContainerHighest)
          ..circle(84, 96, 30, colors.success)
          ..stroke(
            Path()
              ..moveTo(71, 96)
              ..relativeLineTo(9, 9)
              ..relativeLineTo(18, -19),
            colors.onSuccess,
            7,
            round: true,
          );
      case TtIllustrationKind.shootOff:
        art
          ..tile(54, 12, 60, 108, scheme.surfaceContainerHighest, 12)
          ..tile(62, 24, 44, 70, scheme.surfaceContainerHigh)
          ..circle(84, 107, 7, scheme.outline)
          ..tile(96, 70, 56, 32, scheme.primary, 16)
          ..circle(136, 86, 11, scheme.onPrimary)
          ..circle(34, 42, 8, colors.record);
      case TtIllustrationKind.noReels:
        art
          ..tile(22, 20, 56, 76, scheme.surfaceContainerHighest, 12)
          ..tile(90, 20, 56, 76, scheme.surfaceContainerHigh, 12)
          ..tile(28, 104, 40, 8, scheme.outlineVariant, 4)
          ..tile(96, 104, 30, 8, scheme.outlineVariant, 4)
          ..circle(118, 58, 20, scheme.primary)
          ..stroke(_plus(118, 58), scheme.onPrimary, 5, round: true);
      case TtIllustrationKind.emptyReel:
        art
          ..tile(46, 14, 76, 100, scheme.surfaceContainerHighest, 14)
          ..fill(
            Path()
              ..moveTo(74, 52)
              ..relativeLineTo(26, 16)
              ..relativeLineTo(-26, 16)
              ..close(),
            scheme.outline,
          )
          ..circle(122, 108, 20, scheme.tertiaryContainer)
          ..stroke(_plus(122, 108), scheme.onTertiaryContainer, 5, round: true);
      case TtIllustrationKind.folder:
        art
          ..fill(_folder(), scheme.surfaceContainerHighest)
          ..stroke(
            Path()
              ..moveTo(66, 86)
              ..relativeLineTo(36, 0),
            scheme.outlineVariant,
            6,
            round: true,
          );
      case TtIllustrationKind.permission:
        art
          ..tile(28, 24, 34, 44, scheme.surfaceContainerHighest)
          ..tile(66, 24, 34, 44, scheme.surfaceContainerHigh)
          ..tile(104, 24, 34, 44, scheme.surfaceContainerHighest)
          ..tile(28, 72, 34, 44, scheme.surfaceContainerHigh)
          ..tile(66, 72, 34, 44, scheme.surfaceContainerHighest)
          ..tile(104, 72, 34, 44, scheme.surfaceContainerHigh)
          ..circle(84, 70, 26, scheme.primary)
          ..tile(74, 66, 20, 16, scheme.onPrimary, 3)
          // M78 66v-5a6 6 0 0 1 12 0v5: the shackle, a half circle on legs.
          ..stroke(
            Path()
              ..moveTo(78, 66)
              ..lineTo(78, 61)
              ..arcTo(
                Rect.fromCircle(center: const Offset(84, 61), radius: 6),
                math.pi,
                math.pi,
                false,
              )
              ..lineTo(90, 66),
            scheme.onPrimary,
            3.5,
          );
      case TtIllustrationKind.skipped:
        art
          ..tile(40, 22, 48, 64, scheme.surfaceContainerHighest)
          ..tile(80, 30, 48, 64, scheme.surfaceContainerHigh)
          ..circle(84, 98, 24, scheme.secondaryContainer)
          // M74 98h16m-6-7l7 7-7 7: a line with an arrow head.
          ..stroke(
            Path()
              ..moveTo(74, 98)
              ..lineTo(90, 98)
              ..moveTo(84, 91)
              ..lineTo(91, 98)
              ..lineTo(84, 105),
            scheme.onSecondaryContainer,
            4.5,
            round: true,
          );
    }
  }

  /// A plus of 20 x 20 centred on ([cx], [cy]): `M118 48v20M108 58h20`.
  static Path _plus(double cx, double cy) => Path()
    ..moveTo(cx, cy - 10)
    ..lineTo(cx, cy + 10)
    ..moveTo(cx - 10, cy)
    ..lineTo(cx + 10, cy);

  /// `M30 40a8 8 0 0 1 8-8h28l10 10h54a8 8 0 0 1 8 8v58a8 8 0 0 1-8 8H38
  /// a8 8 0 0 1-8-8z`: a folder with a tab, 8 dp corners.
  static Path _folder() => Path()
    ..moveTo(30, 40)
    ..arcTo(_corner(38, 40), math.pi, math.pi / 2, false)
    ..lineTo(66, 32)
    ..lineTo(76, 42)
    ..lineTo(130, 42)
    ..arcTo(_corner(130, 50), -math.pi / 2, math.pi / 2, false)
    ..lineTo(138, 108)
    ..arcTo(_corner(130, 108), 0, math.pi / 2, false)
    ..lineTo(38, 116)
    ..arcTo(_corner(38, 108), math.pi / 2, math.pi / 2, false)
    ..close();

  /// The square around a corner arc of radius 8 centred on ([cx], [cy]).
  static Rect _corner(double cx, double cy) =>
      Rect.fromCircle(center: Offset(cx, cy), radius: 8);

  @override
  bool shouldRepaint(_IllustrationPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.scheme != scheme ||
      oldDelegate.colors != colors;
}

/// The few SVG operations the illustrations use, on one canvas.
class _Art {
  const new(this.canvas);

  final Canvas canvas;

  /// `<rect x y width height rx>`.
  void tile(
    double x,
    double y,
    double w,
    double h,
    Color color, [
    double radius = 6,
  ]) => canvas.drawRRect(
    RRect.fromRectXY(Rect.fromLTWH(x, y, w, h), radius, radius),
    Paint()..color = color,
  );

  /// `<circle cx cy r>`.
  void circle(double cx, double cy, double r, Color color) =>
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);

  /// `<path d fill>`.
  void fill(Path path, Color color) =>
      canvas.drawPath(path, Paint()..color = color);

  /// `<path d fill="none" stroke-width>`, with round caps and joins when
  /// [round] is set (`stroke-linecap="round" stroke-linejoin="round"`).
  void stroke(Path path, Color color, double width, {bool round = false}) =>
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = round ? StrokeCap.round : StrokeCap.butt
          ..strokeJoin = round ? StrokeJoin.round : StrokeJoin.miter,
      );
}
