import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

void main() {
  group('expectTtAccessible', () {
    for (final brightness in Brightness.values) {
      testWidgets('passes a themed, labelled button (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: FilledButton(onPressed: () {}, child: const Text('Save')),
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }

    testWidgets('fails a 24 dp tap target', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: Semantics(
              label: 'Tiny',
              button: true,
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox.square(dimension: 24),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        expectTtAccessible(tester),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('ttTestApp', () {
    testWidgets('applies the text scale', (tester) async {
      late TextScaler scaler;
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) {
              scaler = MediaQuery.textScalerOf(context);
              return const SizedBox();
            },
          ),
          textScale: 2,
        ),
      );
      expect(scaler.scale(10), 20);
    });
  });

  group('fixtures', () {
    /// Decodes [image] for real; null when its bytes do not decode.
    Future<ui.Image?> decode(WidgetTester tester, ImageProvider image) =>
        tester.runAsync<ui.Image?>(() async {
          try {
            final codec = await ui.instantiateImageCodec(
              (image as MemoryImage).bytes,
            );
            return (await codec.getNextFrame()).image;
          } on Exception {
            return null;
          }
        });

    testWidgets('fixtureThumb decodes thumbs 1 to 6', (tester) async {
      for (var n = 1; n <= 6; n++) {
        final image = await decode(tester, fixtureThumb(n));
        expect(image!.width, greaterThan(0));
      }
      expect(() => fixtureThumb(7), throwsRangeError);
    });

    testWidgets('brokenImage fails to decode', (tester) async {
      expect(await decode(tester, brokenImage), isNull);
    });
  });

  group('context.tt', () {
    testWidgets('throws under a theme without TtThemeData', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              context.tt;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });
  });
  test('numeric adds tabular figures and keeps the style', () {
    final text = TakeTrayTheme.light().extension<TtThemeData>()!.text;
    final numeric = text.numeric(text.cardTitle);
    expect(numeric.fontFeatures, [const FontFeature.tabularFigures()]);
    expect(numeric.fontSize, text.cardTitle.fontSize);
  });
}
