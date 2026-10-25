import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

/// The semantics data of the one [TtButton], [TtIconButton] or [TtFab] shown.
SemanticsData _semantics(WidgetTester tester, Type type) =>
    tester.getSemantics(find.byType(type)).getSemanticsData();

void main() {
  group('TtButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(label: 'Save', onPressed: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(TtButton));
      expect(taps, 1);
    });

    testWidgets('a null onPressed is disabled and ignores taps', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          const Center(child: TtButton(label: 'Save', onPressed: null)),
        ),
      );
      await tester.tap(find.byType(TtButton), warnIfMissed: false);
      expect(
        _semantics(tester, TtButton).flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('the semantics label is the label, or semanticLabel', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(label: 'Save', onPressed: () {}),
          ),
        ),
      );
      expect(_semantics(tester, TtButton).label, 'Save');

      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(
              label: 'Save',
              semanticLabel: 'Save this reel',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(_semantics(tester, TtButton).label, 'Save this reel');
      semantics.dispose();
    });

    testWidgets('shows its icon', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(
              label: 'Tag',
              icon: Symbols.sell_rounded,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Symbols.sell_rounded), findsOneWidget);
    });

    testWidgets('expand fills the available width', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 300,
              child: TtButton(label: 'Go', expand: true, onPressed: () {}),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtButton)).width, 300);
    });

    testWidgets('sizes have visual heights of 36, 44 and 56', (tester) async {
      Future<double> heightOf(TtButtonSize size) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtButton(
                label: 'Go',
                size: size,
                kind: TtButtonKind.tonal,
                onPressed: () {},
              ),
            ),
          ),
        );
        // The painted button is the Material inside the padded tap target.
        return tester
            .getSize(
              find.descendant(
                of: find.byType(TtButton),
                matching: find.byType(Material),
              ),
            )
            .height;
      }

      expect(await heightOf(TtButtonSize.small), 36);
      expect(await heightOf(TtButtonSize.medium), 44);
      expect(await heightOf(TtButtonSize.large), 56);
    });

    testWidgets('the small button keeps a 48 x 48 tap target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(
              label: 'Go',
              size: TtButtonSize.small,
              kind: TtButtonKind.text,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byType(TtButton));
      expect(box.height, greaterThanOrEqualTo(48));
      expect(box.width, greaterThanOrEqualTo(48));

      // A tap just above the 36 dp painted button still lands.
      await tester.tapAt(box.topCenter + const Offset(0, 2));
      expect(taps, 1);

      final semantics = tester.ensureSemantics();
      final rect = tester.getSemantics(find.byType(TtButton)).rect;
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.width, greaterThanOrEqualTo(48));
      semantics.dispose();
    });

    for (final brightness in Brightness.values) {
      for (final kind in TtButtonKind.values) {
        testWidgets('${kind.name} passes the accessibility guidelines '
            '(${brightness.name})', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              ColoredBox(
                // Ghost is for use on video.
                color: kind == TtButtonKind.ghost
                    ? const Color(0xFF000000)
                    : Colors.transparent,
                child: Center(
                  child: TtButton(
                    label: 'Save',
                    icon: Symbols.sell_rounded,
                    kind: kind,
                    size: TtButtonSize.small,
                    onPressed: () {},
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    }

    testWidgets('a long label ends in an ellipsis at 2x text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 200,
              child: TtButton(
                label: 'Publish this reel to every one of my channels',
                expand: true,
                onPressed: () {},
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('TtIconButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtIconButton(
              icon: Symbols.close_rounded,
              semanticLabel: 'Close',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtIconButton));
      expect(taps, 1);
    });

    testWidgets('a null onPressed is disabled and ignores taps', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtIconButton(
              icon: Symbols.close_rounded,
              semanticLabel: 'Close',
              onPressed: null,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtIconButton), warnIfMissed: false);
      expect(
        _semantics(tester, TtIconButton).flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('the semantics label is the semanticLabel', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtIconButton(
              icon: Symbols.close_rounded,
              semanticLabel: 'Close',
              onPressed: () {},
            ),
          ),
        ),
      );
      final data = _semantics(tester, TtIconButton);
      expect(data.label, 'Close');
      expect(data.flagsCollection.isButton, isTrue);
      // Not a toggle unless `pressed` is given.
      expect(data.flagsCollection.isToggled, ui.Tristate.none);
      semantics.dispose();
    });

    testWidgets('pressed gives toggle semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final pressed in [true, false]) {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtIconButton(
                icon: Symbols.favorite_rounded,
                semanticLabel: 'Favourite',
                pressed: pressed,
                onPressed: () {},
              ),
            ),
          ),
        );
        expect(
          _semantics(tester, TtIconButton).flagsCollection.isToggled,
          pressed ? ui.Tristate.isTrue : ui.Tristate.isFalse,
        );
      }
      semantics.dispose();
    });

    testWidgets('is 48 x 48 in every style', (tester) async {
      for (final style in TtIconButtonStyle.values) {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtIconButton(
                icon: Symbols.close_rounded,
                semanticLabel: 'Close',
                style: style,
                onPressed: () {},
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(TtIconButton)), const Size(48, 48));
      }
    });

    for (final brightness in Brightness.values) {
      for (final style in TtIconButtonStyle.values) {
        testWidgets('${style.name} passes the accessibility guidelines '
            '(${brightness.name})', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              ColoredBox(
                // On video the icon is white.
                color: style == TtIconButtonStyle.onVideo
                    ? const Color(0xFF000000)
                    : Colors.transparent,
                child: Center(
                  child: TtIconButton(
                    icon: Symbols.close_rounded,
                    semanticLabel: 'Close',
                    style: style,
                    pressed: false,
                    onPressed: () {},
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    }
  });

  group('TtFab', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtFab(
              label: 'Shoot',
              icon: Symbols.videocam_rounded,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtFab));
      expect(taps, 1);
    });

    testWidgets('is 52 dp high and labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtFab(
              label: 'Shoot',
              icon: Symbols.videocam_rounded,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtFab)).height, 52);
      expect(_semantics(tester, TtFab).label, 'Shoot');
      semantics.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines '
          '(${brightness.name})', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtFab(
                label: 'Shoot',
                icon: Symbols.videocam_rounded,
                onPressed: () {},
              ),
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
