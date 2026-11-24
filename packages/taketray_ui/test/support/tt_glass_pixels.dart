import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tt_test_app.dart';

// Pixel tests for glass (Phase 12, D-172).
//
// A blur cannot be seen in a widget tree, so these tests draw sharp black and
// white stripes behind the glass, photograph the result and measure how much
// of the stripes' contrast is left. The numbers are chosen so a blur of 3 dp
// (the scrim's) is clearly below the line and a blur of 1 dp is clearly above
// it.
//
// The flutter_tester renderer is not the S24's Impeller on Vulkan, so a pass
// here is not proof of what the phone draws (the phone lost the blur of a
// scrim with a Material child, and of a ramped blur, while this renderer drew
// both). The structure checks (`expectGlassStructure`, `ttScrimFilter` and
// `expectBlurFilter`) pin what the phone proved; the pixel checks pin that
// there is a blur at all.

/// The stripes' period: 4 dp black, then 4 dp white.
const double ttStripePeriod = 8;

/// A blurred area keeps under this share of the contrast the fill lets
/// through. A blur of 3 dp over [ttStripePeriod] stripes keeps about a tenth.
const double ttBlurredShare = 0.5;

/// The key of the boundary [ttPixelApp] puts around the whole navigator.
const Key ttCaptureKey = ValueKey('tt-capture');

/// Sharp black and white stripes that change colour along [along], filling
/// the space they are given. The first stripe is black.
Widget ttStripes({Axis along = Axis.horizontal}) =>
    SizedBox.expand(child: CustomPaint(painter: _StripesPainter(along)));

class _StripesPainter extends CustomPainter {
  const new(this.along);

  final Axis along;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..isAntiAlias = false;
    final black = Paint()
      ..color = const Color(0xFF000000)
      ..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, white);
    final length = along == Axis.horizontal ? size.width : size.height;
    for (var at = 0.0; at < length; at += ttStripePeriod) {
      const half = ttStripePeriod / 2;
      canvas.drawRect(
        along == Axis.horizontal
            ? Rect.fromLTWH(at, 0, half, size.height)
            : Rect.fromLTWH(0, at, size.width, half),
        black,
      );
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => oldDelegate.along != along;
}

/// `ttTestApp(home)` with a `RepaintBoundary` (keyed [ttCaptureKey]) around
/// the whole navigator, so [TtPixels.capture] sees routes and barriers too.
Widget ttPixelApp(
  Widget home, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  double textScale = 1,
}) => ttTestApp(
  home,
  brightness: brightness,
  disableAnimations: disableAnimations,
  textScale: textScale,
  captureKey: ttCaptureKey,
);

/// Runs [body] with `BoxShadow`s blurring, as on a phone.
///
/// The test binding turns shadow blurs off (`debugDisableShadows`, so a
/// shadow is a sharp copy of its shape); a test that measures a soft shadow's
/// reach needs them back while it pumps and photographs. The binding insists
/// the flag is back at the end of the test, so this restores it itself.
Future<T> ttWithBlurredShadows<T>(Future<T> Function() body) async {
  final before = painting.debugDisableShadows;
  painting.debugDisableShadows = false;
  try {
    return await body();
  } finally {
    painting.debugDisableShadows = before;
  }
}

/// A photograph of what [ttPixelApp] draws, to measure.
class TtPixels {
  new _(this._rgba, this.width, this.height);

  final ByteData _rgba;

  /// The photograph's size in pixels (the view's size, at pixel ratio 1).
  final int width;
  final int height;

  /// The [ttCaptureKey] boundary at pixel ratio 1 (tests set the view to
  /// 360 × 800 physical, with a `devicePixelRatio` of 1).
  static Future<TtPixels> capture(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(ttCaptureKey),
    );
    final taken = await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final data = await image.toByteData();
        return TtPixels._(data!, image.width, image.height);
      } finally {
        image.dispose();
      }
    });
    return taken!;
  }

  /// Luma 0..1 of the pixel at ([x], [y]): (0.2126 R + 0.7152 G + 0.0722 B)
  /// / 255 of the sRGB bytes (not WCAG luminance), so a fill of alpha a
  /// scales it by (1 − a).
  double _luma(int x, int y) {
    final at = (y * width + x) * 4;
    return (0.2126 * _rgba.getUint8(at) +
            0.7152 * _rgba.getUint8(at + 1) +
            0.0722 * _rgba.getUint8(at + 2)) /
        255;
  }

  /// The pixels [rect] covers, inside the photograph.
  ({int left, int top, int right, int bottom}) _pixels(Rect rect) {
    final left = rect.left.floor().clamp(0, width);
    final top = rect.top.floor().clamp(0, height);
    final right = rect.right.ceil().clamp(0, width);
    final bottom = rect.bottom.ceil().clamp(0, height);
    if (right <= left || bottom <= top) {
      throw ArgumentError.value(rect, 'rect', 'is outside the photograph');
    }
    return (left: left, top: top, right: right, bottom: bottom);
  }

  /// The mean, over the lines of [rect] across [along], of the line's
  /// (max − min) luma, 0..1.
  double edgeContrast(Rect rect, {Axis along = Axis.horizontal}) {
    final p = _pixels(rect);
    final horizontal = along == Axis.horizontal;
    final lines = horizontal ? p.bottom - p.top : p.right - p.left;
    var sum = 0.0;
    for (var line = 0; line < lines; line++) {
      var low = 1.0;
      var high = 0.0;
      final steps = horizontal ? p.right - p.left : p.bottom - p.top;
      for (var step = 0; step < steps; step++) {
        final luma = horizontal
            ? _luma(p.left + step, p.top + line)
            : _luma(p.left + line, p.top + step);
        if (luma < low) low = luma;
        if (luma > high) high = luma;
      }
      sum += high - low;
    }
    return sum / lines;
  }

  /// The mean luma, 0..1, of the pixels [rect] covers.
  double meanLuma(Rect rect) {
    final p = _pixels(rect);
    var sum = 0.0;
    for (var y = p.top; y < p.bottom; y++) {
      for (var x = p.left; x < p.right; x++) {
        sum += _luma(x, y);
      }
    }
    return sum / ((p.right - p.left) * (p.bottom - p.top));
  }

  /// The colour of the pixel at [point].
  Color colorAt(Offset point) {
    final x = point.dx.floor();
    final y = point.dy.floor();
    if (x < 0 || y < 0 || x >= width || y >= height) {
      throw ArgumentError.value(point, 'point', 'is outside the photograph');
    }
    final at = (y * width + x) * 4;
    return Color.fromARGB(
      _rgba.getUint8(at + 3),
      _rgba.getUint8(at),
      _rgba.getUint8(at + 1),
      _rgba.getUint8(at + 2),
    );
  }
}

/// Fails (a [TestFailure]) unless [contrast] is under [ttBlurredShare] of
/// `(1 − fillOpacity) × sharp`: the contrast a fill of [fillOpacity] lets
/// through the sharp stripes of contrast [sharp], so the blur has taken most
/// of the rest.
void expectBlurred(
  double contrast, {
  required double sharp,
  required double fillOpacity,
}) {
  final limit = ttBlurredShare * (1 - fillOpacity) * sharp;
  if (!(contrast < limit)) {
    throw TestFailure(
      'Not blurred: the stripes keep a contrast of $contrast, which is not '
      'under $limit ($ttBlurredShare × (1 − $fillOpacity) × $sharp).',
    );
  }
}

/// Fails (a [TestFailure]) unless [contrast] is at least 0.9 of
/// `(1 − fillOpacity) × sharp`: the stripes are still sharp under the fill.
void expectSharp(
  double contrast, {
  required double sharp,
  double fillOpacity = 0,
}) {
  final limit = 0.9 * (1 - fillOpacity) * sharp;
  if (!(contrast >= limit)) {
    throw TestFailure(
      'Not sharp: the stripes keep a contrast of $contrast, which is under '
      '$limit (0.9 × (1 − $fillOpacity) × $sharp).',
    );
  }
}

List<Element> _filtersUnder(Finder of) {
  final filters = find
      .descendant(of: of, matching: find.byType(BackdropFilter))
      .evaluate()
      .toList();
  if (filters.isEmpty) {
    throw TestFailure(
      'No BackdropFilter under ${of.describeMatch(Plurality.zero)}.',
    );
  }
  return filters;
}

/// Every `BackdropFilter` under [of] (at least one) is a blur of [sigma].
void expectBlurFilter(WidgetTester tester, Finder of, double sigma) {
  for (final element in _filtersUnder(of)) {
    expect(
      (element.widget as BackdropFilter).filter,
      ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
  }
}

/// The `BackdropFilter` that is an ancestor of the topmost `ModalBarrier`: a
/// route's scrim (an `AnimatedModalBarrier` builds one inside it).
Finder ttScrimFilter() => find.ancestor(
  of: find.byType(ModalBarrier).last,
  matching: find.byType(BackdropFilter),
);

/// Widgets that lay out or catch touches but paint nothing: the glass check
/// looks through them for the first thing that paints.
bool _paintsNothing(Widget widget) =>
    widget is Padding ||
    widget is Align ||
    widget is SizedBox ||
    widget is ConstrainedBox ||
    widget is LimitedBox ||
    widget is UnconstrainedBox ||
    widget is OverflowBox ||
    widget is FractionallySizedBox ||
    widget is IntrinsicHeight ||
    widget is IntrinsicWidth ||
    widget is Semantics ||
    widget is MergeSemantics ||
    widget is ExcludeSemantics ||
    widget is IgnorePointer ||
    widget is AbsorbPointer ||
    widget is MouseRegion ||
    widget is Listener;

/// What the first thing a `BackdropFilter` paints over is, or null when it is
/// a `ColoredBox` or a coloured `DecoratedBox` (the fill).
String? _notAFill(Element filter) {
  var element = filter;
  while (true) {
    Element? child;
    element.visitChildren((e) => child ??= e);
    if (child == null) return 'nothing under it paints';
    element = child!;
    final widget = element.widget;
    if (widget is Material) return 'a Material';
    if (widget is ColoredBox) return null;
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration && decoration.color != null) return null;
      return 'a DecoratedBox with no colour';
    }
    if (_paintsNothing(widget)) continue;
    if (widget is RenderObjectWidget) return 'a ${widget.runtimeType}';
  }
}

/// For every `BackdropFilter` under [of] (at least one): the first thing under
/// it that paints (looking through layout-only single-child widgets) is a
/// `ColoredBox` or a coloured `DecoratedBox`, never a `Material`.
///
/// The S24 lost the blur behind a `Material` child (the reel cover pill, spec
/// "What the phone showed", F) and kept it behind a `ColoredBox` fill with the
/// ink on a transparent `Material` inside it (K, T).
void expectGlassStructure(WidgetTester tester, Finder of) {
  for (final element in _filtersUnder(of)) {
    final wrong = _notAFill(element);
    if (wrong != null) {
      throw TestFailure(
        'A BackdropFilter is filled with $wrong; it must be a ColoredBox or a '
        'coloured DecoratedBox (a Material child lost the blur on the S24).',
      );
    }
  }
}

/// Opens the page's dialog or sheet (the tap on the text "open" in [opener])
/// and checks the scrim blurs by 3 dp from the first frame to the end of the
/// close, always the same widget, never a ramp (D-172).
///
/// The close (a tap on the scrim) is checked only with animations on: with
/// them off the route is gone at the first frame.
Future<void> expectSteadyScrimBlur(
  WidgetTester tester, {
  required Widget opener,
  bool disableAnimations = false,
}) async {
  BackdropFilter scrim() => tester.widget<BackdropFilter>(ttScrimFilter());
  final steady = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3);
  await tester.pumpWidget(
    ttTestApp(opener, disableAnimations: disableAnimations),
  );
  await tester.tap(find.text('open'));
  await tester.pump(); // the route's animation is at 0
  expect(scrim().filter, steady);
  final first = tester.element(ttScrimFilter());
  if (disableAnimations) return;
  for (final ms in [16, 100, 200, 300]) {
    await tester.pump(Duration(milliseconds: ms));
    expect(scrim().filter, steady, reason: 'after $ms ms');
    expect(
      tester.element(ttScrimFilter()),
      same(first),
      reason: 'no widget swap after $ms ms',
    );
  }
  // Close it with a tap on the scrim, top left, away from the panel.
  await tester.tapAt(const Offset(5, 5));
  await tester.pump();
  expect(scrim().filter, steady, reason: 'the first frame of the close');
  await tester.pump(const Duration(milliseconds: 100));
  expect(scrim().filter, steady, reason: '100 ms into the close');
  await tester.pumpAndSettle();
}

/// Draws [ttStripes] under [opener], opens it (the tap on the text "open"),
/// and checks the page behind is blurred and dimmed by [dim] (the dialog and
/// sheet scrim: black at 50 %, the default; a menu's barrier does not dim, so
/// it passes 0).
///
/// The measured rectangle is 120 × 40 dp at (8, 8): on the scrim, outside any
/// panel of a dialog or a sheet.
Future<void> expectPageBlurredAndDimmed(
  WidgetTester tester, {
  required Widget opener,
  double dim = .5,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ttPixelApp(Stack(fit: StackFit.expand, children: [ttStripes(), opener])),
  );
  const rect = Rect.fromLTWH(8, 8, 120, 40);
  final before = await TtPixels.capture(tester);
  final sharp = before.edgeContrast(rect);
  final luma0 = before.meanLuma(rect);
  expectSharp(sharp, sharp: 1);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  final after = await TtPixels.capture(tester);
  expectBlurred(after.edgeContrast(rect), sharp: sharp, fillOpacity: dim);
  expect(after.meanLuma(rect), closeTo(luma0 * (1 - dim), .03));
}
