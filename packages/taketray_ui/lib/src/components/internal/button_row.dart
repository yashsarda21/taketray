import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays its children out side by side with equal widths when each fits its
/// share of the width on one line, and one per row at the full width when
/// one does not (long labels, large text). Unlike a `LayoutBuilder`, it
/// answers intrinsic size queries. Shown through `TtButtonRow`.
class TtButtonRowLayout extends MultiChildRenderObjectWidget {
  /// Lays out [children] [spacing] apart.
  const new({required this.spacing, super.children, super.key});

  /// Gap between two children, across or down.
  final double spacing;

  @override
  RenderTtButtonRow createRenderObject(BuildContext context) =>
      RenderTtButtonRow(spacing);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTtButtonRow renderObject,
  ) => renderObject.spacing = spacing;
}

/// Where a child of a [RenderTtButtonRow] sits.
class _ButtonRowParentData extends ContainerBoxParentData<RenderBox>;

/// The render object of [TtButtonRowLayout].
class RenderTtButtonRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ButtonRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ButtonRowParentData> {
  /// A row whose children sit [spacing] apart.
  new(this._spacing);

  /// Gap between two children, across or down.
  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ButtonRowParentData) {
      child.parentData = _ButtonRowParentData();
    }
  }

  List<RenderBox> get _children => getChildrenAsList();

  /// Each child's width when side by side in [width].
  double _share(double width) =>
      (width - spacing * (childCount - 1)) / childCount;

  /// Whether every child fits its share of [width] on one line.
  bool _fitsSideBySide(double width) {
    final share = _share(width);
    return _children.every(
      (child) => child.getMaxIntrinsicWidth(double.infinity) <= share,
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => _children.fold(
    0,
    (widest, child) => math.max(widest, child.getMinIntrinsicWidth(height)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (childCount == 0) return 0;
    final widest = _children.fold<double>(
      0,
      (widest, child) => math.max(widest, child.getMaxIntrinsicWidth(height)),
    );
    return widest * childCount + spacing * (childCount - 1);
  }

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) heightOf,
  ) {
    if (childCount == 0) return 0;
    if (_fitsSideBySide(width)) {
      final share = _share(width);
      return _children.fold(
        0,
        (tallest, child) => math.max(tallest, heightOf(child, share)),
      );
    }
    return _children.fold<double>(
          0,
          (total, child) => total + heightOf(child, width),
        ) +
        spacing * (childCount - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMaxIntrinsicHeight(width),
  );

  /// Sizes the children with [layoutChild] (and places them when [place] is
  /// given) for [constraints], and returns the bar's size.
  Size _arrange(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild, {
    void Function(RenderBox child, Offset offset)? place,
  }) {
    assert(constraints.hasBoundedWidth, 'A TtButtonRow needs a bounded width.');
    final width = constraints.maxWidth;
    if (childCount == 0) return constraints.constrain(Size(width, 0));
    if (_fitsSideBySide(width)) {
      final share = _share(width);
      var x = 0.0;
      var height = 0.0;
      for (final child in _children) {
        final size = layoutChild(child, BoxConstraints.tightFor(width: share));
        place?.call(child, Offset(x, 0));
        x += share + spacing;
        height = math.max(height, size.height);
      }
      return constraints.constrain(Size(width, height));
    }
    var y = 0.0;
    for (final child in _children) {
      final size = layoutChild(child, BoxConstraints.tightFor(width: width));
      place?.call(child, Offset(0, y));
      y += size.height + spacing;
    }
    return constraints.constrain(Size(width, y - spacing));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _arrange(constraints, (child, c) => child.getDryLayout(c));

  @override
  void performLayout() {
    size = _arrange(
      constraints,
      (child, c) {
        child.layout(c, parentUsesSize: true);
        return child.size;
      },
      place: (child, offset) =>
          (child.parentData! as _ButtonRowParentData).offset = offset,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
