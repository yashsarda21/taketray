import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A grey bar that stands in for a line of text while it loads.
///
/// 12 dp high, [widthFactor] of the width it is given, aligned to the start.
/// It is still, and hidden from a screen reader.
class TtSkeletonLine extends StatelessWidget {
  /// A skeleton line [widthFactor] (0 to 1) of the available width.
  const new({this.widthFactor = 0.4, super.key});

  /// How much of the available width the line takes.
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    // proto.css: .skel-line { height: 12px; border-radius: 6px; … }
    return ExcludeSemantics(
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(TtMetrics.skeletonLineRadius),
          ),
          child: const SizedBox(height: TtMetrics.skeletonLineHeight),
        ),
      ),
    );
  }
}

/// A clip tile that is still loading: a 3:4 grey tile with a light band that
/// sweeps across it.
///
/// The sweep runs every 1.4 s while animations are on, and stops, leaving a
/// plain tile, under "remove animations". Hidden from a screen reader.
class TtClipTileSkeleton extends StatefulWidget {
  /// A skeleton tile.
  const new({super.key});

  @override
  State<TtClipTileSkeleton> createState() => _TtClipTileSkeletonState();
}

class _TtClipTileSkeletonState extends State<TtClipTileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: TtMetrics.skeletonShimmerMillis.round()),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.tt.motion.isReduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .tile.skel { background: surface-container-high }
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: tt.sizes.clipTileAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tt.radii.m),
          child: ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: tt.motion.isReduced
                ? null
                : CustomPaint(
                    painter: _ShimmerPainter(
                      progress: _controller,
                      color: scheme.onSurface.withValues(
                        alpha: TtMetrics.skeletonShimmerOpacity,
                      ),
                    ),
                    size: Size.infinite,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Paints `.tile.skel::before`: a 100 degree gradient, transparent to a faint
/// band and back, on a layer 220 % as wide as the tile that slides from
/// 120 % to -120 % (a CSS background position) once per cycle.
class _ShimmerPainter extends CustomPainter {
  new({required this.progress, required this.color}) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final layerWidth = size.width * TtMetrics.skeletonShimmerLayerWidth;
    // background-position-x p: the layer's left edge is (width - layer) * p.
    final p = TtMetrics.skeletonShimmerTravel * (1 - 2 * progress.value);
    final left = (size.width - layerWidth) * p;

    // A CSS gradient line passes through the centre of the layer at the given
    // angle, long enough for the corners to take the end colours.
    const angle = TtMetrics.skeletonShimmerAngle * math.pi / 180;
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final length =
        (layerWidth * math.sin(angle)).abs() +
        (size.height * math.cos(angle)).abs();
    final centre = Offset(left + layerWidth / 2, size.height / 2);
    final clear = color.withValues(alpha: 0);
    final shader = ui.Gradient.linear(
      centre - direction * (length / 2),
      centre + direction * (length / 2),
      [clear, clear, color, clear, clear],
      const [
        0,
        TtMetrics.skeletonShimmerStart,
        TtMetrics.skeletonShimmerMiddle,
        TtMetrics.skeletonShimmerEnd,
        1,
      ],
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) =>
      old.progress != progress || old.color != color;
}
