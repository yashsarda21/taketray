import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [child] out at the width it is given and as tall as it needs, then
/// shrinks it (never enlarges it) when that is taller than the height it was
/// given, and centres it.
///
/// Like a [FittedBox] with `BoxFit.scaleDown`, but the child keeps the width
/// of the box, so text in it wraps at the box's width instead of running on in
/// unbounded room. It does not use a `LayoutBuilder`, so it answers intrinsic
/// size queries (inside an `IntrinsicHeight`, for example).
class FitHeight extends SingleChildRenderObjectWidget {
  /// Shrinks [child] to the height it is given when it is taller.
  const new({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFitHeight();
}

class _RenderFitHeight extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  double _scale = 1;
  Offset _offset = Offset.zero;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

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
    final size = child.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(size);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    final own = constraints.constrain(child.size);
    size = own;
    _scale = child.size.height > own.height && child.size.height > 0
        ? own.height / child.size.height
        : 1;
    // Centre the scaled child in the box.
    _offset = Offset(
      (own.width - child.size.width * _scale) / 2,
      (own.height - child.size.height * _scale) / 2,
    );
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
