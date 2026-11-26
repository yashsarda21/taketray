import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/dashed_border.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_glass_pixels.dart';
import '../support/tt_test_app.dart';
import '../support/tt_text_contrast.dart';

const _longName = 'Saturday morning market walk with the whole family';

/// The width of a chip in the panel at 360 dp: (360 - 2 x 12 - 8) / 2.
const _chipWidth = 164.0;

/// The width of a chip in the panel at 2x text, where the panel gives each
/// chip a whole row: 360 - 2 x 12.
const _rowWidth = 336.0;

Widget _chip({
  String name = 'Lisbon trip',
  String count = '12 clips',
  ImageProvider? cover,
  bool withCover = true,
  TtReelChipState state = TtReelChipState.idle,
  bool multi = false,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  double width = _chipWidth,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width,
    child: TtVideoSurface(
      child: Builder(
        builder: (context) => ColoredBox(
          color: context.scheme.surfaceContainer,
          child: TtReelChip(
            name: name,
            countText: count,
            semanticLabel: 'Add to $name, $count',
            cover: withCover ? (cover ?? fixtureThumb(1)) : null,
            state: state,
            multiSelect: multi,
            onTap: onTap ?? () {},
            onLongPress: onLongPress,
          ),
        ),
      ),
    ),
  ),
);

Future<void> _decode(WidgetTester tester, ImageProvider image) async {
  await tester.runAsync(
    () => precacheImage(
      image,
      tester.element(find.byType(TtReelChip)),
      onError: (_, _) {},
    ),
  );
  await tester.pumpAndSettle();
}

Color? _fill(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(TtReelChip),
          matching: find.byType(Material),
        )
        .first,
  );
  return material.color;
}

BorderSide _side(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(TtReelChip),
          matching: find.byType(Material),
        )
        .first,
  );
  return (material.shape! as RoundedRectangleBorder).side;
}

void main() {
  group('TtReelChip', () {
    testWidgets('is 58 dp high at 164 wide: 44 dp cover, 6 dp padding, '
        '1 dp border', (tester) async {
      await tester.pumpWidget(ttTestApp(_chip()));
      final chip = tester.getRect(find.byType(TtReelChip));
      expect(chip.size, const Size(_chipWidth, 58));
      expect(
        chip.height,
        greaterThanOrEqualTo(tester.view.devicePixelRatio * 0 + 56),
      );
      final cover = tester.getRect(find.byKey(const ValueKey('tt-chip-cover')));
      expect(cover.size, const Size(34, 44));
      // 1 dp border + 6 dp padding in; 7 dp above.
      expect(cover.left - chip.left, 7);
      expect(cover.top - chip.top, 7);
      final name = tester.getRect(find.text('Lisbon trip'));
      expect(name.left - cover.right, 10);
    });

    testWidgets('shows the name and count in the right styles', (tester) async {
      await tester.pumpWidget(ttTestApp(_chip()));
      final scheme = tester.element(find.byType(TtReelChip)).scheme;
      final name = tester.widget<Text>(find.text('Lisbon trip'));
      expect(name.style!.fontSize, 14);
      expect(name.style!.color, scheme.onSurface);
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      final count = tester.widget<Text>(find.text('12 clips'));
      expect(count.style!.fontSize, 12);
      expect(count.style!.color, scheme.onSurfaceVariant);
    });

    testWidgets('idle: highest surface container, no visible border', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_chip()));
      final scheme = tester.element(find.byType(TtReelChip)).scheme;
      expect(_fill(tester), scheme.surfaceContainerHighest);
      expect(_side(tester).color.a, 0);
      expect(_side(tester).width, 1);
    });

    testWidgets('picked: primary container with a primary border', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_chip(state: TtReelChipState.picked, multi: true)),
      );
      await tester.pumpAndSettle();
      final scheme = tester.element(find.byType(TtReelChip)).scheme;
      expect(_fill(tester), scheme.primaryContainer);
      expect(_side(tester).color, scheme.primary);
      expect(
        tester.widget<Text>(find.text('Lisbon trip')).style!.color,
        scheme.onPrimaryContainer,
      );
      expect(
        tester.widget<Text>(find.text('12 clips')).style!.color!.a,
        closeTo(0.8, 0.01),
      );
    });

    testWidgets('done: primary fill, 0.97 scale, a check in place of the '
        'cover', (tester) async {
      await tester.pumpWidget(ttTestApp(_chip(state: TtReelChipState.done)));
      await tester.pumpAndSettle();
      final scheme = tester.element(find.byType(TtReelChip)).scheme;
      expect(_fill(tester), scheme.primary);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        0.97,
      );
      expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Symbols.movie_rounded), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(Symbols.check_rounded));
      expect(icon.size, 24);
      expect(icon.color, scheme.primary);
      expect(
        tester.widget<Text>(find.text('Lisbon trip')).style!.color,
        scheme.onPrimary,
      );
      final cover = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey('tt-chip-cover')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(cover.color, scheme.onPrimary);
    });

    testWidgets('idle is not scaled', (tester) async {
      await tester.pumpWidget(ttTestApp(_chip()));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('with a cover it shows the picture', (tester) async {
      await tester.pumpWidget(ttTestApp(_chip()));
      await _decode(tester, fixtureThumb(1));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Symbols.movie_rounded), findsNothing);
    });

    testWidgets('without a cover it shows the movie icon', (tester) async {
      await tester.pumpWidget(ttTestApp(_chip(withCover: false)));
      expect(find.byType(Image), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(Symbols.movie_rounded));
      expect(icon.size, 20);
      expect(
        icon.color,
        tester.element(find.byType(TtReelChip)).scheme.onSurfaceVariant,
      );
    });

    testWidgets('a cover that fails to load falls back to the movie icon', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_chip(cover: brokenImage)));
      await _decode(tester, brokenImage);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Symbols.movie_rounded), findsOneWidget);
    });

    testWidgets('multi-select shows a check mark, checked only when picked', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_chip()));
      expect(find.byType(TtCheckMark), findsNothing);
      await tester.pumpWidget(ttTestApp(_chip(multi: true)));
      expect(
        tester.widget<TtCheckMark>(find.byType(TtCheckMark)).checked,
        isFalse,
      );
      await tester.pumpWidget(
        ttTestApp(_chip(multi: true, state: TtReelChipState.picked)),
      );
      expect(
        tester.widget<TtCheckMark>(find.byType(TtCheckMark)).checked,
        isTrue,
      );
      // At the end of the chip, 10 dp + 1 dp border from the edge.
      final chip = tester.getRect(find.byType(TtReelChip));
      final mark = tester.getRect(find.byType(TtCheckMark));
      expect(chip.right - mark.right, 11);
      expect(mark.size, const Size(18, 18));
    });

    testWidgets('a tap calls onTap and a long press onLongPress', (
      tester,
    ) async {
      var taps = 0;
      var longs = 0;
      await tester.pumpWidget(
        ttTestApp(_chip(onTap: () => taps++, onLongPress: () => longs++)),
      );
      await tester.tap(find.byType(TtReelChip));
      expect(taps, 1);
      await tester.longPress(find.byType(TtReelChip));
      expect(longs, 1);
      expect(taps, 1);
    });

    testWidgets('a chip without handlers is inert', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _chipWidth,
              child: TtReelChip(
                name: 'Lisbon trip',
                countText: '12 clips',
                semanticLabel: 'Add to Lisbon trip, 12 clips',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtReelChip));
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics: a button named by semanticLabel', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_chip(onLongPress: () {})));
      final data = tester
          .getSemantics(find.byType(TtReelChip))
          .getSemanticsData();
      expect(data.label, 'Add to Lisbon trip, 12 clips');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      handle.dispose();
    });

    testWidgets('semantics: a multi-select chip reports checked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_chip(multi: true, state: TtReelChipState.picked)),
      );
      var data = tester
          .getSemantics(find.byType(TtReelChip))
          .getSemanticsData();
      expect(data.flagsCollection.isChecked, CheckedState.isTrue);
      expect(data.label, 'Add to Lisbon trip, 12 clips');
      await tester.pumpWidget(ttTestApp(_chip(multi: true)));
      await tester.pumpAndSettle();
      data = tester.getSemantics(find.byType(TtReelChip)).getSemanticsData();
      expect(data.flagsCollection.isChecked, CheckedState.isFalse);
      handle.dispose();
    });

    testWidgets('semantics: a plain chip has no checked state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_chip()));
      final data = tester
          .getSemantics(find.byType(TtReelChip))
          .getSemanticsData();
      expect(data.flagsCollection.isChecked, CheckedState.none);
      handle.dispose();
    });

    testWidgets('a long name ellipsises on one line', (tester) async {
      await tester.pumpWidget(ttTestApp(_chip(name: _longName)));
      expect(tester.takeException(), isNull);
      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(find.byType(TtReelChip)).height, 58);
    });

    // The panel gives a chip 336 dp at 2x (one per row), never 164 dp. The
    // 164 dp case is a squeeze test, named as one: a chip the panel does not
    // make at 2x, kept to prove a narrow parent cannot make it overflow
    // (D-93).
    for (final (width, kind) in [
      (_rowWidth, "in the panel's row"),
      (_chipWidth, 'squeezed into a 164 dp cell the panel never makes at 2x'),
    ]) {
      for (final multi in [false, true]) {
        for (final state in TtReelChipState.values) {
          testWidgets('at 2x text nothing overflows or overlaps, $kind '
              '(multi $multi, ${state.name})', (tester) async {
            await tester.pumpWidget(
              ttTestApp(
                _chip(
                  name: _longName,
                  count: '1234 clips',
                  multi: multi,
                  state: state,
                  width: width,
                ),
                textScale: 2,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final chip = tester.getRect(find.byType(TtReelChip));
            // The chip grows with the text; it never gets shorter than 56 dp.
            expect(chip.height, greaterThanOrEqualTo(56));
            final cover = tester.getRect(
              find.byKey(const ValueKey('tt-chip-cover')),
            );
            final name = tester.getRect(find.text(_longName));
            final count = tester.getRect(find.text('1234 clips'));
            expect(chip.contains(cover.topLeft), isTrue);
            expect(chip.contains(cover.bottomRight), isTrue);
            expect(chip.contains(name.topLeft), isTrue);
            expect(chip.contains(name.bottomRight), isTrue);
            expect(chip.contains(count.bottomRight), isTrue);
            expect(name.overlaps(cover), isFalse);
            expect(count.overlaps(cover), isFalse);
            expect(name.overlaps(count), isFalse);
            if (multi && state != TtReelChipState.done) {
              final mark = tester.getRect(find.byType(TtCheckMark));
              expect(name.overlaps(mark), isFalse);
              expect(count.overlaps(mark), isFalse);
              expect(mark.overlaps(cover), isFalse);
            }
          });
        }
      }
    }

    for (final multi in [false, true]) {
      testWidgets('at 2x a name takes two lines, so "Lisbon food" is readable '
          '(multi $multi)', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            _chip(name: 'Lisbon food market', multi: multi, width: 336),
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final name = tester.widget<Text>(find.text('Lisbon food market'));
        expect(name.maxLines, 2);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Lisbon food market'),
        );
        // The first 11 letters, "Lisbon food", are laid out on one line.
        final boxes = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 11),
        );
        expect(boxes, isNotEmpty);
        expect({for (final box in boxes) box.top}, hasLength(1));
        expect(paragraph.didExceedMaxLines, isFalse);
      });
    }

    testWidgets('below 1.5x the name stays on one line', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_chip(name: _longName), textScale: 1.49),
      );
      expect(tester.widget<Text>(find.text(_longName)).maxLines, 1);
      await tester.pumpWidget(
        ttTestApp(_chip(name: _longName), textScale: 1.5),
      );
      expect(tester.widget<Text>(find.text(_longName)).maxLines, 2);
    });

    testWidgets('keeps its 48 dp target at every text size', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(ttTestApp(_chip(), textScale: scale));
        final size = tester.getSize(find.byType(TtReelChip));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });

    for (final brightness in Brightness.values) {
      for (final state in TtReelChipState.values) {
        testWidgets('passes the accessibility guidelines '
            '(${brightness.name}, ${state.name})', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              _chip(state: state, multi: state != TtReelChipState.done),
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();
          await expectTtAccessible(tester);
        });
      }
    }
  });

  group('TtNewReelChip', () {
    Widget newChip({
      String title = 'New reel',
      String? subtitle = 'Add this clip to it',
      bool fullWidth = false,
      String? semanticLabel,
      VoidCallback? onTap,
      double width = _chipWidth,
    }) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: TtVideoSurface(
          child: Builder(
            builder: (context) => ColoredBox(
              color: context.scheme.surfaceContainer,
              child: TtNewReelChip(
                title: title,
                subtitle: subtitle,
                fullWidth: fullWidth,
                semanticLabel: semanticLabel,
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    );

    DashedBorderPainter? dashed(WidgetTester tester) => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(TtNewReelChip),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((c) => c.foregroundPainter)
        .whereType<DashedBorderPainter>()
        .firstOrNull;

    testWidgets('has a dashed outline: 1.5 dp, outline colour, 18 dp radius', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(newChip(onTap: () {})));
      final painter = dashed(tester);
      expect(painter, isNotNull);
      final scheme = tester.element(find.byType(TtNewReelChip)).scheme;
      expect(painter!.color, scheme.outline);
      expect(painter.width, 1.5);
      expect(painter.radius, 18);
      expect(painter.dash, 4.5);
      expect(painter.gap, 3);
    });

    testWidgets('has no fill, a primary title and a plus on a secondary '
        'container cover', (tester) async {
      await tester.pumpWidget(ttTestApp(newChip(onTap: () {})));
      final scheme = tester.element(find.byType(TtNewReelChip)).scheme;
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtNewReelChip),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color!.a, 0);
      expect(
        tester.widget<Text>(find.text('New reel')).style!.color,
        scheme.primary,
      );
      expect(
        tester.widget<Text>(find.text('Add this clip to it')).style!.color,
        scheme.onSurfaceVariant,
      );
      final icon = tester.widget<Icon>(find.byIcon(Symbols.add_rounded));
      expect(icon.color, scheme.onSecondaryContainer);
      final cover = tester.getRect(find.byKey(const ValueKey('tt-chip-cover')));
      expect(cover.size, const Size(34, 44));
    });

    testWidgets('is as tall as a reel chip and lines up with it', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(newChip(onTap: () {})));
      final chip = tester.getRect(find.byType(TtNewReelChip));
      expect(chip.size, const Size(_chipWidth, 58));
      final cover = tester.getRect(find.byKey(const ValueKey('tt-chip-cover')));
      expect(cover.left - chip.left, 7);
      expect(cover.top - chip.top, 7);
    });

    testWidgets('new reel chip spans the row when fullWidth', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          newChip(
            fullWidth: true,
            subtitle: null,
            width: _rowWidth,
            onTap: () {},
          ),
        ),
      );
      final chip = tester.getRect(find.byType(TtNewReelChip));
      expect(chip.width, _rowWidth);
      // The cover and the title are centred together as one group.
      final cover = tester.getRect(find.byKey(const ValueKey('tt-chip-cover')));
      final title = tester.getRect(find.text('New reel'));
      final group = cover.expandToInclude(title);
      // Centred in the padded area, which has 7 dp at the start and 11 at the
      // end, so 2 dp left of the middle of the chip.
      expect(group.center.dx, closeTo(chip.center.dx - 2, 1));
      expect(find.text('Add this clip to it'), findsNothing);
      // The outline follows the whole width.
      expect(dashed(tester), isNotNull);
    });

    testWidgets('a tap calls onTap; a chip without one is inert', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(newChip(onTap: () => taps++)));
      await tester.tap(find.byType(TtNewReelChip));
      expect(taps, 1);
      await tester.pumpWidget(ttTestApp(newChip()));
      await tester.tap(find.byType(TtNewReelChip));
      expect(taps, 1);
    });

    testWidgets('semantics: a button named by the title, or by semanticLabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(newChip(onTap: () {})));
      var data = tester
          .getSemantics(find.byType(TtNewReelChip))
          .getSemanticsData();
      expect(data.label, 'New reel');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      await tester.pumpWidget(
        ttTestApp(
          newChip(semanticLabel: 'Create a reel for this clip', onTap: () {}),
        ),
      );
      data = tester.getSemantics(find.byType(TtNewReelChip)).getSemanticsData();
      expect(data.label, 'Create a reel for this clip');
      handle.dispose();
    });

    testWidgets('at 2x a long title takes two lines and nothing overflows', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          newChip(
            title: 'Make a brand new reel for this clip',
            subtitle: 'Add this clip to it right away',
            width: _rowWidth,
            onTap: () {},
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<Text>(find.text('Make a brand new reel for this clip'))
            .maxLines,
        2,
      );
      expect(
        tester.getSize(find.byType(TtNewReelChip)).height,
        greaterThanOrEqualTo(56),
      );
    });

    testWidgets('keeps its dashed outline at 2x text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(newChip(width: _rowWidth, onTap: () {}), textScale: 2),
      );
      expect(dashed(tester), isNotNull);
    });

    for (final brightness in Brightness.values) {
      for (final full in [false, true]) {
        testWidgets('passes the accessibility guidelines '
            '(${brightness.name}, fullWidth $full)', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              newChip(
                fullWidth: full,
                subtitle: full ? null : 'Add this clip to it',
                width: full ? _rowWidth : _chipWidth,
                onTap: () {},
              ),
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    }
  });

  // Phase 12, Task 7 (D-178): the on-video style, glass over the playing clip.
  group('TtReelChip, onVideo style', () {
    testWidgets('is at least 52 dp high with a 30 x 40 cover, and the glass '
        '0xD61E2024 blurred by 14', (tester) async {
      await tester.pumpWidget(ttTestApp(_videoChip()));
      expect(TtMetrics.reelChipOnVideoMinHeight, 52);
      expect(TtMetrics.reelChipOnVideoCoverWidth, 30);
      expect(TtMetrics.reelChipOnVideoCoverHeight, 40);
      final chip = tester.getRect(find.byType(TtReelChip));
      expect(chip.height, greaterThanOrEqualTo(52));
      // 40 dp cover + 2 x (6 dp padding + 1 dp border).
      expect(chip.size, const Size(_chipWidth, 54));
      final cover = tester.getRect(find.byKey(const ValueKey('tt-chip-cover')));
      expect(cover.size, const Size(30, 40));
      expect(cover.left - chip.left, 7);
      expect(_glassColor(tester), const Color(0xD61E2024));
      expectBlurFilter(tester, find.byType(TtReelChip), 14);
      expectGlassStructure(tester, find.byType(TtReelChip));
      final clip = tester.widget<ClipRRect>(
        find
            .descendant(
              of: find.byType(TtReelChip),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(18));
    });

    group('the picked and done fills animate (D-178)', () {
      Future<void> showState(
        WidgetTester tester,
        TtReelChipState state, {
        bool disableAnimations = false,
      }) => tester.pumpWidget(
        ttTestApp(
          _videoChip(state: state, multi: true),
          disableAnimations: disableAnimations,
        ),
      );

      /// [c] is neither [from] nor [to], and no channel is outside them.
      bool strictlyBetween(Color c, Color from, Color to) {
        bool within(double v, double a, double b) =>
            v >= (a < b ? a : b) - .001 && v <= (a < b ? b : a) + .001;
        return c != from &&
            c != to &&
            within(c.a, from.a, to.a) &&
            within(c.r, from.r, to.r) &&
            within(c.g, from.g, to.g) &&
            within(c.b, from.b, to.b);
      }

      testWidgets('idle to picked: halfway through it is neither fill', (
        tester,
      ) async {
        await showState(tester, TtReelChipState.idle);
        final idle = _glassColor(tester);
        await showState(tester, TtReelChipState.picked);
        final picked = tester
            .element(find.byType(TtReelChip))
            .scheme
            .primaryContainer;
        expect(
          _glassColor(tester),
          idle,
          reason: 'the first frame starts at idle',
        );
        await tester.pump(const Duration(milliseconds: 75));
        final middle = _glassColor(tester);
        expect(
          strictlyBetween(middle, idle, picked),
          isTrue,
          reason: '$middle',
        );
        // The glass keeps its order mid-way: blur 14, a plain fill first, and
        // no Opacity (D-173, F8).
        expectBlurFilter(tester, find.byType(TtReelChip), 14);
        expectGlassStructure(tester, find.byType(TtReelChip));
        expect(
          find.descendant(
            of: find.byType(TtReelChip),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
        await tester.pumpAndSettle();
        expect(_glassColor(tester), picked);
      });

      testWidgets('picked to done, and back to idle', (tester) async {
        await showState(tester, TtReelChipState.picked);
        final scheme = tester.element(find.byType(TtReelChip)).scheme;
        await showState(tester, TtReelChipState.done);
        await tester.pump(const Duration(milliseconds: 75));
        expect(
          strictlyBetween(
            _glassColor(tester),
            scheme.primaryContainer,
            scheme.primary,
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(_glassColor(tester), scheme.primary);

        await showState(tester, TtReelChipState.idle);
        await tester.pump(const Duration(milliseconds: 75));
        expect(
          strictlyBetween(
            _glassColor(tester),
            scheme.primary,
            const Color(0xD61E2024),
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(_glassColor(tester), const Color(0xD61E2024));
      });

      testWidgets('a chip first built picked or done does not animate in', (
        tester,
      ) async {
        await showState(tester, TtReelChipState.done);
        final scheme = tester.element(find.byType(TtReelChip)).scheme;
        expect(_glassColor(tester), scheme.primary);
        await tester.pump(const Duration(milliseconds: 75));
        expect(_glassColor(tester), scheme.primary);
      });

      testWidgets('with reduced motion the new fill is there at once', (
        tester,
      ) async {
        await showState(tester, TtReelChipState.idle, disableAnimations: true);
        await showState(
          tester,
          TtReelChipState.picked,
          disableAnimations: true,
        );
        await tester.pump();
        final scheme = tester.element(find.byType(TtReelChip)).scheme;
        expect(_glassColor(tester), scheme.primaryContainer);
      });
    });

    testWidgets('idle: a white name and a count at 78 %', (tester) async {
      await tester.pumpWidget(ttTestApp(_videoChip()));
      expect(TtMetrics.reelChipOnVideoCountOpacity, .78);
      final name = tester.widget<Text>(find.text('Lisbon trip'));
      expect(name.style!.color, const Color(0xFFFFFFFF));
      expect(name.style!.fontSize, 14);
      final count = tester.widget<Text>(find.text('12 clips'));
      expect(count.style!.color!.a, closeTo(.78, .005));
      expect(count.style!.color!.withValues(alpha: 1), const Color(0xFFFFFFFF));
      expect(count.style!.fontSize, 12);
      // The glass has no Material fill and no visible border.
      expect(_border(tester).color.a, 0);
    });

    testWidgets('picked keeps primary container with a primary border, and '
        'the count at 85 %', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_videoChip(state: TtReelChipState.picked, multi: true)),
      );
      await tester.pumpAndSettle();
      final scheme = tester.element(find.byType(TtReelChip)).scheme;
      expect(TtMetrics.reelChipOnVideoStateCountOpacity, .85);
      expect(_glassColor(tester), scheme.primaryContainer);
      expect(_border(tester).color, scheme.primary);
      expect(_border(tester).width, 1);
      expect(
        tester.widget<Text>(find.text('Lisbon trip')).style!.color,
        scheme.onPrimaryContainer,
      );
      final count = tester.widget<Text>(find.text('12 clips')).style!.color!;
      expect(count.a, closeTo(.85, .005));
      expect(
        count.withValues(alpha: 1),
        scheme.onPrimaryContainer.withValues(alpha: 1),
      );
      expect(
        tester.widget<TtCheckMark>(find.byType(TtCheckMark)).checked,
        isTrue,
      );
    });

    testWidgets('done keeps the primary fill, a check, the 0.97 scale and '
        'the count at 85 %', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_videoChip(state: TtReelChipState.done)),
      );
      await tester.pumpAndSettle();
      final scheme = tester.element(find.byType(TtReelChip)).scheme;
      expect(_glassColor(tester), scheme.primary);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        0.97,
      );
      expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Lisbon trip')).style!.color,
        scheme.onPrimary,
      );
      expect(
        tester.widget<Text>(find.text('12 clips')).style!.color!.a,
        closeTo(.85, .005),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-chip-cover'))),
        const Size(30, 40),
      );
    });

    testWidgets('the idle count is not at the state opacity (85 %)', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_videoChip()));
      expect(
        tester.widget<Text>(find.text('12 clips')).style!.color!.a,
        isNot(closeTo(.85, .02)),
      );
    });

    testWidgets('a tap and a long press call their handlers', (tester) async {
      var taps = 0;
      var longs = 0;
      await tester.pumpWidget(
        ttTestApp(_videoChip(onTap: () => taps++, onLongPress: () => longs++)),
      );
      await tester.tap(find.byType(TtReelChip));
      expect(taps, 1);
      await tester.longPress(find.byType(TtReelChip));
      expect(longs, 1);
      expect(taps, 1);
    });

    testWidgets('semantics: one button named semanticLabel, with tap and long '
        'press', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_videoChip(onLongPress: () {})));
      final data = tester
          .getSemantics(find.byType(TtReelChip))
          .getSemanticsData();
      expect(data.label, 'Add to Lisbon trip, 12 clips');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      handle.dispose();
    });

    testWidgets('semantics: a multi-select chip reports checked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_videoChip(state: TtReelChipState.picked, multi: true)),
      );
      final data = tester
          .getSemantics(find.byType(TtReelChip))
          .getSemanticsData();
      expect(data.flagsCollection.isChecked, CheckedState.isTrue);
      handle.dispose();
    });

    testWidgets('a long name ellipsises on one line', (tester) async {
      await tester.pumpWidget(ttTestApp(_videoChip(name: _longName)));
      expect(tester.takeException(), isNull);
      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(find.byType(TtReelChip)).height, 54);
    });

    testWidgets('at 2x the name takes two lines, nothing overflows and the '
        'glass grows with the chip', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_videoChip(name: _longName, width: _rowWidth), textScale: 2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text(_longName)).maxLines, 2);
      final chip = tester.getSize(find.byType(TtReelChip));
      expect(chip.height, greaterThan(54));
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(TtReelChip),
            matching: find.byType(BackdropFilter),
          ),
        ),
        chip,
      );
    });

    testWidgets('the cover is centred in the grown chip at 2x', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_videoChip(name: _longName, width: _rowWidth), textScale: 2),
      );
      final chip = tester.getRect(find.byType(TtReelChip));
      final cover = tester.getRect(find.byKey(const ValueKey('tt-chip-cover')));
      expect(cover.center.dy, closeTo(chip.center.dy, .5));
    });

    testWidgets('the surface style is the default and has no glass', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_chip()));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-chip-cover'))),
        const Size(34, 44),
      );
      expect(tester.getSize(find.byType(TtReelChip)).height, 58);
      expect(_fill(tester), isNotNull);
      expect(TtReelChipStyle.values, [
        TtReelChipStyle.surface,
        TtReelChipStyle.onVideo,
      ]);
    });

    group('contrast', () {
      // The chips sit on the dock's scrim (black, at least 74 %) over the
      // clip, never bare on it: the stand-in is a white frame under black
      // at 74 %, the weakest stop the chips ever sit on.
      Widget scrimOverWhite(Widget child) => Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFFFFFFF)),
          ColoredBox(color: const Color(0xFF000000).withValues(alpha: .74)),
          Align(alignment: Alignment.topLeft, child: child),
        ],
      );

      Future<List<TtTextContrastSample>> measure(WidgetTester tester) async {
        final semantics = tester.ensureSemantics();
        try {
          return await measureTtTextContrast(tester);
        } finally {
          semantics.dispose();
        }
      }

      for (final state in TtReelChipState.values) {
        testWidgets('a ${state.name} chip reads AA over a white frame '
            'under the dock scrim', (tester) async {
          await tester.pumpWidget(
            ttPixelApp(
              scrimOverWhite(
                _videoChip(state: state, multi: state != TtReelChipState.done),
              ),
              brightness: Brightness.dark,
            ),
          );
          await tester.pumpAndSettle();
          final samples = await measure(tester);
          expect(samples, hasLength(2));
          for (final sample in samples) {
            expect(sample.ratio, greaterThanOrEqualTo(4.5), reason: '$sample');
          }
          final semantics = tester.ensureSemantics();
          await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
          semantics.dispose();
        });
      }

      testWidgets('an idle chip reads AA even bare on a pure white frame', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttPixelApp(
            Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFFFFFFFF)),
                Align(alignment: Alignment.topLeft, child: _videoChip()),
              ],
            ),
            brightness: Brightness.dark,
          ),
        );
        final samples = await measure(tester);
        expect(samples, hasLength(2));
        for (final sample in samples) {
          expect(sample.ratio, greaterThanOrEqualTo(4.5), reason: '$sample');
        }
      });

      testWidgets('passes the accessibility guidelines', (tester) async {
        await tester.pumpWidget(
          ttPixelApp(scrimOverWhite(_videoChip()), brightness: Brightness.dark),
        );
        await expectTtAccessible(tester);
      });
    });
  });

  group('TtNewReelChip, onVideo style', () {
    testWidgets('is at least 52 dp high with a 30 x 40 cover and the glass '
        '0x8C1E2024 blurred by 14', (tester) async {
      await tester.pumpWidget(ttTestApp(_videoNewChip()));
      final chip = tester.getRect(find.byType(TtNewReelChip));
      expect(chip.size, const Size(_chipWidth, 54));
      final cover = tester.getRect(find.byKey(const ValueKey('tt-chip-cover')));
      expect(cover.size, const Size(30, 40));
      expect(_glassColor(tester, of: TtNewReelChip), const Color(0x8C1E2024));
      expectBlurFilter(tester, find.byType(TtNewReelChip), 14);
      expectGlassStructure(tester, find.byType(TtNewReelChip));
    });

    testWidgets('has a 1.5 dp dashed border in white at 55 %', (tester) async {
      await tester.pumpWidget(ttTestApp(_videoNewChip()));
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(TtNewReelChip),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.foregroundPainter)
          .whereType<DashedBorderPainter>()
          .single;
      expect(painter.color, const Color(0x8CFFFFFF));
      expect(painter.width, 1.5);
      expect(painter.radius, 18);
      expect(painter.dash, 4.5);
      expect(painter.gap, 3);
    });

    testWidgets('a white title, a subtitle at 78 %, the secondary container '
        'cover and the plus', (tester) async {
      await tester.pumpWidget(ttTestApp(_videoNewChip()));
      final scheme = tester.element(find.byType(TtNewReelChip)).scheme;
      expect(
        tester.widget<Text>(find.text('New reel')).style!.color,
        const Color(0xFFFFFFFF),
      );
      final sub = tester.widget<Text>(find.text('Add this clip to it'));
      expect(sub.style!.color!.a, closeTo(.78, .005));
      expect(sub.style!.color!.withValues(alpha: 1), const Color(0xFFFFFFFF));
      final cover = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey('tt-chip-cover')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(cover.color, scheme.secondaryContainer);
      final plus = tester.widget<Icon>(find.byIcon(Symbols.add_rounded));
      expect(plus.color, scheme.onSecondaryContainer);
    });

    testWidgets('a tap calls onTap, and a chip with no onTap is inert', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_videoNewChip(onTap: () => taps++)));
      await tester.tap(find.byType(TtNewReelChip));
      expect(taps, 1);
      await tester.pumpWidget(ttTestApp(_videoNewChip()));
      await tester.tap(find.byType(TtNewReelChip));
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics: one button named semanticLabel', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_videoNewChip(semanticLabel: 'Create a reel for this clip')),
      );
      final data = tester
          .getSemantics(find.byType(TtNewReelChip))
          .getSemanticsData();
      expect(data.label, 'Create a reel for this clip');
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('full width with no subtitle takes the row, centred', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _videoNewChip(fullWidth: true, subtitle: null, width: _rowWidth),
        ),
      );
      final chip = tester.getRect(find.byType(TtNewReelChip));
      expect(chip.width, _rowWidth);
      expect(chip.height, 54);
      final cover = tester.getRect(find.byKey(const ValueKey('tt-chip-cover')));
      final title = tester.getRect(find.text('New reel'));
      final content = cover.expandToInclude(title);
      // The padding is 7 dp before and 11 dp after, so the middle of the
      // content is 2 dp before the middle of the chip.
      expect(content.center.dx, closeTo(chip.center.dx - 2, .5));
    });

    testWidgets('at 2x a long title takes two lines and nothing overflows', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _videoNewChip(
            title: 'Make a brand new reel for this clip',
            subtitle: 'Add this clip to it right away',
            width: _rowWidth,
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<Text>(find.text('Make a brand new reel for this clip'))
            .maxLines,
        2,
      );
    });

    testWidgets('the surface New reel chip is unchanged: no glass', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _chipWidth,
              child: TtNewReelChip(title: 'New reel'),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.getSize(find.byType(TtNewReelChip)).height, 58);
    });

    group('contrast', () {
      testWidgets('the title and subtitle read AA over a white frame under '
          'the dock scrim', (tester) async {
        await tester.pumpWidget(
          ttPixelApp(
            Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFFFFFFFF)),
                ColoredBox(
                  color: const Color(0xFF000000).withValues(alpha: .74),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: _videoNewChip(onTap: () {}),
                ),
              ],
            ),
            brightness: Brightness.dark,
          ),
        );
        final handle = tester.ensureSemantics();
        final samples = await measureTtTextContrast(tester);
        expect(samples, hasLength(2));
        for (final sample in samples) {
          expect(sample.ratio, greaterThanOrEqualTo(4.5), reason: '$sample');
        }
        await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
        handle.dispose();
      });
    });
  });
}

Widget _videoChip({
  String name = 'Lisbon trip',
  TtReelChipState state = TtReelChipState.idle,
  bool multi = false,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  double width = _chipWidth,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width,
    child: TtReelChip(
      name: name,
      countText: '12 clips',
      semanticLabel: 'Add to $name, 12 clips',
      state: state,
      multiSelect: multi,
      style: TtReelChipStyle.onVideo,
      onTap: onTap ?? () {},
      onLongPress: onLongPress,
    ),
  ),
);

Widget _videoNewChip({
  String title = 'New reel',
  String? subtitle = 'Add this clip to it',
  String? semanticLabel,
  bool fullWidth = false,
  VoidCallback? onTap,
  double width = _chipWidth,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width,
    child: TtNewReelChip(
      title: title,
      subtitle: subtitle,
      semanticLabel: semanticLabel,
      fullWidth: fullWidth,
      style: TtReelChipStyle.onVideo,
      onTap: onTap,
    ),
  ),
);

/// The fill under the chip's `BackdropFilter`.
Color _glassColor(WidgetTester tester, {Type of = TtReelChip}) => tester
    .widget<ColoredBox>(
      find
          .descendant(
            of: find.descendant(
              of: find.byType(of),
              matching: find.byType(BackdropFilter),
            ),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

/// The border painted over the glass of an on-video chip.
BorderSide _border(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(TtReelChip),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.position == DecorationPosition.foreground,
          ),
        )
        .first,
  );
  return ((box.decoration as BoxDecoration).border! as Border).top;
}
