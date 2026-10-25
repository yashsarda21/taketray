import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _longName = 'Saturday morning market walk with the whole family';

/// The width of a chip in the panel at 360 dp: (360 - 2 x 12 - 8) / 2.
const _chipWidth = 164.0;

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

    for (final multi in [false, true]) {
      for (final state in TtReelChipState.values) {
        testWidgets('at 2x text nothing overflows or overlaps '
            '(multi $multi, ${state.name})', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              _chip(
                name: _longName,
                count: '1234 clips',
                multi: multi,
                state: state,
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
}
