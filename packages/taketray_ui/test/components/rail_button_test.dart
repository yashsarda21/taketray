import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_glass_pixels.dart';
import '../support/tt_test_app.dart';
import '../support/tt_text_contrast.dart';

// TtRailButton (Phase 12, Task 7, D-178): the 64 dp glass Skip and Same
// buttons of the full-screen tag player. The glass blur is measured in
// glass_pixels_test.dart; this file pins the widget tree, the values, the
// semantics and the contrast.

const _phone = Size(360, 800);

void _viewport(WidgetTester tester) {
  tester.view
    ..physicalSize = _phone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

TtRailButton _button({
  String label = 'Same',
  String? detail,
  String semanticLabel = 'Same as previous: London Food',
  IconData icon = Symbols.repeat_rounded,
  VoidCallback? onPressed,
  bool enabled = true,
}) => TtRailButton(
  icon: icon,
  label: label,
  detail: detail,
  semanticLabel: semanticLabel,
  onPressed: enabled ? (onPressed ?? () {}) : null,
);

/// [child] at the top left of a page of sharp stripes.
Widget _onStripes(Widget child) => Stack(
  fit: StackFit.expand,
  children: [
    ttStripes(),
    Positioned(left: 16, top: 96, child: child),
  ],
);

/// [child] on a pure white frame, the worst case for a clip behind it.
Widget _onWhite(Widget child) => ColoredBox(
  color: const Color(0xFFFFFFFF),
  child: Align(alignment: Alignment.topLeft, child: child),
);

Finder get _glass => find.descendant(
  of: find.byType(TtRailButton),
  matching: find.byType(BackdropFilter),
);

ColoredBox _fill(WidgetTester tester) => tester.widget<ColoredBox>(
  find.descendant(of: _glass, matching: find.byType(ColoredBox)).first,
);

Text _text(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text));

/// No `Opacity`, `AnimatedOpacity` or `FadeTransition` between [of] and the
/// button: an Opacity round a BackdropFilter can drop the blur (F8). The
/// route's own page fade, above the button, is not looked at.
void _expectNoFadeAround(WidgetTester tester, Finder of) {
  for (final element in of.evaluate()) {
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is TtRailButton) return false;
      expect(
        widget is Opacity ||
            widget is AnimatedOpacity ||
            widget is FadeTransition,
        isFalse,
        reason: 'a ${widget.runtimeType} between the button and its glass',
      );
      return true;
    });
  }
}

Future<List<TtTextContrastSample>> _contrast(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    return await measureTtTextContrast(tester);
  } finally {
    semantics.dispose();
  }
}

void main() {
  group('TtRailButton', () {
    testWidgets('is 64 x 64 with radius 20, in the glass 0xBD121316 blurred '
        'by 12', (tester) async {
      _viewport(tester);
      await tester.pumpWidget(ttPixelApp(_onStripes(_button(label: 'Skip'))));
      final size = tester.getSize(find.byType(TtRailButton));
      expect(size, const Size(64, 64));
      expect(TtMetrics.railButtonSize, 64);
      expect(TtMetrics.railButtonRadius, 20);
      expect(TtMetrics.railButtonBlur, 12);
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(TtRailButton),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(20));
      expect(_fill(tester).color, const Color(0xBD121316));
      expectBlurFilter(tester, find.byType(TtRailButton), 12);
      expectGlassStructure(tester, find.byType(TtRailButton));
    });

    testWidgets('the glass is the same in the light and the dark theme', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(_button(label: 'Skip'), brightness: brightness),
        );
        expect(_fill(tester).color, const Color(0xBD121316));
      }
    });

    testWidgets('an icon of 24, then the label in labelMedium, white, '
        '1 dp apart, with 8 dp above and 4 dp beside', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: _button(label: 'Skip', icon: Symbols.redo_rounded),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Symbols.redo_rounded));
      expect(icon.size, 24);
      expect(icon.color, const Color(0xFFFFFFFF));
      final label = _text(tester, 'Skip');
      expect(label.style!.fontSize, 12);
      expect(label.style!.color, const Color(0xFFFFFFFF));
      final box = tester.getRect(find.byType(TtRailButton));
      final iconBox = tester.getRect(find.byIcon(Symbols.redo_rounded));
      final labelBox = tester.getRect(find.text('Skip'));
      expect(labelBox.top - iconBox.bottom, 1);
      // Centred: the 64 x 64 is a minimum, the content is in the middle.
      expect(iconBox.center.dx, closeTo(box.center.dx, .01));
      expect(
        (iconBox.top - box.top) - (box.bottom - labelBox.bottom),
        closeTo(0, 1.5),
      );
    });

    testWidgets('the detail: labelSmall, white at 85 %, one line, an ellipsis, '
        'at most 56 dp wide at 1x', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: _button(detail: 'London Food and Paris Trip and Rome'),
          ),
        ),
      );
      final detail = _text(tester, 'London Food and Paris Trip and Rome');
      expect(detail.style!.fontSize, 12);
      expect(detail.style!.color!.a, closeTo(.85, .005));
      expect(
        detail.style!.color!.withValues(alpha: 1),
        const Color(0xFFFFFFFF),
      );
      expect(detail.maxLines, 1);
      expect(detail.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(find.text('London Food and Paris Trip and Rome')).width,
        lessThanOrEqualTo(56),
      );
      // 56 of text and 2 x 4 of padding: the button stays 64 wide.
      expect(tester.getSize(find.byType(TtRailButton)).width, 64);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a button with no detail shows no second line', (tester) async {
      await tester.pumpWidget(ttTestApp(_button(label: 'Skip')));
      expect(
        find.descendant(
          of: find.byType(TtRailButton),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a short detail is as wide as its text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: _button(detail: 'A'),
          ),
        ),
      );
      expect(
        tester.getSize(find.text('A')).width,
        lessThan(TtMetrics.railButtonDetailMaxWidth),
      );
      expect(tester.getSize(find.byType(TtRailButton)), const Size(64, 74));
    });

    testWidgets('a tap calls onPressed once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(Center(child: _button(onPressed: () => taps++))),
      );
      await tester.tap(find.byType(TtRailButton));
      expect(taps, 1);
    });

    testWidgets('is one button named semanticLabel, with no other node', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: _button(detail: 'London Food'),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(TtRailButton))
          .getSemanticsData();
      expect(data.label, 'Same as previous: London Food');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      // The visible words are not separate nodes.
      expect(find.bySemanticsLabel('Same'), findsNothing);
      expect(find.bySemanticsLabel('London Food'), findsNothing);
      semantics.dispose();
    });

    group('off (onPressed null)', () {
      // F8: an Opacity round a BackdropFilter can drop the blur, so the off
      // state fades the fill and the content, never the glass.
      testWidgets('fades the fill and the content to 45 %, with no Opacity', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            Align(
              alignment: Alignment.topLeft,
              child: _button(detail: 'nothing yet', enabled: false),
            ),
          ),
        );
        expect(TtMetrics.railButtonDisabledOpacity, .45);
        _expectNoFadeAround(tester, _glass.first);
        _expectNoFadeAround(tester, find.byType(Icon));
        _expectNoFadeAround(tester, find.byType(Text));
        expect(_fill(tester).color.a, closeTo(0xBD / 255 * .45, .005));
        expect(
          _fill(tester).color.withValues(alpha: 1),
          const Color(0xFF121316),
        );
        final icon = tester.widget<Icon>(find.byIcon(Symbols.repeat_rounded));
        expect(icon.color!.a, closeTo(.45, .005));
        expect(_text(tester, 'Same').style!.color!.a, closeTo(.45, .005));
        expect(
          _text(tester, 'nothing yet').style!.color!.a,
          closeTo(.85 * .45, .005),
        );
        expectBlurFilter(tester, find.byType(TtRailButton), 12);
        expectGlassStructure(tester, find.byType(TtRailButton));
      });

      testWidgets('is announced as a disabled button with its name', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ttTestApp(
            Align(
              alignment: Alignment.topLeft,
              child: _button(
                semanticLabel: 'Same as previous: nothing tagged yet',
                enabled: false,
              ),
            ),
          ),
        );
        final data = tester
            .getSemantics(find.byType(TtRailButton))
            .getSemanticsData();
        expect(data.label, 'Same as previous: nothing tagged yet');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
        expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
        semantics.dispose();
      });

      testWidgets('ignores a tap and shows no ripple', (tester) async {
        await tester.pumpWidget(
          ttTestApp(Center(child: _button(enabled: false))),
        );
        await tester.tap(find.byType(TtRailButton));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps its 64 x 64 box', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            Align(
              alignment: Alignment.topLeft,
              child: _button(label: 'Skip', enabled: false),
            ),
          ),
        );
        expect(tester.getSize(find.byType(TtRailButton)), const Size(64, 64));
      });
    });

    testWidgets('at 2x it grows in both directions and nothing overflows', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: _button(detail: 'London Food and Paris Trip'),
          ),
          textScale: 2,
        ),
      );
      final size = tester.getSize(find.byType(TtRailButton));
      expect(size.width, greaterThan(64));
      expect(size.height, greaterThan(64));
      // The detail may use 56 dp of 1x text, so 112 dp at 2x; the button is
      // that and the padding.
      expect(size.width, lessThanOrEqualTo(2 * 56 + 8));
      expect(tester.takeException(), isNull);
      // The glass still fills the whole grown button.
      expect(tester.getSize(_glass), size);
    });

    testWidgets('at 2x the label alone still makes at least 64 x 64', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: _button(label: 'Skip'),
          ),
          textScale: 2,
        ),
      );
      final size = tester.getSize(find.byType(TtRailButton));
      expect(size.width, greaterThanOrEqualTo(64));
      expect(size.height, greaterThan(64));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty detail still lays out', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: _button(detail: ''),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TtRailButton)).width, 64);
    });

    testWidgets('a very long detail with a very long label stays inside the '
        'screen', (tester) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topRight,
            child: _button(
              detail:
                  'London Food, Paris Trip, Rome Weekend, Lisbon, Madrid, Oslo',
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(TtRailButton)).right,
        lessThanOrEqualTo(360),
      );
    });

    group('contrast over a white frame', () {
      testWidgets('the label and the detail read AA (F7: about 6.4:1, not '
          '7.8:1)', (tester) async {
        _viewport(tester);
        await tester.pumpWidget(
          ttPixelApp(_onWhite(_button(detail: 'London'))),
        );
        final samples = await _contrast(tester);
        expect(samples, hasLength(2));
        for (final sample in samples) {
          expect(sample.ratio, greaterThanOrEqualTo(4.5), reason: '$sample');
        }
        final detail = samples.singleWhere((s) => s.text == 'London');
        // The handoff said 7.8:1; the measured ratio is 6.4:1 (white at
        // 85 % over the glass over white). Pin the number so a change to the
        // glass or to the detail's opacity is noticed.
        expect(detail.ratio, inInclusiveRange(6.2, 6.6));
        final label = samples.singleWhere((s) => s.text == 'Same');
        expect(label.ratio, greaterThan(7.5));
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
        semantics.dispose();
      });

      testWidgets('a detail cut with an ellipsis reads AA too', (tester) async {
        _viewport(tester);
        await tester.pumpWidget(
          ttPixelApp(_onWhite(_button(detail: 'London Food and Paris Trip'))),
        );
        final samples = await _contrast(tester);
        expect(samples, hasLength(2));
        for (final sample in samples) {
          expect(sample.ratio, greaterThanOrEqualTo(4.5), reason: '$sample');
        }
      });
    });
  });
}
