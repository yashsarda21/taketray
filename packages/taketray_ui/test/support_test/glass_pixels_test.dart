import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tt_glass_pixels.dart';

/// A 360 × 800 phone at pixel ratio 1, as the pixel tests need.
void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A rectangle well away from the screen's edges (a blur reads past the edge).
const _rect = Rect.fromLTWH(100, 300, 120, 40);

/// The stripes with a blur of [sigma] and a white fill of [fill] over them.
Widget _glass(double sigma, double fill) => Stack(
  fit: StackFit.expand,
  children: [
    ttStripes(),
    Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: ColoredBox(color: Color.fromRGBO(255, 255, 255, fill)),
      ),
    ),
  ],
);

Future<({double sharp, double contrast})> _measure(
  WidgetTester tester,
  Widget glass,
) async {
  _phone(tester);
  await tester.pumpWidget(ttPixelApp(ttStripes()));
  final sharp = (await TtPixels.capture(tester)).edgeContrast(_rect);
  await tester.pumpWidget(ttPixelApp(glass));
  final contrast = (await TtPixels.capture(tester)).edgeContrast(_rect);
  return (sharp: sharp, contrast: contrast);
}

void main() {
  group('the stripes', () {
    testWidgets('bare stripes are sharp', (tester) async {
      _phone(tester);
      await tester.pumpWidget(ttPixelApp(ttStripes()));
      final pixels = await TtPixels.capture(tester);
      expect(pixels.edgeContrast(_rect), greaterThan(0.9));
      expectSharp(pixels.edgeContrast(_rect), sharp: 1);
    });

    testWidgets('are 4 dp black, then 4 dp white, starting black', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(ttPixelApp(ttStripes()));
      final pixels = await TtPixels.capture(tester);
      expect(pixels.colorAt(const Offset(0, 5)), const Color(0xFF000000));
      expect(pixels.colorAt(const Offset(3, 5)), const Color(0xFF000000));
      expect(pixels.colorAt(const Offset(4, 5)), const Color(0xFFFFFFFF));
      expect(pixels.colorAt(const Offset(7, 5)), const Color(0xFFFFFFFF));
      expect(pixels.colorAt(const Offset(8, 5)), const Color(0xFF000000));
      // They change along x only.
      expect(pixels.colorAt(const Offset(2, 700)), const Color(0xFF000000));
    });

    testWidgets('a whole number of periods has a mean luma of a half', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(ttPixelApp(ttStripes()));
      final pixels = await TtPixels.capture(tester);
      expect(
        pixels.meanLuma(const Rect.fromLTWH(8, 8, 120, 40)),
        closeTo(0.5, 1e-9),
      );
    });

    testWidgets('vertical stripes change along y, not x', (tester) async {
      _phone(tester);
      await tester.pumpWidget(ttPixelApp(ttStripes(along: Axis.vertical)));
      final pixels = await TtPixels.capture(tester);
      expect(pixels.colorAt(const Offset(5, 2)), const Color(0xFF000000));
      expect(pixels.colorAt(const Offset(5, 6)), const Color(0xFFFFFFFF));
      expect(
        pixels.edgeContrast(_rect, along: Axis.vertical),
        greaterThan(0.9),
      );
      expect(pixels.edgeContrast(_rect), lessThan(0.01));
    });
  });

  group('expectBlurred', () {
    testWidgets('sigma 0 is not blurred', (tester) async {
      final m = await _measure(tester, _glass(0, .5));
      expect(
        () => expectBlurred(m.contrast, sharp: m.sharp, fillOpacity: .5),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('sigma 1 is not blurred enough', (tester) async {
      final m = await _measure(tester, _glass(1, .5));
      expect(
        () => expectBlurred(m.contrast, sharp: m.sharp, fillOpacity: .5),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('sigma 3 is blurred under a half fill', (tester) async {
      final m = await _measure(tester, _glass(3, .5));
      expectBlurred(m.contrast, sharp: m.sharp, fillOpacity: .5);
    });

    testWidgets('sigma 12 is blurred under a 94 % fill', (tester) async {
      final m = await _measure(tester, _glass(12, .94));
      expectBlurred(m.contrast, sharp: m.sharp, fillOpacity: .94);
    });

    testWidgets('an unblurred 94 % fill is not blurred', (tester) async {
      final m = await _measure(tester, _glass(0, .94));
      expect(
        () => expectBlurred(m.contrast, sharp: m.sharp, fillOpacity: .94),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('expectSharp', () {
    testWidgets('an unblurred half fill is sharp', (tester) async {
      final m = await _measure(tester, _glass(0, .5));
      expectSharp(m.contrast, sharp: m.sharp, fillOpacity: .5);
    });

    testWidgets('a blur of 3 is not sharp', (tester) async {
      final m = await _measure(tester, _glass(3, .5));
      expect(
        () => expectSharp(m.contrast, sharp: m.sharp, fillOpacity: .5),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('the fill dims the luma', () {
    testWidgets('a black half fill halves the mean luma', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        ttPixelApp(
          Stack(
            fit: StackFit.expand,
            children: [
              ttStripes(),
              const ColoredBox(color: Color.fromRGBO(0, 0, 0, .5)),
            ],
          ),
        ),
      );
      final pixels = await TtPixels.capture(tester);
      expect(
        pixels.meanLuma(const Rect.fromLTWH(8, 8, 120, 40)),
        closeTo(.25, .01),
      );
    });
  });

  group('expectBlurFilter', () {
    Widget filtered(double sigma) => BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: const ColoredBox(color: Color(0x80FFFFFF)),
    );

    testWidgets('passes for the sigma it is given', (tester) async {
      await tester.pumpWidget(ttPixelApp(filtered(3)));
      expectBlurFilter(tester, find.byType(Scaffold), 3);
    });

    testWidgets('fails for another sigma', (tester) async {
      await tester.pumpWidget(ttPixelApp(filtered(1)));
      expect(
        () => expectBlurFilter(tester, find.byType(Scaffold), 3),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('fails when one of two filters is another sigma', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttPixelApp(Column(children: [filtered(3), filtered(2)])),
      );
      expect(
        () => expectBlurFilter(tester, find.byType(Scaffold), 3),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('fails when there is no filter at all', (tester) async {
      await tester.pumpWidget(ttPixelApp(const SizedBox()));
      expect(
        () => expectBlurFilter(tester, find.byType(Scaffold), 3),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('expectGlassStructure', () {
    Widget over(Widget child) => BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: child,
    );

    Future<void> expectFails(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(ttPixelApp(over(child)));
      expect(
        () => expectGlassStructure(tester, find.byType(Scaffold)),
        throwsA(isA<TestFailure>()),
      );
    }

    testWidgets('a Material child fails the structure check', (tester) async {
      await expectFails(
        tester,
        const Material(color: Color(0x80FFFFFF), child: SizedBox(width: 50)),
      );
    });

    testWidgets('a ColoredBox fill with a transparent Material passes', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttPixelApp(
          over(
            const ColoredBox(
              color: Color(0x80FFFFFF),
              child: Material(
                type: MaterialType.transparency,
                child: Text('ink'),
              ),
            ),
          ),
        ),
      );
      expectGlassStructure(tester, find.byType(Scaffold));
    });

    testWidgets('a coloured DecoratedBox passes', (tester) async {
      await tester.pumpWidget(
        ttPixelApp(
          over(
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x80FFFFFF),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
        ),
      );
      expectGlassStructure(tester, find.byType(Scaffold));
    });

    testWidgets('a DecoratedBox with no colour fails', (tester) async {
      await expectFails(
        tester,
        const DecoratedBox(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(BorderSide()),
          ),
        ),
      );
    });

    testWidgets('looks through padding, size and semantics', (tester) async {
      await tester.pumpWidget(
        ttPixelApp(
          over(
            Padding(
              padding: const EdgeInsets.all(4),
              child: Semantics(
                label: 'glass',
                child: const SizedBox(
                  width: 50,
                  height: 50,
                  child: ColoredBox(color: Color(0x80FFFFFF)),
                ),
              ),
            ),
          ),
        ),
      );
      expectGlassStructure(tester, find.byType(Scaffold));
    });

    testWidgets('a Material below layout-only widgets still fails', (
      tester,
    ) async {
      await expectFails(
        tester,
        const Padding(
          padding: EdgeInsets.all(4),
          child: Material(child: SizedBox(width: 50, height: 50)),
        ),
      );
    });

    testWidgets('a Material below the fill is not the first painter', (
      tester,
    ) async {
      // The check is about what the filter paints over first, not about every
      // descendant: a Material inside the fill is the point of K and T.
      await tester.pumpWidget(
        ttPixelApp(
          over(
            const ColoredBox(
              color: Color(0x80FFFFFF),
              child: Material(child: SizedBox(width: 50, height: 50)),
            ),
          ),
        ),
      );
      expectGlassStructure(tester, find.byType(Scaffold));
    });

    testWidgets('another painter first (a Text) fails', (tester) async {
      await expectFails(tester, const Text('on the bare filter'));
    });

    testWidgets('nothing at all under the filter fails', (tester) async {
      await tester.pumpWidget(ttPixelApp(over(const SizedBox())));
      expect(
        () => expectGlassStructure(tester, find.byType(Scaffold)),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('no filter at all fails', (tester) async {
      await tester.pumpWidget(ttPixelApp(const SizedBox()));
      expect(
        () => expectGlassStructure(tester, find.byType(Scaffold)),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('one bad filter among good ones fails', (tester) async {
      await tester.pumpWidget(
        ttPixelApp(
          Column(
            children: [
              over(const ColoredBox(color: Color(0x80FFFFFF))),
              over(const Material(child: SizedBox(width: 50, height: 50))),
            ],
          ),
        ),
      );
      expect(
        () => expectGlassStructure(tester, find.byType(Scaffold)),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
