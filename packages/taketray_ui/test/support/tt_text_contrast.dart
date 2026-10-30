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
/// guess depends on how the font is rasterised: on Linux a 12 to 14 dp
/// glyph has so few fully covered pixels that an anti-aliased edge pixel
/// wins, and text that is fine reads as 1.2:1 (likely FreeType vs the Mac's
/// CoreText; inferred, see D-62). This guideline checks
/// the same texts with the same thresholds, but measures each one from three
/// screenshots in which no glyph is drawn:
///
/// - the background: every text in the view painted transparent (and without
///   shadows), so the image holds exactly what is behind the glyphs;
/// - the foreground: every text run replaced by a solid box in the text's own
///   colour (its `backgroundColor`), so each box pixel is exactly what a
///   fully covered glyph pixel is after every opacity, blend and translucent
///   layer above and below it;
/// - the probe: the same boxes in the inverted colour, so a box pixel shows
///   up even where the text colour equals the background.
///
/// Inside the text's paint bounds, the pixels that the foreground or the
/// probe changed are the text's boxes. Pixels on a box edge (a 4-neighbour
/// outside the boxes: partly covered rows and columns, clip edges) are left
/// out. Each remaining pixel has a (foreground, background) pair; the text's
/// ratio is the worst one, ignoring the worst [ignoredShare] of its pixels so
/// that a few stray pixels cannot decide it. So at least 98 % of the text's
/// fully covered pixels meet the reported ratio, and a band under the
/// threshold (text half over a light area, the light end of a gradient)
/// fails. Boxes and fills have no glyph edges, so the result does not depend
/// on the font rasteriser. Text shadows are left out, which can only lower
/// the ratio.
///
/// Besides the texts Flutter's guideline picks (semantics nodes whose label
/// is the text), every other shown text is measured too (a hit-testable,
/// non-empty [Text] or [EditableText], unless its semantics are disabled or
/// hidden), so text merged into a parent label cannot pass unmeasured.
///
/// Every text render object is restored, and the frame repainted, before
/// this returns.
class TtTextContrastGuideline extends AccessibilityGuideline {
  /// The guideline; use [ttTextContrastGuideline], or
  /// [ttTextContrastIncludingDisabledGuideline] to measure disabled text too.
  const new({this.includeDisabled = false});

  /// Whether text whose semantics are disabled is measured as well (it is
  /// exempt in Flutter's guideline, as WCAG exempts inactive controls). A
  /// row that is "off" but must keep AA contrast (D-79) is checked this way.
  final bool includeDisabled;

  /// The thresholds and text selection of Flutter's guideline.
  static const _flutter = MinimumTextContrastGuideline();

  /// As Flutter's guideline: a ratio 0.01 under the target still passes.
  static const double _tolerance = -0.01;

  /// The share of a text's fully covered pixels whose worst ratios are
  /// ignored: 2 %.
  static const double ignoredShare = 0.02;

  @override
  String get description =>
      'Text contrast should follow WCAG guidelines '
      '(resolved colours, TakeTray D-62)';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var result = const Evaluation.pass();
    final samples = await measureTtTextContrast(
      tester,
      includeDisabled: includeDisabled,
    );
    for (final sample in samples) {
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

/// [ttTextContrastGuideline] that also measures text whose semantics are
/// disabled, for rows and days that are off but must stay readable (D-79).
const AccessibilityGuideline ttTextContrastIncludingDisabledGuideline =
    TtTextContrastGuideline(includeDisabled: true);

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
  WidgetTester tester, {
  bool includeDisabled = false,
}) async {
  final samples = <TtTextContrastSample>[];
  for (final renderView in tester.binding.renderViews) {
    final targets = <_Target>[];
    _collectTargets(
      renderView.owner!.semanticsOwner!.rootSemanticsNode!,
      renderView,
      targets,
      includeDisabled: includeDisabled,
    );
    _collectShownTexts(
      tester,
      renderView,
      targets,
      includeDisabled: includeDisabled,
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
    late final _Shot probe;
    try {
      _restyleAll(originals, _Paint.hidden);
      background = await _shoot(tester, renderView);
      _restyleAll(originals, _Paint.boxes);
      boxes = await _shoot(tester, renderView);
      _restyleAll(originals, _Paint.probe);
      probe = await _shoot(tester, renderView);
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
      final (fg, bg) = _worstPair(background, boxes, probe, rect);
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
  List<_Target> out, {
  required bool includeDisabled,
}) {
  final disabled =
      !includeDisabled && node.flagsCollection.isEnabled == ui.Tristate.isFalse;
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
    _collectTargets(child, renderView, out, includeDisabled: includeDisabled);
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
  return _textTarget(element, label, renderView);
}

/// [element] (a [Text] or [EditableText]) as a target, or null when it is
/// more than 50 px off screen (Flutter's rule).
_Target? _textTarget(Element element, String label, RenderView renderView) {
  final renderBox = element.renderObject! as RenderBox;
  final paintBoundsWithOffset = MatrixUtils.transformRect(
    renderBox.getTransformTo(null),
    renderBox.paintBounds.inflate(4),
  );
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

/// Adds every shown text that the semantics walk did not reach: a
/// hit-testable [Text] or [EditableText] with something other than spaces in
/// it, typically one whose semantics are merged into a parent label (a tile,
/// a chip) or excluded. As in Flutter's walk, text whose semantics node (after
/// merging) is disabled, hidden or invisible is exempt, and so is text more
/// than 50 px off screen. This is what keeps the check from passing because
/// it measured nothing (D-62).
void _collectShownTexts(
  WidgetTester tester,
  RenderView renderView,
  List<_Target> targets, {
  required bool includeDisabled,
}) {
  final reached = {for (final t in targets) t.text};
  for (final element
      in find
          .byWidgetPredicate((w) => w is Text || w is EditableText)
          .hitTestable()
          .evaluate()) {
    final label = switch (element.widget) {
      final Text t => t.data ?? t.textSpan?.toPlainText() ?? '',
      final EditableText t => t.controller.text,
      _ => '',
    };
    if (label.trim().isEmpty) continue;
    if (tester.viewOf(find.byElementPredicate((e) => e == element)) !=
        renderView.flutterView) {
      continue;
    }
    final node = _effectiveSemantics(element.renderObject!);
    if (node != null &&
        (node.isInvisible ||
            node.flagsCollection.isHidden ||
            (!includeDisabled &&
                node.flagsCollection.isEnabled == ui.Tristate.isFalse))) {
      continue;
    }
    final target = _textTarget(element, label, renderView);
    if (target == null || reached.contains(target.text)) continue;
    reached.add(target.text);
    targets.add(target);
  }
}

/// The semantics node that [object] ends up in, after merging.
SemanticsNode? _effectiveSemantics(RenderObject object) {
  RenderObject? current = object;
  SemanticsNode? node;
  while (current != null && node == null) {
    node = current.debugSemantics;
    current = current.parent;
  }
  while (node != null && node.isMergedIntoParent) {
    node = node.parent;
  }
  return node;
}

/// What [_restyle] draws in place of the glyphs.
enum _Paint {
  /// Nothing: the glyphs are transparent.
  hidden,

  /// Each run's box in the run's text colour.
  boxes,

  /// Each run's box in the inverse of the run's text colour.
  probe,
}

void _restyleAll(Map<RenderBox, InlineSpan> originals, _Paint paint) {
  originals.forEach((box, span) {
    _setTextOf(box, _restyle(span, paint: paint, root: true));
  });
}

Color _inverse(Color c) =>
    Color.from(alpha: c.a, red: 1 - c.r, green: 1 - c.g, blue: 1 - c.b);

const _clear = Color(0x00000000);

/// [span] with its glyphs transparent and without shadows, and each run's
/// box filled as [paint] says.
InlineSpan _restyle(
  InlineSpan span, {
  required _Paint paint,
  required bool root,
  Color? inherited,
}) {
  if (span is! TextSpan) return span;
  final style = span.style;
  if (style != null &&
      (style.foreground != null ||
          style.background != null ||
          style.backgroundColor != null)) {
    throw StateError(
      'The TakeTray contrast check does not measure text with a '
      'foreground or background paint: "${span.toPlainText()}"',
    );
  }
  final color = style?.color;
  final effective = color ?? inherited;
  if (effective == null && (span.text ?? '').isNotEmpty) {
    throw StateError('Text without a colour: "${span.text}"');
  }
  final restyled = style?.copyWith(
    color: color == null ? null : _clear,
    backgroundColor: color == null
        ? null
        : switch (paint) {
            _Paint.hidden => null,
            _Paint.boxes => color,
            _Paint.probe => _inverse(color),
          },
    shadows: root || style.shadows != null ? const <Shadow>[] : null,
    decorationColor: style.decorationColor == null ? null : _clear,
  );
  return TextSpan(
    text: span.text,
    children: span.children
        ?.map(
          (c) => _restyle(c, paint: paint, root: false, inherited: effective),
        )
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

/// The worst (box, background) pair among the fully covered box pixels of
/// [rect], ignoring the worst [TtTextContrastGuideline.ignoredShare] of them;
/// (background, background), a ratio of 1, when no box pixel is visible.
(Color, Color) _worstPair(
  _Shot background,
  _Shot boxes,
  _Shot probe,
  Rect rect,
) {
  final r = rect.intersect(
    Rect.fromLTWH(0, 0, background.width.toDouble(), background.height * 1.0),
  );
  final left = r.left.floor();
  final top = r.top.floor();
  final w = r.isEmpty ? 0 : r.right.ceil() - left;
  final h = r.isEmpty ? 0 : r.bottom.ceil() - top;
  final inBox = List<bool>.filled(w * h, false);
  final plain = <int, int>{};
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final b = background.at(left + x, top + y);
      plain.update(b, (n) => n + 1, ifAbsent: () => 1);
      inBox[y * w + x] =
          boxes.at(left + x, top + y) != b || probe.at(left + x, top + y) != b;
    }
  }
  bool covered(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && inBox[y * w + x];

  Map<(int, int), int> pairsWhere(bool Function(int x, int y) keep) {
    final pairs = <(int, int), int>{};
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!keep(x, y)) continue;
        final key = (
          boxes.at(left + x, top + y),
          background.at(left + x, top + y),
        );
        pairs.update(key, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return pairs;
  }

  var pairs = pairsWhere(
    (x, y) =>
        covered(x, y) &&
        covered(x - 1, y) &&
        covered(x + 1, y) &&
        covered(x, y - 1) &&
        covered(x, y + 1),
  );
  // Text too small for a box pixel with four box neighbours: use them all.
  if (pairs.isEmpty) pairs = pairsWhere(covered);
  if (pairs.isEmpty) {
    if (plain.isEmpty) return (_clear, _clear);
    final bg = _rgbaToColor(_mode(plain, _intBefore));
    return (bg, bg);
  }

  final ranked =
      pairs.entries
          .map((e) => (e.key, e.value, _ratio(e.key.$1, e.key.$2)))
          .toList()
        ..sort((a, b) {
          final byRatio = a.$3.compareTo(b.$3);
          return byRatio != 0
              ? byRatio
              : (_pairBefore(a.$1, b.$1) ? -1 : (a.$1 == b.$1 ? 0 : 1));
        });
  final total = pairs.values.fold(0, (a, b) => a + b);
  final ignored = total * TtTextContrastGuideline.ignoredShare;
  var seen = 0;
  for (final (pair, count, _) in ranked) {
    seen += count;
    if (seen > ignored) {
      return (_rgbaToColor(pair.$1), _rgbaToColor(pair.$2));
    }
  }
  final (f, b) = ranked.last.$1;
  return (_rgbaToColor(f), _rgbaToColor(b));
}

double _ratio(int fgRgba, int bgRgba) => TtTextContrastSample(
  text: '',
  foreground: _rgbaToColor(fgRgba),
  background: _rgbaToColor(bgRgba),
  fontSize: null,
  bold: false,
).ratio;

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
