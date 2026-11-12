import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

/// A real 2 x 2 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGMoNroPRAwQCg'
  'AozgYRl2dfIwAAAABJRU5ErkJggg==',
);

Widget _icon({Uint8List? png, String letters = 'VN'}) => Center(
  child: TtAppIcon(png: png, fallbackLetters: letters),
);

/// Waits for the image bytes to decode (a real async job).
Future<void> _decode(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

void main() {
  group('TtAppIcon without bytes', () {
    testWidgets(
      'is a 40 dp rounded tile in surface-container-highest with the bold '
      'letters in on-surface-variant',
      (tester) async {
        await tester.pumpWidget(ttTestApp(_icon()));
        final scheme = tester.element(find.byType(TtAppIcon)).scheme;
        expect(tester.getSize(find.byType(TtAppIcon)), const Size.square(40));
        final deco =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(TtAppIcon),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(deco.color, scheme.surfaceContainerHighest);
        expect(deco.borderRadius, BorderRadius.circular(12));
        final style = tester.widget<Text>(find.text('VN')).style!;
        expect(style.color, scheme.onSurfaceVariant);
        expect(style.fontWeight, FontWeight.w800);
        expect(find.byType(Image), findsNothing);
        // Centred.
        expect(
          tester.getRect(find.text('VN')).center,
          tester.getRect(find.byType(TtAppIcon)).center,
        );
      },
    );

    testWidgets('one letter, two and a long run all fit in one line', (
      tester,
    ) async {
      for (final letters in ['C', 'VN', 'WWWW', 'Instagram']) {
        await tester.pumpWidget(ttTestApp(_icon(letters: letters)));
        expect(tester.takeException(), isNull, reason: letters);
        // The size on screen, after any shrinking.
        expect(
          tester.getRect(find.text(letters)).width,
          lessThanOrEqualTo(40),
          reason: letters,
        );
        expect(tester.getSize(find.byType(TtAppIcon)), const Size.square(40));
      }
    });

    testWidgets('empty letters draw an empty tile', (tester) async {
      await tester.pumpWidget(ttTestApp(_icon(letters: '')));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TtAppIcon)), const Size.square(40));
    });

    testWidgets('the letters are drawn the same size at 1x and 2x text', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_icon(letters: 'E')));
      final one = tester.getRect(find.text('E')).size;
      await tester.pumpWidget(ttTestApp(_icon(letters: 'E'), textScale: 2));
      expect(tester.getRect(find.text('E')).size, one);
      final paragraph = tester.renderObject<RenderParagraph>(find.text('E'));
      expect(paragraph.textScaler, TextScaler.noScaling);
    });

    testWidgets('stays 40 dp with the letters unscaled at 2x text', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_icon(), textScale: 2));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TtAppIcon)), const Size.square(40));
      expect(tester.getRect(find.text('VN')).width, lessThanOrEqualTo(40));
    });

    testWidgets('follows the dark theme', (tester) async {
      await tester.pumpWidget(ttTestApp(_icon(), brightness: Brightness.dark));
      final scheme = tester.element(find.byType(TtAppIcon)).scheme;
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(TtAppIcon),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.color, scheme.surfaceContainerHighest);
      expect(scheme.brightness, Brightness.dark);
      // A quiet tile that is not the page's own colour.
      expect(deco.color, isNot(scheme.surface));
    });

    testWidgets('is decoration: no label of its own for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_icon()));
      expect(find.bySemanticsLabel('VN'), findsNothing);
      handle.dispose();
    });

    testWidgets('has enough contrast for its letters', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(ttTestApp(_icon(), brightness: brightness));
        await expectTtAccessible(tester);
      }
    });
  });

  group('TtAppIcon with bytes', () {
    testWidgets('shows the picture 40 dp, cover-fitted, clipped to the same '
        'corners, and not the letters', (tester) async {
      await tester.pumpWidget(ttTestApp(_icon(png: _png)));
      await _decode(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TtAppIcon)), const Size.square(40));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect((image.image as MemoryImage).bytes, _png);
      expect(image.fit, BoxFit.cover);
      expect(tester.getSize(find.byType(Image)), const Size.square(40));
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(TtAppIcon),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(12));
      expect(find.text('VN'), findsNothing);
    });

    testWidgets('bytes that are not an image fall back to the letters, '
        'without an error', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_icon(png: Uint8List.fromList([1, 2, 3, 4]))),
      );
      await _decode(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('VN'), findsOneWidget);
      expect(tester.getSize(find.byType(TtAppIcon)), const Size.square(40));
    });

    testWidgets('empty bytes are the same as none', (tester) async {
      await tester.pumpWidget(ttTestApp(_icon(png: Uint8List(0))));
      expect(tester.takeException(), isNull);
      expect(find.text('VN'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('bytes appearing and going away swap the picture and the '
        'letters', (tester) async {
      await tester.pumpWidget(ttTestApp(_icon()));
      expect(find.text('VN'), findsOneWidget);
      await tester.pumpWidget(ttTestApp(_icon(png: _png)));
      await _decode(tester);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('VN'), findsNothing);
      await tester.pumpWidget(ttTestApp(_icon()));
      expect(find.text('VN'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('new bytes show the new picture', (tester) async {
      final other = Uint8List.fromList([..._png, 0]);
      await tester.pumpWidget(ttTestApp(_icon(png: _png)));
      await tester.pumpWidget(ttTestApp(_icon(png: other)));
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as MemoryImage).bytes, other);
    });

    testWidgets('the picture is hidden from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_icon(png: _png)));
      await _decode(tester);
      final node = tester.getSemantics(find.byType(TtAppIcon));
      expect(node.label, isEmpty);
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      handle.dispose();
    });
  });
}
