import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The red record dot: 10 dp, with a ring.
///
/// While [live] it pulses, a ring spreading out and fading every 1.6 s. It
/// holds still, and runs no animation at all, when [live] is false or the
/// system asks to remove animations.
///
/// [compact] makes it 8 dp (the stat strip). Giving an [outline] draws a 2 dp
/// ring of that colour around the dot, in place of the soft record ring, so
/// the dot stands out from a picture (the Shooting mode card's icon).
class TtRecDot extends StatefulWidget {
  /// A record dot that pulses while [live].
  const new({this.live = true, this.compact = false, this.outline, super.key});

  /// Whether the dot pulses (motion permitting).
  final bool live;

  /// Whether the dot is the smaller 8 dp version.
  final bool compact;

  /// The colour of a ring drawn around the dot, or null for none.
  final Color? outline;

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
    final outline = widget.outline;
    final size = widget.compact
        ? TtMetrics.recDotCompactSize
        : TtMetrics.recDotSize;
    Widget paint(double spread, double alpha) => ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: record,
          // The outline is painted last, so it covers the start of the pulse.
          boxShadow: [
            BoxShadow(
              color: record.withValues(alpha: alpha),
              spreadRadius: spread,
            ),
            if (outline != null)
              BoxShadow(
                color: outline,
                spreadRadius: TtMetrics.recDotOutlineWidth,
              ),
          ],
        ),
        child: SizedBox.square(dimension: size),
      ),
    );

    // proto.css: .shoot .ico .recdot { box-shadow: 0 0 0 2px … } and
    // @keyframes pulseOn: the ring starts under the outline (record 70 %) and
    // spreads to 7 px.
    final restSpread = outline == null
        ? TtMetrics.recDotRingWidth
        : TtMetrics.recDotOutlineWidth;
    final restAlpha = outline == null ? TtMetrics.recDotRingOpacity : 0.0;
    final startSpread = outline == null ? 0.0 : TtMetrics.recDotOutlineWidth;
    final startAlpha = outline == null
        ? TtMetrics.recDotPulseOpacity
        : TtMetrics.recDotOutlinePulseOpacity;

    if (!_pulsing) return paint(restSpread, restAlpha);
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
          startSpread + (TtMetrics.recDotPulseSpread - startSpread) * grown,
          startAlpha * (1 - grown),
        );
      },
    );
  }
}
