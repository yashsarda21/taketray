import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A text, and how many lines of it fit: the question [TextOverflowSwitch]
/// asks of the width it is given.
///
/// Equal when the same text is set the same way, so a rebuild with the same
/// words does not ask for a new layout.
@immutable
class TextClamp {
  /// [text] drawn in [style] and [textScaler], read in [textDirection] and
  /// clamped to [maxLines].
  const new({
    required this.text,
    required this.style,
    required this.textScaler,
    required this.textDirection,
    required this.maxLines,
    this.locale,
  });

  /// The words.
  final String text;

  /// The full style the text is drawn in.
  final TextStyle style;

  /// The text scale of the screen.
  final TextScaler textScaler;

  /// Which way the text runs.
  final TextDirection textDirection;

  /// The most lines that show.
  final int maxLines;

  /// The language of the text, or null.
  final Locale? locale;

  /// Whether [text] needs more than [maxLines] lines in a column [width] dp
  /// wide. Measured, not counted: the same layout the `Text` itself gets.
  bool exceeds(double width) {
    if (!width.isFinite || width <= 0 || text.isEmpty) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  @override
  bool operator ==(Object other) =>
      other is TextClamp &&
      other.text == text &&
      other.style == style &&
      other.textScaler == textScaler &&
      other.textDirection == textDirection &&
      other.maxLines == maxLines &&
      other.locale == locale;

  @override
  int get hashCode =>
      Object.hash(text, style, textScaler, textDirection, maxLines, locale);
}

/// Shows `whole` when [clamp]'s text fits in its lines at the width it is
/// given, and `clamped` when it does not.
///
/// For a text that shows a "Show more" button only when it is cut short. The
/// width is known during layout, like a `LayoutBuilder`, but this answers
/// intrinsic size queries (inside an `IntrinsicHeight`), which a
/// `LayoutBuilder` cannot. Both children are built and laid out; only the
/// chosen one is drawn, hit tested and seen by a screen reader.
class TextOverflowSwitch extends MultiChildRenderObjectWidget {
  /// Shows [whole] if [clamp] fits its lines, else [clamped].
  new({
    required this.clamp,
    required Widget whole,
    required Widget clamped,
    super.key,
  }) : super(children: [whole, clamped]);

  /// The text and lines to measure.
  final TextClamp clamp;

  @override
  MultiChildRenderObjectElement createElement() => _SwitchElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTextOverflowSwitch(clamp);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTextOverflowSwitch).clamp = clamp;
  }
}

/// Tells the widget tree which child is shown, so `find` (which skips what is
/// offstage) and the inspector see one text, not two.
class _SwitchElement extends MultiChildRenderObjectElement {
  new(TextOverflowSwitch super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final shown = (renderObject as _RenderTextOverflowSwitch)._showing;
    visitChildren((child) {
      if (shown == null || identical(child.renderObject, shown)) {
        visitor(child);
      }
    });
  }
}

class _Data extends ContainerBoxParentData<RenderBox>;

class _RenderTextOverflowSwitch extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Data>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  new(this._clamp);

  TextClamp _clamp;
  RenderBox? _showing;

  TextClamp get clamp => _clamp;

  set clamp(TextClamp value) {
    if (value == _clamp) return;
    _clamp = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  RenderBox get _whole => firstChild!;
  RenderBox get _clamped => childAfter(firstChild!)!;

  RenderBox _choose(double maxWidth) =>
      _clamp.exceeds(maxWidth) ? _clamped : _whole;

  @override
  double computeMinIntrinsicWidth(double height) => _max(
    _whole.getMinIntrinsicWidth(height),
    _clamped.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _max(
    _whole.getMaxIntrinsicWidth(height),
    _clamped.getMaxIntrinsicWidth(height),
  );

  static double _max(double a, double b) => a > b ? a : b;

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
    final other = identical(chosen, _whole) ? _clamped : _whole;
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
