import 'package:flutter/widgets.dart';

/// A dark gradient that fills its parent and fades from [color] at one edge
/// to clear at the other, so light text stays readable over a picture.
///
/// The gradient starts at the top edge when [top] is true, otherwise at the
/// bottom edge. [solid] is the share of the height, counted from that edge,
/// that stays at the full [color] before the fade begins (0 fades the whole
/// way, 0.7 keeps 70 % solid). The scrim takes no touches and is not
/// announced. The caller sizes and places it, for example with `Positioned`
/// or `FractionallySizedBox`.
class Scrim extends StatelessWidget {
  /// A scrim of [color] on the top or bottom edge.
  const new({required this.color, required this.top, this.solid = 0, super.key})
    : assert(solid >= 0 && solid < 1, 'solid is a share of the height');

  /// The colour at the edge, with its opacity.
  final Color color;

  /// Whether the edge is the top (otherwise the bottom).
  final bool top;

  /// The share of the height from the edge that stays at [color].
  final double solid;

  @override
  Widget build(BuildContext context) {
    final edge = top ? Alignment.topCenter : Alignment.bottomCenter;
    final inner = top ? Alignment.bottomCenter : Alignment.topCenter;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: edge,
              end: inner,
              colors: solid == 0
                  ? [color, color.withValues(alpha: 0)]
                  : [color, color, color.withValues(alpha: 0)],
              stops: solid == 0 ? null : [0, solid, 1],
            ),
          ),
        ),
      ),
    );
  }
}
