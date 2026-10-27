import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_test_app.dart';
import '../support/tt_text_contrast.dart';

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// [child] alone on a white page, with no theme in the way.
Widget _page(Widget child, {Color background = _white}) => Directionality(
  textDirection: TextDirection.ltr,
  child: ColoredBox(
    color: background,
    child: Center(child: child),
  ),
);

/// Measures with semantics on, as `expectTtAccessible` does.
Future<List<TtTextContrastSample>> _measure(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    return await measureTtTextContrast(tester);
  } finally {
    semantics.dispose();
  }
}

Future<TtTextContrastSample> _only(WidgetTester tester) async {
  final samples = await _measure(tester);
  expect(samples, hasLength(1));
  return samples.single;
}

/// Each channel of `actual` is within one step of [expected] (Skia and
/// [Color.alphaBlend] may round a blend differently).
Matcher _near(Color expected) => predicate<Color>((actual) {
  int ch(Color c, double Function(Color) f) => (f(c) * 255).round();
  for (final f in <double Function(Color)>[
    (c) => c.r,
    (c) => c.g,
    (c) => c.b,
  ]) {
    if ((ch(actual, f) - ch(expected, f)).abs() > 1) return false;
  }
  return actual.a == 1;
}, 'within one step of $expected');

void main() {
  group('measureTtTextContrast', () {
    for (final size in [8.0, 12.0, 14.0, 40.0]) {
      for (final weight in [FontWeight.w200, FontWeight.w400]) {
        testWidgets('finds the exact colours of ${size.toInt()} dp '
            'w${weight.value} text', (tester) async {
          // The thin and small cases are the ones where too few glyph pixels
          // are fully covered for a pixel guess (D-62).
          await tester.pumpWidget(
            _page(
              Text(
                'Measured',
                style: TextStyle(
                  color: const Color(0xFF336699),
                  fontSize: size,
                  fontWeight: weight,
                ),
              ),
              background: const Color(0xFFF0E0D0),
            ),
          );
          final sample = await _only(tester);
          expect(sample.foreground, const Color(0xFF336699));
          expect(sample.background, const Color(0xFFF0E0D0));
          expect(sample.fontSize, size);
        });
      }
    }

    testWidgets('composites translucent text over its background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(
          Text(
            'Half',
            style: TextStyle(
              color: _black.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
      final sample = await _only(tester);
      expect(
        sample.foreground,
        _near(Color.alphaBlend(_black.withValues(alpha: 0.5), _white)),
      );
      expect(sample.background, _white);
    });

    testWidgets(
      'composites a translucent panel and an Opacity above the text',
      (tester) async {
        await tester.pumpWidget(
          _page(
            Opacity(
              opacity: 0.6,
              child: ColoredBox(
                color: const Color(0xFF203040).withValues(alpha: 0.9),
                child: const Text(
                  'Panel',
                  style: TextStyle(color: _white, fontSize: 14),
                ),
              ),
            ),
          ),
        );
        final sample = await _only(tester);
        final panel = Color.alphaBlend(
          const Color(0xFF203040).withValues(alpha: 0.9),
          _white,
        );
        expect(
          sample.background,
          _near(Color.alphaBlend(panel.withValues(alpha: 0.6), _white)),
        );
        // A fully covered glyph pixel is white through the 60 % layer.
        expect(sample.foreground, _near(_white));
      },
    );

    testWidgets('sees a sibling painted under the text', (tester) async {
      await tester.pumpWidget(
        _page(
          const SizedBox(
            width: 200,
            height: 60,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: Color(0xFF8B0000))),
                Center(
                  child: Text(
                    'On red',
                    style: TextStyle(color: _white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final sample = await _only(tester);
      expect(sample.foreground, _white);
      expect(sample.background, const Color(0xFF8B0000));
    });

    testWidgets('measures a TakeTray snack in dark as its theme colours', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 328,
              child: TtSnack(message: 'Clip deleted'),
            ),
          ),
          brightness: Brightness.dark,
        ),
      );
      final scheme = TakeTrayTheme.dark().colorScheme;
      final samples = await _measure(tester);
      final sample = samples.singleWhere((s) => s.text == 'Clip deleted');
      expect(sample.foreground, scheme.onInverseSurface);
      expect(
        sample.background,
        _near(
          Color.alphaBlend(
            scheme.inverseSurface.withValues(alpha: TtMetrics.snackbarOpacity),
            scheme.surface,
          ),
        ),
      );
    });

    testWidgets('gives a ratio of 1 for text in the background colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(
          const Text('Hidden', style: TextStyle(color: _white, fontSize: 14)),
        ),
      );
      final sample = await _only(tester);
      expect(sample.ratio, 1);
    });

    testWidgets('leaves the text and the picture as they were', (tester) async {
      await tester.pumpWidget(
        _page(
          const Text(
            'Kept',
            style: TextStyle(
              color: Color(0xFF336699),
              fontSize: 14,
              shadows: [Shadow(blurRadius: 2)],
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text('Kept'));
      final span = paragraph.text;
      Future<Uint8List> shot() async {
        final view = tester.binding.renderViews.single;
        final layer = view.debugLayer! as OffsetLayer;
        final bytes = await tester.runAsync(() async {
          final image = await layer.toImage(view.paintBounds);
          final data = await image.toByteData();
          image.dispose();
          return data!.buffer.asUint8List();
        });
        return bytes!;
      }

      final before = await shot();
      await _measure(tester);
      expect(identical(paragraph.text, span), isTrue);
      expect(await shot(), before);
    });
  });

  group('TtTextContrastGuideline', () {
    // #767676 on white is 4.54:1, #949494 is 3.03:1.
    Future<void> pump(
      WidgetTester tester, {
      required Color color,
      required double size,
      FontWeight weight = FontWeight.normal,
    }) => tester.pumpWidget(
      _page(
        Text(
          'Sample',
          style: TextStyle(color: color, fontSize: size, fontWeight: weight),
        ),
      ),
    );

    Future<void> expectGuideline(WidgetTester tester, Matcher matcher) async {
      final semantics = tester.ensureSemantics();
      try {
        await expectLater(tester, matcher);
      } finally {
        semantics.dispose();
      }
    }

    testWidgets('passes 4.5:1 text at 14 dp', (tester) async {
      await pump(tester, color: const Color(0xFF767676), size: 14);
      await expectGuideline(tester, meetsGuideline(ttTextContrastGuideline));
    });

    testWidgets('fails 3:1 text at 14 dp', (tester) async {
      await pump(tester, color: const Color(0xFF949494), size: 14);
      await expectGuideline(
        tester,
        doesNotMeetGuideline(ttTextContrastGuideline),
      );
    });

    testWidgets('passes 3:1 text at 18 dp and bold at 14 dp', (tester) async {
      await pump(tester, color: const Color(0xFF949494), size: 18);
      await expectGuideline(tester, meetsGuideline(ttTextContrastGuideline));
      await pump(
        tester,
        color: const Color(0xFF949494),
        size: 14,
        weight: FontWeight.bold,
      );
      await expectGuideline(tester, meetsGuideline(ttTextContrastGuideline));
    });

    testWidgets('fails text as light as its background', (tester) async {
      await pump(tester, color: _white, size: 40);
      await expectGuideline(
        tester,
        doesNotMeetGuideline(ttTextContrastGuideline),
      );
    });

    testWidgets('names the text and both colours when it fails', (
      tester,
    ) async {
      await pump(tester, color: const Color(0xFFCCCCCC), size: 16);
      final semantics = tester.ensureSemantics();
      final evaluation = await ttTextContrastGuideline.evaluate(tester);
      semantics.dispose();
      expect(evaluation.passed, isFalse);
      expect(evaluation.reason, contains('"Sample"'));
      expect(evaluation.reason, contains('#cccccc on #ffffff'));
    });
  });
}
