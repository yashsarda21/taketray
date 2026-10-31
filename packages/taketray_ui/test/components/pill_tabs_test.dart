import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _tabs = [
  TtPillTab<String>('all', 'All'),
  TtPillTab<String>('waiting', 'Waiting 3'),
  TtPillTab<String>('ready', 'Ready'),
  TtPillTab<String>('done', 'Published', semanticLabel: 'Published reels'),
];

void main() {
  group('TtPillTabs', () {
    testWidgets('wrapAtLargeText: at 2x the tabs wrap in rows and do not '
        'scroll', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String>(
            tabs: _tabs,
            value: 'all',
            onChanged: (_) {},
            wrapAtLargeText: true,
          ),
          textScale: 2,
        ),
      );

      expect(find.byType(SingleChildScrollView), findsNothing);
      final rights = [
        for (final label in ['All', 'Waiting 3', 'Ready', 'Published'])
          tester.getRect(find.text(label)).right,
      ];
      expect(rights.every((r) => r <= 360 - 16), isTrue, reason: 'none cut');
      final tops = {
        for (final label in ['All', 'Waiting 3', 'Ready', 'Published'])
          tester.getRect(find.text(label)).top,
      };
      expect(tops.length, greaterThan(1), reason: 'more than one row');
      expect(tester.takeException(), isNull);
    });

    testWidgets('wrapAtLargeText: at 1x the tabs still scroll sideways', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String>(
            tabs: _tabs,
            value: 'all',
            onChanged: (_) {},
            wrapAtLargeText: true,
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('a null value selects no tab', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String?>(tabs: _tabs, value: null, onChanged: (_) {}),
        ),
      );

      for (final label in ['All', 'Waiting 3', 'Ready', 'Published reels']) {
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          isNot(ui.Tristate.isTrue),
          reason: label,
        );
      }
      semantics.dispose();
    });

    testWidgets('calls onChanged with the tapped value', (tester) async {
      final values = <String>[];
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String>(tabs: _tabs, value: 'all', onChanged: values.add),
        ),
      );
      await tester.tap(find.text('Ready'));
      expect(values, ['ready']);
    });

    testWidgets('marks only the selected tab selected in semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String>(tabs: _tabs, value: 'waiting', onChanged: (_) {}),
        ),
      );
      final selected = <String>[];
      for (final label in ['All', 'Waiting 3', 'Ready', 'Published reels']) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        if (data.flagsCollection.isSelected == ui.Tristate.isTrue) {
          selected.add(label);
        } else {
          expect(data.flagsCollection.isSelected, ui.Tristate.isFalse);
        }
        expect(data.flagsCollection.isButton, isTrue);
      }
      expect(selected, ['Waiting 3']);
      semantics.dispose();
    });

    testWidgets('every tab is at least 48 dp tall to touch', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String>(tabs: _tabs, value: 'all', onChanged: (_) {}),
        ),
      );
      for (final label in ['All', 'Waiting 3', 'Ready', 'Published reels']) {
        final rect = tester.getSemantics(find.bySemanticsLabel(label)).rect;
        expect(rect.height, greaterThanOrEqualTo(48), reason: label);
      }
      semantics.dispose();
    });

    group('ensureVisible on a chip', () {
      Widget tabs({required bool inColumnScroll}) {
        final row = TtPillTabs<String>(
          tabs: const [
            TtPillTab<String>('all', 'All 12'),
            TtPillTab<String>('collecting', 'Collecting 5'),
            TtPillTab<String>('ready', 'Ready to edit 4'),
            TtPillTab<String>('published', 'Published 3'),
          ],
          value: 'all',
          onChanged: (_) {},
        );
        return ttTestApp(
          inColumnScroll
              ? ListView(children: [const SizedBox(height: 40), row])
              : row,
        );
      }

      for (final inColumnScroll in [false, true]) {
        testWidgets('settles on the last chip'
            '${inColumnScroll ? ' inside a vertical list' : ''}', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(tabs(inColumnScroll: inColumnScroll));
          expect(
            tester.getRect(find.text('Published 3')).right,
            greaterThan(360),
            reason: 'the last chip starts out of view',
          );

          await tester.ensureVisible(find.text('Published 3'));
          await tester.pumpAndSettle();

          expect(
            tester.getRect(find.text('Published 3')).right,
            lessThanOrEqualTo(360),
          );
        });
      }
    });

    testWidgets('scrolls horizontally when the tabs do not fit', (
      tester,
    ) async {
      final values = <String>[];
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String>(
            tabs: [
              for (var i = 0; i < 12; i++)
                TtPillTab<String>('t$i', 'Reel number $i'),
            ],
            value: 't0',
            onChanged: values.add,
          ),
        ),
      );
      expect(find.text('Reel number 11').hitTestable(), findsNothing);
      await tester.drag(
        find.byType(TtPillTabs<String>),
        const Offset(-2000, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reel number 11'));
      expect(values, ['t11']);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines '
          '(${brightness.name})', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            TtPillTabs<String>(
              tabs: _tabs,
              value: 'waiting',
              onChanged: (_) {},
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }

    const long = [
      TtPillTab<String>('a', 'A very long label that keeps going on'),
      TtPillTab<String>('b', 'Two'),
      TtPillTab<String>('c', 'Three tabs here'),
    ];

    testWidgets('a long label wraps into the width at 2x text', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String>(
            tabs: long,
            value: 'a',
            onChanged: (_) {},
            wrapAtLargeText: true,
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      // Every tab is wholly on the screen (none runs off to be scrolled to),
      // and they stack in more than one row.
      final tabs = [
        for (final tab in long) tester.getRect(find.text(tab.label)),
      ];
      for (final rect in tabs) {
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
      }
      expect({for (final rect in tabs) rect.top}.length, greaterThan(1));
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('a long label scrolls sideways at 2x text', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          TtPillTabs<String>(tabs: long, value: 'a', onChanged: (_) {}),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
    });
  });

  group('TtSuggestionChip', () {
    testWidgets('calls onPressed when tapped and shows its label', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtSuggestionChip(
              label: 'London Food',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('London Food'), findsOneWidget);
      await tester.tap(find.byType(TtSuggestionChip));
      expect(taps, 1);
    });

    testWidgets('keeps a 48 dp tap target around the 36 dp chip', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtSuggestionChip(label: 'Ideas', onPressed: () => taps++),
          ),
        ),
      );
      final box = tester.getRect(find.byType(TtSuggestionChip));
      expect(box.height, greaterThanOrEqualTo(48));
      await tester.tapAt(box.topCenter + const Offset(0, 2));
      expect(taps, 1);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines '
          '(${brightness.name})', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtSuggestionChip(label: 'London Food', onPressed: () {}),
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
