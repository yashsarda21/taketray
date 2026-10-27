import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG text contrast measured from the colours the text and its background
/// really have, the same on every platform (D-62).
///
/// Flutter's [textContrastGuideline] takes a screenshot and guesses the text
/// colour as the most frequent "light" or "dark" pixel around the text. That
/// guess depends on how the font is rasterised: on Linux (FreeType) a 12 to
/// 14 dp glyph has so few fully covered pixels that an anti-aliased edge
/// pixel wins, and text that is fine reads as 1.2:1. This guideline checks
/// the same texts with the same thresholds, but measures each one from two
/// screenshots in which no glyph is drawn:
///
/// - the background: every text in the view painted transparent (and without
///   shadows), so the image holds exactly what is behind the glyphs;
/// - the foreground: every text run replaced by a solid box in the text's own
///   colour (its `backgroundColor`), so each box pixel is exactly what a
///   fully covered glyph pixel is after every opacity, blend and translucent
///   layer above and below it.
///
/// Inside the text's paint bounds, the pixels where the two images differ
/// are the text; the most frequent (box, background) pair of colours gives
/// the ratio. Boxes and fills have no glyph edges, so the result does not
/// depend on the font rasteriser. Text shadows are left out, which can only
/// lower the ratio.
///
/// Every text render object is restored, and the frame repainted, before
/// this returns.
class TtTextContrastGuideline extends AccessibilityGuideline {
  /// The guideline; use [ttTextContrastGuideline].
  const new();

  /// The thresholds and text selection of Flutter's guideline.
  static const _flutter = MinimumTextContrastGuideline();

  /// As Flutter's guideline: a ratio 0.01 under the target still passes.
  static const double _tolerance = -0.01;

  @override
  String get description =>
      'Text contrast should follow WCAG guidelines '
      '(resolved colours, TakeTray D-62)';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var result = const Evaluation.pass();
    for (final sample in await measureTtTextContrast(tester)) {
      if (sample.ratio - sample.required >= _tolerance) continue;
      result += Evaluation.fail(
        '"${sample.text}": expected a contrast ratio of at least '
        '${sample.required} but found ${sample.ratio.toStringAsFixed(2)} '
        'for a font size of ${sample.fontSize}.\n'
        'Text ${_hex(sample.foreground)} on ${_hex(sample.background)}.\n'
        'See also: '
        'https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html',
      );
    }
    return result;
  }
}

/// The text contrast check of `expectTtAccessible` on every platform (D-62).
const AccessibilityGuideline ttTextContrastGuideline =
    TtTextContrastGuideline();

/// One text checked by [TtTextContrastGuideline].
@immutable
class TtTextContrastSample {
  /// A sample for [text], drawn in [foreground] on [background].
  const new({
    required this.text,
    required this.foreground,
    required this.background,
    required this.fontSize,
    required this.bold,
  });

  /// The text, as its semantics label.
  final String text;

  /// The colour of a fully covered glyph pixel, after compositing.
  final Color foreground;

  /// The colour behind the glyphs, after compositing.
  final Color background;

  /// The font size Flutter's guideline uses for the threshold.
  final double? fontSize;

  /// Whether the text is bold, as Flutter's guideline decides it.
  final bool bold;

  /// The WCAG contrast ratio of [foreground] and [background].
  double get ratio {
    final a = foreground.computeLuminance() + 0.05;
    final b = background.computeLuminance() + 0.05;
    return a > b ? a / b : b / a;
  }

  /// The WCAG AA minimum for this text: 4.5, or 3 for large text.
  double get required => TtTextContrastGuideline._flutter.targetContrastRatio(
    fontSize,
    bold: bold,
  );

  @override
  String toString() =>
      'TtTextContrastSample("$text", ${_hex(foreground)} on '
      '${_hex(background)}, ${ratio.toStringAsFixed(2)})';
}

/// Measures every text that [TtTextContrastGuideline] checks, in the order
/// of the semantics tree; see the guideline for how.
Future<List<TtTextContrastSample>> measureTtTextContrast(
  WidgetTester tester,
) async {
  final samples = <TtTextContrastSample>[];
  for (final renderView in tester.binding.renderViews) {
    final targets = <_Target>[];
    _collectTargets(
      renderView.owner!.semanticsOwner!.rootSemanticsNode!,
      renderView,
      targets,
    );
    if (targets.isEmpty) continue;

    final texts = <RenderBox>[];
    void visit(RenderObject object) {
      if (object is RenderParagraph || object is RenderEditable) {
        texts.add(object as RenderBox);
      }
      object.visitChildren(visit);
    }

    renderView.visitChildren(visit);
    final originals = {for (final t in texts) t: _textOf(t)!};

    late final _Shot background;
    late final _Shot boxes;
    try {
      _restyleAll(originals, boxes: false);
      background = await _shoot(tester, renderView);
      _restyleAll(originals, boxes: true);
      boxes = await _shoot(tester, renderView);
    } finally {
      originals.forEach(_setTextOf);
      _flush(tester);
    }

    for (final target in targets) {
      final box = target.text;
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        box.paintBounds,
      );
      final (fg, bg) = _dominantPair(background, boxes, rect);
      samples.add(
        TtTextContrastSample(
          text: target.label,
          foreground: fg,
          background: bg,
          fontSize: target.fontSize,
          bold: target.bold,
        ),
      );
    }
  }
  return samples;
}

class _Target {
  new(this.label, this.text, this.fontSize, {required this.bold});

  final String label;
  final RenderBox text;
  final double? fontSize;
  final bool bold;
}

/// Picks the same semantics nodes and elements as Flutter's
/// `MinimumTextContrastGuideline` (flutter_test, accessibility.dart).
void _collectTargets(
  SemanticsNode node,
  RenderView renderView,
  List<_Target> out,
) {
  final disabled = node.flagsCollection.isEnabled == ui.Tristate.isFalse;
  if (node.isInvisible ||
      node.isMergedIntoParent ||
      node.flagsCollection.isHidden ||
      disabled) {
    return;
  }
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  for (final child in children) {
    _collectTargets(child, renderView, out);
  }
  final data = node.getSemanticsData();
  if (data.flagsCollection.scopesRoute ||
      (data.label.trim().isEmpty && data.value.trim().isEmpty)) {
    return;
  }
  final label = data.label.isEmpty ? data.value : data.label;
  for (final element in find.text(label).hitTestable().evaluate()) {
    final target = _targetFor(node, element, label, renderView);
    if (target != null) out.add(target);
  }
}

_Target? _targetFor(
  SemanticsNode node,
  Element element,
  String label,
  RenderView renderView,
) {
  final renderBox = element.renderObject;
  if (renderBox is! RenderBox) {
    throw StateError('Unexpected renderObject type: $renderBox');
  }
  final globalTransform = renderBox.getTransformTo(null);
  final paintBoundsWithOffset = MatrixUtils.transformRect(
    globalTransform,
    renderBox.paintBounds.inflate(4),
  );
  final rootTransform = Matrix4.identity();
  renderView.applyPaintTransform(renderView.child!, rootTransform);
  rootTransform.multiply(globalTransform);
  final screenBounds = MatrixUtils.transformRect(
    rootTransform,
    renderBox.paintBounds,
  );
  var nodeBounds = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final transform = current.transform;
    if (transform != null) {
      nodeBounds = MatrixUtils.transformRect(transform, nodeBounds);
    }
    current = current.parent;
  }
  final intersection = nodeBounds.intersect(screenBounds);
  if (intersection.width <= 0 || intersection.height <= 0) return null;

  final widget = element.widget;
  final TextStyle style;
  if (widget is Text) {
    final own = widget.style;
    style = own == null || own.inherit
        ? DefaultTextStyle.of(element).style.merge(own)
        : own;
  } else if (widget is EditableText) {
    style = widget.style;
  } else {
    throw StateError('Unexpected widget type: ${widget.runtimeType}');
  }

  final size = renderView.flutterView.physicalSize;
  final window = size * renderView.flutterView.devicePixelRatio;
  if (paintBoundsWithOffset.top < -50 ||
      paintBoundsWithOffset.left < -50 ||
      paintBoundsWithOffset.bottom > window.height + 50 ||
      paintBoundsWithOffset.right > window.width + 50) {
    return null;
  }

  RenderBox? text;
  void search(RenderObject object) {
    if (text != null) return;
    if (object is RenderParagraph || object is RenderEditable) {
      text = object as RenderBox;
      return;
    }
    object.visitChildren(search);
  }

  search(renderBox);
  if (text == null) {
    throw StateError('No text render object under ${widget.runtimeType}');
  }
  return _Target(
    label,
    text!,
    style.fontSize,
    bold: style.fontWeight == FontWeight.bold,
  );
}

InlineSpan? _textOf(RenderBox box) => switch (box) {
  RenderParagraph() => box.text,
  RenderEditable() => box.text,
  _ => null,
};

void _setTextOf(RenderBox box, InlineSpan span) {
  switch (box) {
    case RenderParagraph():
      box.text = span;
    case RenderEditable():
      box.text = span;
  }
}

void _restyleAll(Map<RenderBox, InlineSpan> originals, {required bool boxes}) {
  originals.forEach((box, span) {
    _setTextOf(box, _restyle(span, boxes: boxes, root: true));
  });
}

const _clear = Color(0x00000000);

/// [span] with its glyphs transparent and without shadows, and with, when
/// [boxes], each run's box filled with the run's text colour.
InlineSpan _restyle(
  InlineSpan span, {
  required bool boxes,
  required bool root,
}) {
  if (span is! TextSpan) return span;
  final style = span.style;
  TextStyle? restyled;
  if (style == null) {
    if (root) throw StateError('Text without a style: "${span.toPlainText()}"');
  } else {
    if (style.foreground != null ||
        style.background != null ||
        style.backgroundColor != null) {
      throw StateError(
        'The TakeTray contrast check does not measure text with a '
        'foreground or background paint: "${span.toPlainText()}"',
      );
    }
    final color = style.color;
    if (root && color == null) {
      throw StateError('Text without a colour: "${span.toPlainText()}"');
    }
    restyled = style.copyWith(
      color: color == null ? null : _clear,
      backgroundColor: boxes ? color : null,
      shadows: root || style.shadows != null ? const <Shadow>[] : null,
      decorationColor: style.decorationColor == null ? null : _clear,
    );
  }
  return TextSpan(
    text: span.text,
    children: span.children
        ?.map((c) => _restyle(c, boxes: boxes, root: false))
        .toList(),
    style: restyled,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    semanticsIdentifier: span.semanticsIdentifier,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}

void _flush(WidgetTester tester) {
  tester.binding.rootPipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
}

class _Shot {
  new(this.pixels, this.width, this.height);

  final ByteData pixels;
  final int width;
  final int height;

  /// The pixel at ([x], [y]) as RGBA.
  int at(int x, int y) => pixels.getUint32((y * width + x) * 4);
}

Future<_Shot> _shoot(WidgetTester tester, RenderView renderView) async {
  _flush(tester);
  final layer = renderView.debugLayer! as OffsetLayer;
  final shot = await tester.binding.runAsync<_Shot>(() async {
    // As Flutter's guideline: logical pixels, so the bounds need no scaling.
    final image = await layer.toImage(
      renderView.paintBounds,
      pixelRatio: 1 / renderView.flutterView.devicePixelRatio,
    );
    try {
      final data = await image.toByteData();
      return _Shot(data!, image.width, image.height);
    } finally {
      image.dispose();
    }
  });
  return shot!;
}

/// The most frequent (box, background) pair among the pixels of [rect] that
/// the boxes changed; (background, background) when none did, which is a
/// ratio of 1.
(Color, Color) _dominantPair(_Shot background, _Shot boxes, Rect rect) {
  final r = rect.intersect(
    Rect.fromLTWH(0, 0, background.width.toDouble(), background.height * 1.0),
  );
  final pairs = <(int, int), int>{};
  final plain = <int, int>{};
  for (var x = r.left.floor(); x < r.right.ceil(); x++) {
    for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
      final b = background.at(x, y);
      final f = boxes.at(x, y);
      plain.update(b, (n) => n + 1, ifAbsent: () => 1);
      if (f != b) pairs.update((f, b), (n) => n + 1, ifAbsent: () => 1);
    }
  }
  if (pairs.isEmpty) {
    if (plain.isEmpty) return (_clear, _clear);
    final bg = _rgbaToColor(_mode(plain, _intBefore));
    return (bg, bg);
  }
  final (f, b) = _mode(pairs, _pairBefore);
  return (_rgbaToColor(f), _rgbaToColor(b));
}

/// The most frequent key; ties go to the key that [before] puts first, so
/// the result does not depend on map order.
K _mode<K extends Object>(
  Map<K, int> counts, [
  bool Function(K a, K b)? before,
]) {
  MapEntry<K, int>? best;
  for (final e in counts.entries) {
    if (best == null ||
        e.value > best.value ||
        (e.value == best.value && (before?.call(e.key, best.key) ?? false))) {
      best = e;
    }
  }
  return best!.key;
}

bool _intBefore(int a, int b) => a < b;

bool _pairBefore((int, int) a, (int, int) b) =>
    a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2);

Color _rgbaToColor(int rgba) =>
    Color(((rgba & 0xFF) << 24) | ((rgba >> 8) & 0xFFFFFF));

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'
    '${c.a < 1 ? ' at ${(c.a * 100).round()} %' : ''}';
