import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [child] out at the width it is given and as tall as it needs, then
/// shrinks it (never enlarges it) when that is taller than the height it was
/// given, and centres it.
///
/// Like a [FittedBox] with `BoxFit.scaleDown`, but the child keeps the width
/// of the box, so text in it wraps at the box's width instead of running on in
/// unbounded room. As a last resort it also shrinks the child when its
/// narrowest possible layout (every word on a line of its own) is wider than
/// the box, so a word is never broken in the middle.
///
/// It does not use a `LayoutBuilder`, so it answers intrinsic size queries
/// (inside an `IntrinsicHeight`, for example), and it reports its child's
/// baseline, scaled.
class FitHeight extends SingleChildRenderObjectWidget {
  /// Shrinks [child] to the box it is given when it is bigger.
  const new({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFitHeight();
}

/// How the child is laid out and drawn inside the box.
typedef _Plan = ({
  BoxConstraints child,
  double scale,
  Size size,
  Offset offset,
});

class _RenderFitHeight extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  double _scale = 1;
  Offset _offset = Offset.zero;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  /// Works out the layout for [constraints], measuring the child with
  /// [measure].
  _Plan _plan(
    BoxConstraints constraints,
    Size Function(BoxConstraints) measure,
  ) {
    final child = this.child!;
    var childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    var childSize = measure(childConstraints);
    // A word wider than the box: lay out at the width of the widest word and
    // shrink, instead of letting the text break the word.
    var scale = 1.0;
    if (constraints.maxWidth.isFinite) {
      final narrowest = child.getMinIntrinsicWidth(double.infinity);
      if (narrowest > constraints.maxWidth && narrowest > 0) {
        scale = constraints.maxWidth / narrowest;
        childConstraints = BoxConstraints(maxWidth: narrowest);
        childSize = measure(childConstraints);
      }
    }
    final scaled = Size(childSize.width * scale, childSize.height * scale);
    final own = constraints.constrain(scaled);
    if (childSize.height > 0 && childSize.height * scale > own.height) {
      scale = own.height / childSize.height;
    }
    final shown = Size(childSize.width * scale, childSize.height * scale);
    return (
      child: childConstraints,
      scale: scale,
      size: own,
      offset: Offset(
        (own.width - shown.width) / 2,
        (own.height - shown.height) / 2,
      ),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _plan(constraints, child.getDryLayout).size;
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    final plan = _plan(constraints, child.getDryLayout);
    final distance = child.getDryBaseline(plan.child, baseline);
    return distance == null ? null : distance * plan.scale + plan.offset.dy;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final distance = child?.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance * _scale + _offset.dy;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final plan = _plan(constraints, (c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    // The last measure may not have been for the final constraints.
    child.layout(plan.child, parentUsesSize: true);
    size = plan.size;
    _scale = plan.scale;
    _offset = plan.offset;
  }

  Matrix4 get _transform =>
      Matrix4.translationValues(_offset.dx, _offset.dy, 0)
        ..scaleByDouble(_scale, _scale, 1, 1);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void dispose() {
    layer = null;
    super.dispose();
  }
}
