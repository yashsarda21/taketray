import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/outside_shadow.dart';
import 'package:taketray_ui/src/components/internal/saturation.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_glass_pixels.dart';
import '../support/tt_test_app.dart';

void main() {
  group('TtGlass', () {
    testWidgets('shows its child inside a backdrop blur', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(child: TtGlass(radius: 20, child: Text('Hello'))),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TtGlass),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the shadow is optional', (tester) async {
      Future<int> shadowed({required bool shadow}) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtGlass(
                radius: 20,
                shadow: shadow,
                child: const Text('Hello'),
              ),
            ),
          ),
        );
        return find
            .descendant(
              of: find.byType(TtGlass),
              matching: find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is OutsideShadowPainter,
              ),
            )
            .evaluate()
            .length;
      }

      expect(await shadowed(shadow: true), 1);
      expect(await shadowed(shadow: false), 0);
    });

    testWidgets('the shadow is not a BoxShadow under the glass', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(child: TtGlass(radius: 20, child: Text('Hello'))),
        ),
      );
      final boxShadows = find
          .descendant(
            of: find.byType(TtGlass),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .where((e) {
            final d = (e.widget as DecoratedBox).decoration;
            return d is BoxDecoration && d.boxShadow != null;
          });
      expect(boxShadows, isEmpty);
    });

    testWidgets('a TtGlass without saturation blurs only', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(child: TtGlass(radius: 20, child: Text('Hello'))),
        ),
      );
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter,
        ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      );
    });

    testWidgets('a saturation of 1 blurs only too', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtGlass(
              radius: 20,
              // The default, passed on purpose: 1 means a plain blur.
              // ignore: avoid_redundant_argument_values
              saturation: 1,
              child: Text('Hello'),
            ),
          ),
        ),
      );
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter,
        ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      );
    });

    testWidgets('a saturation blurs first, then saturates', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtGlass(
              radius: 20,
              blur: 5,
              saturation: 1.4,
              child: Text('Hello'),
            ),
          ),
        ),
      );
      final filter = tester
          .widget<BackdropFilter>(find.byType(BackdropFilter))
          .filter;
      expect(
        filter,
        ui.ImageFilter.compose(
          outer: ui.ColorFilter.matrix(ttSaturationMatrix(1.4)),
          inner: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        ),
      );
      expect(
        filter,
        isNot(
          ui.ImageFilter.compose(
            outer: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            inner: ui.ColorFilter.matrix(ttSaturationMatrix(1.4)),
          ),
        ),
      );
    });
  });

  group('OutsideShadowPainter', () {
    // A 120 x 60 box over white, casting [shadows]. The first test's is the
    // nav pill's: black, shifted down 10 dp, blurred by 30 and shrunk by 8.
    Future<TtPixels> shot(
      WidgetTester tester, {
      required List<BoxShadow> shadows,
    }) {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return ttWithBlurredShadows(() async {
        await tester.pumpWidget(
          ttPixelApp(
            ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: Align(
                child: CustomPaint(
                  painter: OutsideShadowPainter(
                    shadows: shadows,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const SizedBox(width: 120, height: 60),
                ),
              ),
            ),
          ),
        );
        final photo = await TtPixels.capture(tester);
        return photo;
      });
    }

    const shadow = BoxShadow(
      blurRadius: 30,
      offset: Offset(0, 10),
      spreadRadius: -8,
    );

    int red(Color c) => (c.r * 255).round();

    testWidgets('paints nothing inside the box, and does outside it', (
      tester,
    ) async {
      final photo = await shot(tester, shadows: const [shadow]);
      // The box is centred: x 120..240, y 370..430.
      for (final at in const [
        Offset(180, 400),
        Offset(180, 425),
        Offset(130, 400),
        Offset(180, 372),
      ]) {
        expect(red(photo.colorAt(at)), 255, reason: 'inside at $at');
      }
      expect(red(photo.colorAt(const Offset(180, 436))), lessThan(250));
      expect(red(photo.colorAt(const Offset(180, 446))), lessThan(250));
      // Beside the box, the shadow's spread is 8 dp in, so little shows.
      expect(red(photo.colorAt(const Offset(112, 410))), lessThan(255));
    });

    testWidgets('a positive spread and a big offset stay outside too', (
      tester,
    ) async {
      final photo = await shot(
        tester,
        shadows: const [
          BoxShadow(blurRadius: 4, offset: Offset(20, 20), spreadRadius: 6),
        ],
      );
      expect(red(photo.colorAt(const Offset(180, 400))), 255);
      expect(red(photo.colorAt(const Offset(225, 415))), 255);
      expect(red(photo.colorAt(const Offset(250, 440))), lessThan(40));
    });

    testWidgets('no shadows paint nothing', (tester) async {
      final photo = await shot(tester, shadows: const []);
      expect(red(photo.colorAt(const Offset(180, 440))), 255);
    });

    test('builds its outside path once for a size, and again for another', () {
      final painter = OutsideShadowPainter(
        shadows: const [shadow],
        borderRadius: BorderRadius.circular(30),
      );
      void paintAt(Size size) {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
      }

      expect(painter.outsidePathBuilds, 0);
      paintAt(const Size(120, 60));
      expect(painter.outsidePathBuilds, 1);
      paintAt(const Size(120, 60));
      paintAt(const Size(120, 60));
      expect(painter.outsidePathBuilds, 1, reason: 'the same size is cached');
      paintAt(const Size(130, 60));
      expect(painter.outsidePathBuilds, 2, reason: 'a new size is rebuilt');
      paintAt(const Size(130, 60));
      expect(painter.outsidePathBuilds, 2);
      paintAt(const Size(120, 60));
      expect(painter.outsidePathBuilds, 3, reason: 'back to the first size');
    });

    test('a cached path still paints the same pixels as a fresh one', () async {
      Future<List<int>> pixels(
        OutsideShadowPainter painter,
        List<Size> sizes,
      ) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..drawRect(
            const Rect.fromLTWH(0, 0, 300, 200),
            Paint()..color = const Color(0xFFFFFFFF),
          )
          ..translate(100, 70);
        for (final size in sizes) {
          painter.paint(canvas, size);
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(300, 200);
        final data = (await image.toByteData())!;
        image.dispose();
        picture.dispose();
        return data.buffer.asUint8List().toList();
      }

      const shadows = [BoxShadow(blurRadius: 6, offset: Offset(0, 4))];
      final corners = BorderRadius.circular(12);
      // Sizes A, B, A: the cache must not leak the first path into B.
      final cached = await pixels(
        OutsideShadowPainter(shadows: shadows, borderRadius: corners),
        const [Size(100, 40)],
      );
      final viaOther = OutsideShadowPainter(
        shadows: shadows,
        borderRadius: corners,
      );
      await pixels(viaOther, const [Size(60, 60)]);
      final again = await pixels(viaOther, const [Size(100, 40)]);
      expect(again, cached, reason: 'a stale path from another size leaked');
    });

    test('repaints when its shadows or corners change', () {
      final base = OutsideShadowPainter(
        shadows: const [BoxShadow(blurRadius: 4)],
        borderRadius: BorderRadius.circular(8),
      );
      final same = OutsideShadowPainter(
        shadows: const [BoxShadow(blurRadius: 4)],
        borderRadius: BorderRadius.circular(8),
      );
      final otherShadow = OutsideShadowPainter(
        shadows: const [BoxShadow(blurRadius: 5)],
        borderRadius: BorderRadius.circular(8),
      );
      final otherCorner = OutsideShadowPainter(
        shadows: const [BoxShadow(blurRadius: 4)],
        borderRadius: BorderRadius.circular(9),
      );
      expect(base.shouldRepaint(same), isFalse);
      expect(base.shouldRepaint(otherShadow), isTrue);
      expect(base.shouldRepaint(otherCorner), isTrue);
    });
  });

  group('TtGlass accessibility', () {
    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            const Center(child: TtGlass(radius: 20, child: Text('Hello'))),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });

  group('TtGlassPill', () {
    testWidgets('shows the icon and the text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtGlassPill(
              icon: Symbols.link_rounded,
              text: '3',
              semanticLabel: '3 links',
            ),
          ),
        ),
      );
      expect(find.byIcon(Symbols.link_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('is 24 dp high', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtGlassPill(
              icon: Symbols.link_rounded,
              semanticLabel: 'Linked',
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtGlassPill)).height, 24);
    });

    testWidgets('an icon-only pill is announced by its semanticLabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ttTestApp(
            const Center(
              child: TtGlassPill(
                icon: Symbols.link_rounded,
                semanticLabel: 'Has references',
              ),
            ),
          ),
        );
        final data = tester
            .getSemantics(find.byType(TtGlassPill))
            .getSemanticsData();
        expect(data.label, 'Has references');
        // One node: the icon adds no label of its own.
        expect(find.bySemanticsLabel('Has references'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a pill with text is announced by its semanticLabel, not '
        'the text', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ttTestApp(
            const Center(
              child: TtGlassPill(
                icon: Symbols.link_rounded,
                text: '3',
                semanticLabel: '3 references',
              ),
            ),
          ),
        );
        expect(find.bySemanticsLabel('3 references'), findsOneWidget);
        expect(find.bySemanticsLabel('3'), findsNothing);
      } finally {
        handle.dispose();
      }
    });
  });
}
