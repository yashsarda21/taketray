import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A thin progress bar: a 4 dp track in the secondary container with a
/// primary fill, and an optional [label] above it.
///
/// With a [value] from 0 to 1 the fill grows to it (over `motion.medium2`,
/// linear; at once under "remove animations") and a screen reader hears the
/// percentage. With a null [value] the bar is indeterminate: a short bar
/// slides across the track, or, while animations are removed, stands still in
/// the middle. The `.prog` of the prototype has no indeterminate look; this
/// one is a sensible addition (D-49).
///
/// A screen reader hears [semanticLabel], or the [label], or nothing.
class TtProgressBar extends StatefulWidget {
  /// A bar at [value] (0 to 1), or indeterminate when null.
  const new({this.value, this.label, this.semanticLabel, super.key});

  /// How far along the work is, from 0 to 1 (anything else is clamped), or
  /// null when unknown.
  final double? value;

  /// A line of text above the bar, such as "7 of 12 clips", or null.
  final String? label;

  /// What a screen reader says for the bar, or null for the [label].
  final String? semanticLabel;

  @override
  State<TtProgressBar> createState() => _TtProgressBarState();
}

class _TtProgressBarState extends State<TtProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: TtMetrics.progressIndeterminateMillis.round(),
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TtProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Runs the slide only while the bar is indeterminate and motion is on.
  void _sync() {
    final slide = widget.value == null && !context.tt.motion.isReduced;
    if (slide) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
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
    final value = widget.value;
    final label = widget.label;
    final reduced = tt.motion.isReduced;
    final fillBox = DecoratedBox(
      key: const ValueKey('tt-progress-fill'),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(TtMetrics.progressRadius),
      ),
    );

    // proto.css: .prog i { position: absolute; inset: 0 auto 0 0 }
    final Widget fill;
    if (value != null) {
      final clamped = value.clamp(0.0, 1.0);
      fill = TweenAnimationBuilder<double>(
        tween: Tween(end: clamped),
        duration: tt.motion.medium2,
        builder: (context, factor, child) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: factor,
            heightFactor: 1,
            child: child,
          ),
        ),
        child: fillBox,
      );
    } else {
      const share = TtMetrics.progressIndeterminateFraction;
      // The bar's left edge as a share of the track, clipped to the track:
      // it enters at the start, crosses, and leaves at the end.
      (double, double) span(double t) {
        final left = -share + t * (1 + share);
        final start = left.clamp(0.0, 1.0);
        final end = (left + share).clamp(0.0, 1.0);
        return (start, end - start);
      }

      fill = reduced
          ? _Slice(start: (1 - share) / 2, width: share, child: fillBox)
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final (start, width) = span(_controller.value);
                return _Slice(start: start, width: width, child: child!);
              },
              child: fillBox,
            );
    }

    final track = DecoratedBox(
      key: const ValueKey('tt-progress-track'),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(TtMetrics.progressRadius),
      ),
      child: SizedBox(height: TtMetrics.progressHeight, child: fill),
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: widget.semanticLabel ?? label,
      value: value == null ? null : '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: tt.spacing.xs,
        children: [
          if (label != null)
            Text(
              label,
              style: tt.text.material.titleMedium!.copyWith(
                color: scheme.onSurface,
              ),
            ),
          track,
        ],
      ),
    );
  }
}

/// Places [child] in a slice of the track [width] wide, [start] from the
/// start edge (both as shares of the track).
class _Slice extends StatelessWidget {
  const new({required this.start, required this.width, required this.child});

  final double start;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Align's x runs -1..1 over the room left beside the child.
    final room = 1 - width;
    final x = room <= 0 ? -1.0 : 2 * start / room - 1;
    return Align(
      alignment: AlignmentDirectional(x, 0),
      child: FractionallySizedBox(
        widthFactor: width,
        heightFactor: 1,
        child: child,
      ),
    );
  }
}
