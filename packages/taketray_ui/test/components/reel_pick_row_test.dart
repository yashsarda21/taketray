import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _row({
  String name = 'Lisbon trip',
  String count = '12 clips',
  bool selected = false,
  bool multi = true,
  ImageProvider? cover,
  VoidCallback? onTap,
}) => Align(
  alignment: Alignment.topCenter,
  child: TtReelPickRow(
    name: name,
    countText: count,
    semanticLabel: '$name, $count',
    selected: selected,
    multi: multi,
    cover: cover,
    onTap: onTap,
  ),
);

void _phone(WidgetTester tester, {double height = 800}) {
  tester.view
    ..physicalSize = Size(360, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

SemanticsData _data(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();

void main() {
  group('TtReelPickRow', () {
    testWidgets('has a 40 x 52 cover, the name, the count and a check box', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        ttTestApp(_row(cover: fixtureThumb(1), onTap: () {})),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-pick-cover'))),
        const Size(40, 52),
      );
      expect(find.text('Lisbon trip'), findsOneWidget);
      expect(find.text('12 clips'), findsOneWidget);
      expect(find.byType(TtCheckMark), findsOneWidget);
      expect(find.byType(TtRadioMark), findsNothing);
      // 16 dp from the side, 16 dp between the cover and the text.
      expect(
        tester.getRect(find.byKey(const ValueKey('tt-pick-cover'))).left,
        16,
      );
      expect(
        tester.getRect(find.text('Lisbon trip')).left -
            tester.getRect(find.byKey(const ValueKey('tt-pick-cover'))).right,
        16,
      );
      expect(tester.getSize(find.byType(TtReelPickRow)).height, 68);
    });

    testWidgets('single choice shows a radio mark', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        ttTestApp(_row(multi: false, selected: true, onTap: () {})),
      );
      expect(find.byType(TtRadioMark), findsOneWidget);
      expect(find.byType(TtCheckMark), findsNothing);
      expect(
        tester.widget<TtRadioMark>(find.byType(TtRadioMark)).selected,
        isTrue,
      );
    });

    testWidgets('the mark follows selected', (tester) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_row(onTap: () {})));
      expect(
        tester.widget<TtCheckMark>(find.byType(TtCheckMark)).checked,
        isFalse,
      );
      await tester.pumpWidget(ttTestApp(_row(selected: true, onTap: () {})));
      expect(
        tester.widget<TtCheckMark>(find.byType(TtCheckMark)).checked,
        isTrue,
      );
    });

    testWidgets('no cover, or a cover that fails, shows the film icon', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_row(onTap: () {})));
      expect(find.byIcon(Symbols.movie_rounded), findsOneWidget);
      await tester.pumpWidget(
        ttTestApp(_row(cover: MemoryImage(Uint8List(8)), onTap: () {})),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.byIcon(Symbols.movie_rounded), findsOneWidget);
    });

    testWidgets('a tap anywhere on the row calls onTap', (tester) async {
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_row(onTap: () => taps++)));
      await tester.tap(find.byType(TtReelPickRow));
      await tester.tapAt(const Offset(20, 40));
      await tester.tap(find.text('12 clips'));
      expect(taps, 3);
    });

    testWidgets('a null onTap disables the row', (tester) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_row()));
      expect(
        _data(tester, 'Lisbon trip, 12 clips').flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('pick row is a checkbox with the checked state', (
      tester,
    ) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_row(onTap: () {})));
      var data = _data(tester, 'Lisbon trip, 12 clips');
      expect(data.flagsCollection.isChecked, ui.CheckedState.isFalse);
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      await tester.pumpWidget(ttTestApp(_row(selected: true, onTap: () {})));
      data = _data(tester, 'Lisbon trip, 12 clips');
      expect(data.flagsCollection.isChecked, ui.CheckedState.isTrue);
      semantics.dispose();
    });

    testWidgets('pick row is a radio with the checked state', (tester) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_row(multi: false, selected: true, onTap: () {})),
      );
      final data = _data(tester, 'Lisbon trip, 12 clips');
      expect(data.flagsCollection.isChecked, ui.CheckedState.isTrue);
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      await tester.pumpWidget(ttTestApp(_row(multi: false, onTap: () {})));
      expect(
        _data(tester, 'Lisbon trip, 12 clips').flagsCollection.isChecked,
        ui.CheckedState.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('a long name is one line; the row grows at 2x, nothing '
        'overflows', (tester) async {
      _phone(tester);
      const name = 'Saturday morning market walk with the whole family';
      await tester.pumpWidget(ttTestApp(_row(name: name, onTap: () {})));
      expect(tester.widget<Text>(find.text(name)).maxLines, 1);
      final one = tester.getSize(find.byType(TtReelPickRow)).height;
      await tester.pumpWidget(
        ttTestApp(_row(name: name, onTap: () {}), textScale: 2),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TtReelPickRow)).height,
        greaterThan(one),
      );
      // The cover stays centred in the taller row.
      final row = tester.getRect(find.byType(TtReelPickRow));
      expect(
        tester.getRect(find.byKey(const ValueKey('tt-pick-cover'))).center.dy,
        closeTo(row.center.dy, 0.5),
      );
    });

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        for (final multi in [true, false]) {
          testWidgets(
            'passes the accessibility guidelines '
            '(${brightness.name}, ${scale}x, ${multi ? 'multi' : 'single'})',
            (tester) async {
              _phone(tester);
              for (final selected in [false, true]) {
                await tester.pumpWidget(
                  ttTestApp(
                    _row(
                      selected: selected,
                      multi: multi,
                      cover: fixtureThumb(2),
                      onTap: () {},
                    ),
                    brightness: brightness,
                    textScale: scale,
                  ),
                );
                await expectTtAccessible(tester);
              }
            },
          );
        }
      }
    }
  });

  group('TtReelPickNewRow', () {
    Widget newRow({VoidCallback? onTap}) => Align(
      alignment: Alignment.topCenter,
      child: TtReelPickNewRow(label: 'New reel', onTap: onTap ?? () {}),
    );

    testWidgets('has a secondary-container box with a plus and a primary '
        'label', (tester) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(newRow()));
      final scheme = tester.element(find.text('New reel')).scheme;
      expect(
        tester.widget<Text>(find.text('New reel')).style!.color,
        scheme.primary,
      );
      final plus = find.byIcon(Symbols.add_rounded);
      expect(tester.widget<Icon>(plus).color, scheme.onSecondaryContainer);
      final box = tester.widget<DecoratedBox>(
        find.ancestor(of: plus, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        scheme.secondaryContainer,
      );
      expect(
        (box.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(14),
      );
      expect(tester.getSize(find.byType(TtReelPickNewRow)).height, 56);
    });

    testWidgets('is a button that calls onTap', (tester) async {
      _phone(tester);
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(newRow(onTap: () => taps++)));
      await tester.tap(find.text('New reel'));
      expect(taps, 1);
      final data = _data(tester, 'New reel');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        _phone(tester);
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            ttTestApp(newRow(), brightness: brightness, textScale: scale),
          );
          await expectTtAccessible(tester);
        }
      });
    }
  });
}
