import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Shows `preferred` when its natural width fits the room it is given, and
/// `fallback` when it does not.
///
/// For a button whose label might not fit a narrow place: the text button is
/// `preferred` and the icon-only one is `fallback`, so a label is never cut
/// short. The room is decided during layout, like a `LayoutBuilder`, but this
/// answers intrinsic size queries (inside an `IntrinsicHeight`, or under
/// `FitHeight`), which a `LayoutBuilder` cannot.
///
/// Both children are built and laid out; only the chosen one is drawn, hit
/// tested and seen by a screen reader.
class FitOrFallback extends MultiChildRenderObjectWidget {
  /// Shows `preferred` if it fits, else `fallback`.
  new({required Widget preferred, required Widget fallback, super.key})
    : super(children: [preferred, fallback]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFitOrFallback();
}

class _Data extends ContainerBoxParentData<RenderBox>;

class _RenderFitOrFallback extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Data>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  RenderBox? _showing;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _Data) {
      child.parentData = _Data();
    }
  }

  RenderBox get _preferred => firstChild!;
  RenderBox get _fallback => childAfter(firstChild!)!;

  RenderBox _choose(double maxWidth) =>
      !maxWidth.isFinite ||
          _preferred.getMaxIntrinsicWidth(double.infinity) <= maxWidth
      ? _preferred
      : _fallback;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _fallback.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _preferred.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _choose(width).getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _choose(width).getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    _choose(constraints.maxWidth).getDryLayout(constraints.loosen()),
  );

  @override
  void performLayout() {
    final chosen = _choose(constraints.maxWidth);
    final other = identical(chosen, _preferred) ? _fallback : _preferred;
    chosen.layout(constraints.loosen(), parentUsesSize: true);
    // The other one is not shown, but is still laid out so that it is never
    // left waiting for a layout.
    other.layout(BoxConstraints.tight(Size.zero));
    if (!identical(_showing, chosen)) {
      _showing = chosen;
      markNeedsSemanticsUpdate();
    }
    size = constraints.constrain(chosen.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final showing = _showing;
    if (showing != null) context.paintChild(showing, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final showing = _showing;
    return showing != null && showing.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final showing = _showing;
    if (showing != null) visitor(showing);
  }
}
