import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays its children out in equal-width columns, all the same height, and
/// shrinks all of them by **one** scale when the widest word of any child is
/// wider than its column, so no child is ever drawn smaller than another and
/// no word is broken in the middle.
///
/// For a bar of actions (icon over label) at large text: a short label may
/// wrap, but "Remove" cannot, so every action shrinks together, just enough
/// for the widest word to fit. The scale never enlarges. Each child is laid
/// out at its column's width divided by the scale and at least [minHeight]
/// divided by the scale high, so after the shrink it still fills its column
/// and is at least [minHeight] high; the row is as tall as its tallest child.
///
/// It does not use a `LayoutBuilder`, so it answers intrinsic size queries
/// (inside an `IntrinsicHeight`, for example).
class EqualColumns extends MultiChildRenderObjectWidget {
  /// Puts [children] in equal columns, at least [minHeight] high.
  const new({required this.minHeight, required super.children, super.key});

  /// The least height of the row, after the shrink.
  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualColumns(minHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderEqualColumns).minHeight = minHeight;
  }
}

class _Data extends ContainerBoxParentData<RenderBox>;

class _RenderEqualColumns extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Data>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  new(this._minHeight);

  double _minHeight;
  double _scale = 1;
  double _columnWidth = 0;

  double get minHeight => _minHeight;

  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  Iterable<RenderBox> get _children sync* {
    for (var c = firstChild; c != null; c = childAfter(c)) {
      yield c;
    }
  }

  int get _count => _children.length;

  /// The scale for a row [width] wide: 1, or less when the widest word of a
  /// child does not fit its column.
  double _scaleFor(double width) {
    final count = _count;
    if (count == 0 || !width.isFinite) return 1;
    final column = width / count;
    final narrowest = _children
        .map((c) => c.getMinIntrinsicWidth(double.infinity))
        .fold<double>(0, math.max);
    return narrowest > column && narrowest > 0 ? column / narrowest : 1;
  }

  /// The height of the row [width] wide, measured with [heightOf] (a child's
  /// height at a given width).
  double _heightFor(double width, double Function(RenderBox, double) heightOf) {
    final count = _count;
    if (count == 0) return 0;
    final scale = _scaleFor(width);
    final inner = width.isFinite ? width / count / scale : double.infinity;
    final tallest = _children
        .map((c) => heightOf(c, inner))
        .fold<double>(0, math.max);
    return math.max(_minHeight, tallest * scale);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _count *
      _children.map((c) => c.getMinIntrinsicWidth(height)).fold(0, math.max);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _count *
      _children.map((c) => c.getMaxIntrinsicWidth(height)).fold(0, math.max);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _heightFor(width, (c, w) => c.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _heightFor(width, (c, w) => c.getMaxIntrinsicHeight(w));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(computeMaxIntrinsicWidth(double.infinity));
    final height = _heightFor(
      width,
      (c, w) => c.getDryLayout(BoxConstraints(minWidth: w, maxWidth: w)).height,
    );
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() {
    final count = _count;
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(computeMaxIntrinsicWidth(double.infinity));
    if (count == 0) {
      size = constraints.constrain(Size(width, _minHeight));
      return;
    }
    _scale = _scaleFor(width);
    _columnWidth = width / count;
    final inner = _columnWidth / _scale;

    // First measure each child at the inner width; then lay them all out at
    // the height of the tallest, so every action has the same tap area.
    var tallest = _minHeight / _scale;
    for (final child in _children) {
      child.layout(
        BoxConstraints(minWidth: inner, maxWidth: inner),
        parentUsesSize: true,
      );
      tallest = math.max(tallest, child.size.height);
    }
    var x = 0.0;
    for (final child in _children) {
      child.layout(
        BoxConstraints.tight(Size(inner, tallest)),
        parentUsesSize: true,
      );
      (child.parentData! as _Data).offset = Offset(x, 0);
      x += _columnWidth;
    }
    size = constraints.constrain(Size(width, tallest * _scale));
  }

  Matrix4 _transformOf(RenderBox child) {
    final offset = (child.parentData! as _Data).offset;
    return Matrix4.translationValues(offset.dx, offset.dy, 0)
      ..scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _children) {
      context.pushTransform(
        needsCompositing,
        offset,
        _transformOf(child),
        (context, offset) => context.paintChild(child, offset),
      );
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transformOf(child));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _children.toList().reversed) {
      final hit = result.addWithPaintTransform(
        transform: _transformOf(child),
        position: position,
        hitTest: (result, position) =>
            child.hitTest(result, position: position),
      );
      if (hit) return true;
    }
    return false;
  }
}
