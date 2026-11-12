import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/hatch_painter.dart';
import 'package:taketray_ui/src/components/internal/unit_share.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const ValueKey<String> _track = ValueKey('tt-storage-track');
const ValueKey<String> _need = ValueKey('tt-storage-need');
const ValueKey<String> _have = ValueKey('tt-storage-have');
const ValueKey<String> _short = ValueKey('tt-storage-short');

Widget _enough({
  double fraction = 0.3,
  String need = 'Copies: 1.2 GB',
  String free = 'Free after copying: 3.1 GB',
  String semantic = 'Free space 4.3 GB, copies need 1.2 GB',
  double width = 312,
}) => Center(
  child: SizedBox(
    width: width,
    child: TtStorageBar.enough(
      needFraction: fraction,
      needLabel: need,
      freeAfterLabel: free,
      semanticLabel: semantic,
    ),
  ),
);

Widget _shortBar({
  double fraction = 0.6,
  String have = 'You have 1.8 GB',
  String short = 'Short by 1.2 GB',
  String semantic = 'Copies need 3 GB, you have 1.8 GB, short by 1.2 GB',
  double width = 312,
}) => Center(
  child: SizedBox(
    width: width,
    child: TtStorageBar.short(
      haveFraction: fraction,
      haveLabel: have,
      shortLabel: short,
      semanticLabel: semantic,
    ),
  ),
);

Color? _fill(WidgetTester tester, Key key) {
  final box = tester.widget<DecoratedBox>(find.byKey(key));
  return (box.decoration as BoxDecoration).color;
}

/// The colour swatch of the legend item that shows [label].
Finder _swatchOf(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
  matching: find.byType(DecoratedBox),
);

void main() {
  group('TtStorageBar.enough', () {
    testWidgets('is a 14 dp rounded track in surface-container-highest '
        'holding a primary need segment of its share', (tester) async {
      await tester.pumpWidget(ttTestApp(_enough()));
      final scheme = tester.element(find.byType(TtStorageBar)).scheme;
      final track = tester.getRect(find.byKey(_track));
      expect(track.height, 14);
      expect(track.width, 312);
      final decoration =
          tester.widget<DecoratedBox>(find.byKey(_track)).decoration
              as BoxDecoration;
      expect(decoration.color, scheme.surfaceContainerHighest);
      expect(decoration.borderRadius, BorderRadius.circular(7));
      final need = tester.getRect(find.byKey(_need));
      expect(need.width, closeTo(312 * 0.3, 0.01));
      expect(need.height, 14);
      expect(need.left, track.left);
      expect(_fill(tester, _need), scheme.primary);
    });

    testWidgets('the track clips the segment to its rounded ends', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_enough(fraction: 1)));
      expect(
        find.descendant(
          of: find.byType(TtStorageBar),
          matching: find.byType(ClipRRect),
        ),
        findsWidgets,
      );
    });

    testWidgets('the need share is at least 4 % wide: 0, a hair, and just '
        'under 4 % all draw 4 %; 4 % and more draw their own share', (
      tester,
    ) async {
      for (final fraction in [0.0, 0.001, 0.039]) {
        await tester.pumpWidget(ttTestApp(_enough(fraction: fraction)));
        expect(
          tester.getRect(find.byKey(_need)).width,
          closeTo(312 * 0.04, 0.01),
          reason: '$fraction',
        );
      }
      for (final fraction in [0.04, 0.05, 0.5]) {
        await tester.pumpWidget(ttTestApp(_enough(fraction: fraction)));
        expect(
          tester.getRect(find.byKey(_need)).width,
          closeTo(312 * fraction, 0.01),
          reason: '$fraction',
        );
      }
    });

    testWidgets('a need share of 1 or more fills the track and no more', (
      tester,
    ) async {
      for (final fraction in [1.0, 1.5]) {
        await tester.pumpWidget(ttTestApp(_enough(fraction: fraction)));
        expect(tester.getRect(find.byKey(_need)).width, closeTo(312, 0.01));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a share that is not a number or not finite is drawn safely: '
        'NaN, minus infinity and negatives as the 4 % minimum, infinity as '
        'the full bar', (tester) async {
      for (final fraction in [
        double.nan,
        double.negativeInfinity,
        -0.5,
        -1e9,
      ]) {
        await tester.pumpWidget(ttTestApp(_enough(fraction: fraction)));
        expect(tester.takeException(), isNull, reason: '$fraction');
        final width = tester.getRect(find.byKey(_need)).width;
        expect(width, closeTo(312 * 0.04, 0.01), reason: '$fraction');
      }
      await tester.pumpWidget(ttTestApp(_enough(fraction: double.infinity)));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(_need)).width, closeTo(312, 0.01));
    });

    testWidgets('has no have or short segment and nothing hatched', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_enough()));
      expect(find.byKey(_have), findsNothing);
      expect(find.byKey(_short), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TtStorageBar),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is HatchPainter,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('the legend has two items: a primary swatch with the need '
        'label and an outlined one with the free-after label', (tester) async {
      await tester.pumpWidget(ttTestApp(_enough()));
      final scheme = tester.element(find.byType(TtStorageBar)).scheme;
      expect(find.text('Copies: 1.2 GB'), findsOneWidget);
      expect(find.text('Free after copying: 3.1 GB'), findsOneWidget);
      // Only these two texts are in the legend.
      expect(
        find.descendant(
          of: find.byType(TtStorageBar),
          matching: find.byType(Text),
        ),
        findsNWidgets(2),
      );
      final needSwatch = _swatchOf('Copies: 1.2 GB');
      expect(tester.getSize(needSwatch), const Size.square(10));
      final needDeco =
          tester.widget<DecoratedBox>(needSwatch).decoration as BoxDecoration;
      expect(needDeco.color, scheme.primary);
      expect(needDeco.borderRadius, BorderRadius.circular(3));
      final freeSwatch = _swatchOf('Free after copying: 3.1 GB');
      expect(tester.getSize(freeSwatch), const Size.square(10));
      final freeDeco =
          tester.widget<DecoratedBox>(freeSwatch).decoration as BoxDecoration;
      expect(freeDeco.color, scheme.surfaceContainerHighest);
      expect(freeDeco.border, Border.all(color: scheme.outlineVariant));
    });

    testWidgets('the legend is body-small in on-surface-variant, 8 dp under '
        'the bar, items 14 dp apart', (tester) async {
      await tester.pumpWidget(ttTestApp(_enough()));
      final scheme = tester.element(find.byType(TtStorageBar)).scheme;
      final style = tester.widget<Text>(find.text('Copies: 1.2 GB')).style!;
      expect(style.color, scheme.onSurfaceVariant);
      expect(style.fontSize, 12);
      final track = tester.getRect(find.byKey(_track));
      final firstItem = tester.getRect(
        find.ancestor(
          of: find.text('Copies: 1.2 GB'),
          matching: find.byType(Row),
        ),
      );
      expect(firstItem.top - track.bottom, 8);
      final second = tester.getRect(
        find.ancestor(
          of: find.text('Free after copying: 3.1 GB'),
          matching: find.byType(Row),
        ),
      );
      expect(second.left - firstItem.right, 14);
    });

    testWidgets('colours follow the dark theme', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_enough(), brightness: Brightness.dark),
      );
      final scheme = tester.element(find.byType(TtStorageBar)).scheme;
      expect(scheme.brightness, Brightness.dark);
      expect(_fill(tester, _need), scheme.primary);
      expect(_fill(tester, _track), scheme.surfaceContainerHighest);
    });

    testWidgets('is one node for a screen reader: the semantic label, with '
        'the legend texts not read again', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_enough()));
      final node = tester.getSemantics(find.byType(TtStorageBar));
      expect(node.label, 'Free space 4.3 GB, copies need 1.2 GB');
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      expect(find.bySemanticsLabel('Copies: 1.2 GB'), findsNothing);
      expect(
        find.bySemanticsLabel('Free space 4.3 GB, copies need 1.2 GB'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the legend wraps at 2x text on a narrow width, nothing '
        'overflows or is cut', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _enough(
            width: 200,
            need: 'Copies: 12.3 GB',
            free: 'Free after copying: 31.1 GB',
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final first = tester.getRect(find.text('Copies: 12.3 GB'));
      final second = tester.getRect(find.text('Free after copying: 31.1 GB'));
      // The second item moved under the first, 6 dp lower.
      expect(second.top - first.bottom, 6);
      for (final text in ['Copies: 12.3 GB', 'Free after copying: 31.1 GB']) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(text))
              .didExceedMaxLines,
          isFalse,
        );
      }
    });

    testWidgets('a very long label wraps inside the width at 2x', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _enough(
            width: 200,
            free: 'Free after copying: 31.1 GB on this phone and its card',
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(TtStorageBar)).width,
        lessThanOrEqualTo(200),
      );
    });

    testWidgets('is accessible in light and dark', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(ttTestApp(_enough(), brightness: brightness));
        await expectTtAccessible(tester);
      }
    });
  });

  group('TtStorageBar.short', () {
    testWidgets('a solid outline-coloured have part of its share, then the '
        'hatched shortfall to the end', (tester) async {
      await tester.pumpWidget(ttTestApp(_shortBar()));
      final scheme = tester.element(find.byType(TtStorageBar)).scheme;
      final track = tester.getRect(find.byKey(_track));
      final have = tester.getRect(find.byKey(_have));
      final short = tester.getRect(find.byKey(_short));
      expect(track.height, 14);
      expect(have.left, track.left);
      expect(have.width, closeTo(312 * 0.6, 0.01));
      expect(short.left, closeTo(have.right, 0.01));
      expect(short.right, closeTo(track.right, 0.01));
      expect(have.height, 14);
      expect(short.height, 14);
      // The have part is a plain fill; the shortfall is the hatch.
      expect(_fill(tester, _have), scheme.outline);
      expect(find.byKey(_need), findsNothing);
      final hatch = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(_short),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is HatchPainter,
          ),
        ),
      );
      expect((hatch.painter! as HatchPainter).color, scheme.error);
      // The have part is not hatched.
      expect(
        find.descendant(
          of: find.byKey(_have),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is HatchPainter,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('a have share of 0 is all hatch', (tester) async {
      await tester.pumpWidget(ttTestApp(_shortBar(fraction: 0)));
      expect(tester.getSize(find.byKey(_have)).width, 0);
      expect(tester.getSize(find.byKey(_short)).width, closeTo(312, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a have share just under 1 leaves a sliver of hatch and '
        'nothing overflows', (tester) async {
      await tester.pumpWidget(ttTestApp(_shortBar(fraction: 0.999)));
      expect(
        tester.getSize(find.byKey(_short)).width,
        closeTo(312 * 0.001, 0.01),
      );
      expect(tester.takeException(), isNull);
    });

    test('a have share outside 0 <= f < 1 is refused', () {
      for (final bad in [1.0, 1.5, -0.01, double.nan, double.infinity]) {
        expect(
          () => TtStorageBar.short(
            haveFraction: bad,
            haveLabel: 'a',
            shortLabel: 'b',
            semanticLabel: 'c',
          ),
          throwsAssertionError,
          reason: '$bad',
        );
      }
      for (final good in [0.0, 0.5, 0.9999]) {
        expect(
          () => TtStorageBar.short(
            haveFraction: good,
            haveLabel: 'a',
            shortLabel: 'b',
            semanticLabel: 'c',
          ),
          returnsNormally,
          reason: '$good',
        );
      }
    });

    testWidgets('the legend: an outline swatch with the have label and an '
        'error swatch with the short label', (tester) async {
      await tester.pumpWidget(ttTestApp(_shortBar()));
      final scheme = tester.element(find.byType(TtStorageBar)).scheme;
      expect(
        find.descendant(
          of: find.byType(TtStorageBar),
          matching: find.byType(Text),
        ),
        findsNWidgets(2),
      );
      final haveDeco =
          tester.widget<DecoratedBox>(_swatchOf('You have 1.8 GB')).decoration
              as BoxDecoration;
      expect(haveDeco.color, scheme.outline);
      final shortDeco =
          tester.widget<DecoratedBox>(_swatchOf('Short by 1.2 GB')).decoration
              as BoxDecoration;
      expect(shortDeco.color, scheme.error);
      expect(
        tester.getSize(_swatchOf('Short by 1.2 GB')),
        const Size.square(10),
      );
    });

    testWidgets('is one node for a screen reader with the semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_shortBar()));
      final node = tester.getSemantics(find.byType(TtStorageBar));
      expect(node.label, 'Copies need 3 GB, you have 1.8 GB, short by 1.2 GB');
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      expect(find.bySemanticsLabel('You have 1.8 GB'), findsNothing);
      handle.dispose();
    });

    testWidgets('in a right-to-left layout the bar fills from the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          Directionality(
            textDirection: TextDirection.rtl,
            child: _shortBar(fraction: 0.25),
          ),
        ),
      );
      final track = tester.getRect(find.byKey(_track));
      final have = tester.getRect(find.byKey(_have));
      expect(have.right, closeTo(track.right, 0.01));
      expect(have.width, closeTo(312 * 0.25, 0.01));
    });

    testWidgets('is accessible in light and dark, and wraps at 2x', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(ttTestApp(_shortBar(), brightness: brightness));
        await expectTtAccessible(tester);
      }
      await tester.pumpWidget(ttTestApp(_shortBar(width: 200), textScale: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('unitShare', () {
    test('keeps 0 to 1 and makes anything else safe', () {
      expect(unitShare(0), 0);
      expect(unitShare(0.4), 0.4);
      expect(unitShare(1), 1);
      expect(unitShare(1.5), 1);
      expect(unitShare(double.infinity), 1);
      expect(unitShare(-0.3), 0);
      expect(unitShare(double.negativeInfinity), 0);
      expect(unitShare(double.nan), 0);
    });
  });

  group('HatchPainter', () {
    testWidgets('the stripes run from the top left to the bottom right (a '
        'backslash), start solid at the bottom left, and are 6 dp thick', (
      tester,
    ) async {
      const width = 96;
      const height = 14;
      final image = await tester.runAsync(() {
        final recorder = ui.PictureRecorder();
        const HatchPainter(
          color: Color(0xFFFF0000),
          stripe: 6,
          shade: 0.7,
        ).paint(Canvas(recorder), const Size(96, 14));
        return recorder.endRecording().toImage(width, height);
      });
      final data = (await tester.runAsync(image!.toByteData))!;
      // true for a solid stripe, false for the 70 % one.
      bool solid(int x, int y) => data.getUint8((y * width + x) * 4 + 3) > 216;
      var along = 0;
      var alongSame = 0;
      var across = 0;
      var acrossSame = 0;
      for (var y = 1; y < height - 1; y++) {
        for (var x = 1; x < width - 1; x++) {
          along++;
          if (solid(x, y) == solid(x + 1, y + 1)) alongSame++;
          across++;
          if (solid(x, y) == solid(x + 1, y - 1)) acrossSame++;
        }
      }
      // Along a stripe ("\") the colour does not change (but for the soft
      // edge); across it, it does every few pixels.
      expect(alongSame / along, greaterThan(0.97));
      expect(acrossSame / across, lessThan(0.9));
      // The first stripe starts at the bottom left corner and is solid; the
      // next one along the bottom edge is the 70 % one.
      expect(solid(0, height - 1), isTrue);
      expect(solid(3, height - 1), isTrue);
      expect(solid(10, height - 1), isFalse);
      expect(solid(20, height - 1), isTrue);
      // A stripe is 6 dp thick, so it is 6 * sqrt(2) wide along the bottom.
      var run = 0;
      while (run < width && solid(run, height - 1)) {
        run++;
      }
      expect(run, inInclusiveRange(7, 9));
    });

    test('shouldRepaint is false for equal values, true for any change', () {
      const base = HatchPainter(
        color: Color(0xFFB3261E),
        stripe: 6,
        shade: 0.7,
      );
      expect(
        base.shouldRepaint(
          const HatchPainter(color: Color(0xFFB3261E), stripe: 6, shade: 0.7),
        ),
        isFalse,
      );
      expect(
        base.shouldRepaint(
          const HatchPainter(color: Color(0xFF000000), stripe: 6, shade: 0.7),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const HatchPainter(color: Color(0xFFB3261E), stripe: 5, shade: 0.7),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const HatchPainter(color: Color(0xFFB3261E), stripe: 6, shade: 0.5),
        ),
        isTrue,
      );
    });

    testWidgets('draws diagonal stripes of the colour and a lighter shade of '
        'it, and covers the whole area', (tester) async {
      const color = Color(0xFFFF0000);
      final image = await tester.runAsync(() {
        final recorder = ui.PictureRecorder();
        const HatchPainter(
          color: color,
          stripe: 6,
          shade: 0.7,
        ).paint(Canvas(recorder), const Size(96, 14));
        return recorder.endRecording().toImage(96, 14);
      });
      final data = (await tester.runAsync(() => image!.toByteData()))!;
      final alphas = <int>{};
      for (var i = 3; i < data.lengthInBytes; i += 4) {
        alphas.add(data.getUint8(i));
      }
      // Fully opaque stripes and 70 % stripes (178 of 255), nothing empty.
      expect(alphas, contains(255));
      expect(alphas.any((a) => (a - 178).abs() <= 2), isTrue);
      expect(alphas, isNot(contains(0)));
    });
  });
}
