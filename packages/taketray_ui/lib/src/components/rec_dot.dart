import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The red record dot: 10 dp, with a ring.
///
/// While [live] it pulses, a ring spreading out and fading every 1.6 s. It
/// holds still, and runs no animation at all, when [live] is false or the
/// system asks to remove animations.
class TtRecDot extends StatefulWidget {
  /// A record dot that pulses while [live].
  const new({this.live = true, super.key});

  /// Whether the dot pulses (motion permitting).
  final bool live;

  @override
  State<TtRecDot> createState() => _TtRecDotState();
}

class _TtRecDotState extends State<TtRecDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: TtMetrics.recDotPulseMillis.round()),
  );

  bool get _pulsing => widget.live && !context.tt.motion.isReduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TtRecDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_pulsing) {
      if (!_controller.isAnimating) _controller.repeat();
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
    final record = tt.colors.record;
    Widget paint(double spread, double alpha) => ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: record,
          boxShadow: [
            BoxShadow(
              color: record.withValues(alpha: alpha),
              spreadRadius: spread,
            ),
          ],
        ),
        child: const SizedBox.square(dimension: TtMetrics.recDotSize),
      ),
    );

    if (!_pulsing) {
      return paint(TtMetrics.recDotRingWidth, TtMetrics.recDotRingOpacity);
    }
    // proto.css: @keyframes pulse { 0%,100% { 0 0 0 0 record 60% }
    //                               60% { 0 0 0 7px transparent } }
    // with the standard easing on each leg.
    const split = TtMetrics.recDotPulseSpreadFraction;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        final curve = tt.motion.standard;
        final out = v < split;
        final eased = out
            ? curve.transform(v / split)
            : curve.transform((v - split) / (1 - split));
        final grown = out ? eased : 1 - eased;
        return paint(
          TtMetrics.recDotPulseSpread * grown,
          TtMetrics.recDotPulseOpacity * (1 - grown),
        );
      },
    );
  }
}
