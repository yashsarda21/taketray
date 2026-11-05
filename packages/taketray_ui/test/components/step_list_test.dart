import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _steps = [
  'Open Settings > Battery > Background usage limits.',
  'Tap Never sleeping apps and add TakeTray.',
  'If TakeTray is under Sleeping apps, remove it.',
];

Widget _list([List<String> steps = _steps]) =>
    Align(alignment: Alignment.topLeft, child: TtStepList(steps));

void main() {
  group('TtStepList', () {
    testWidgets('step list numbers its items', (tester) async {
      await tester.pumpWidget(ttTestApp(_list()));
      // The numbers start at 1 and go up by one.
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.text('0.'), findsNothing);
      expect(find.text('4.'), findsNothing);
      for (final step in _steps) {
        expect(find.text(step), findsOneWidget);
      }
      // Each number is on the row of its own step, in order.
      for (var i = 0; i < _steps.length; i++) {
        expect(
          tester.getRect(find.text('${i + 1}.')).top,
          tester.getRect(find.text(_steps[i])).top,
          reason: 'step ${i + 1}',
        );
      }
    });

    testWidgets('each item reads "1. text" and the list is one group', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_list()));
      for (var i = 0; i < _steps.length; i++) {
        final data = tester
            .getSemantics(find.bySemanticsLabel('${i + 1}. ${_steps[i]}'))
            .getSemanticsData();
        expect(data.role, ui.SemanticsRole.listItem, reason: 'step ${i + 1}');
      }
      // The number and the text are not read on their own.
      expect(find.bySemanticsLabel('1.'), findsNothing);
      expect(find.bySemanticsLabel(_steps.first), findsNothing);
      // One list node holds the three items.
      final list = tester.getSemantics(find.byType(TtStepList));
      expect(list.getSemanticsData().role, ui.SemanticsRole.list);
      var items = 0;
      list.visitChildren((child) {
        items++;
        return true;
      });
      expect(items, 3);
      handle.dispose();
    });

    testWidgets('the text hangs 20 dp in and the items are 6 dp apart', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_list(const ['One.', 'Two.', 'Three.'])),
      );
      final list = tester.getRect(find.byType(TtStepList));
      expect(list.left, 0);
      for (final text in ['One.', 'Two.', 'Three.']) {
        expect(tester.getRect(find.text(text)).left, 20, reason: text);
      }
      expect(tester.getRect(find.text('1.')).left, 0);
      final first = tester.getRect(find.text('One.'));
      final second = tester.getRect(find.text('Two.'));
      final third = tester.getRect(find.text('Three.'));
      expect(second.top - first.bottom, 6);
      expect(third.top - second.bottom, 6);
    });

    testWidgets('uses body medium in the on-surface colour', (tester) async {
      await tester.pumpWidget(ttTestApp(_list()));
      final scheme = tester.element(find.byType(TtStepList)).scheme;
      for (final text in ['1.', _steps.first]) {
        final style = tester.widget<Text>(find.text(text)).style!;
        expect(style.fontSize, 14, reason: text);
        expect(style.fontWeight, FontWeight.w400, reason: text);
        expect(style.color, scheme.onSurface, reason: text);
      }
    });

    testWidgets('a long step wraps under its text, not under its number, '
        'and is not cut at 2x', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const long =
          'Long-press the TakeTray icon, tap App info, then Battery usage '
          'and choose Allow background activity.';
      await tester.pumpWidget(
        ttTestApp(
          const Padding(
            padding: EdgeInsets.all(16),
            child: TtStepList([long, 'Turn on Allow auto launch.']),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height, greaterThan(2 * 14 * 2));
      // The number is on its own and does not collide with the text.
      final number = tester.getRect(find.text('1.'));
      final text = tester.getRect(find.text(long));
      expect(text.left, greaterThanOrEqualTo(number.right));
      // The second step is below the whole first one.
      expect(
        tester.getRect(find.text('2.')).top,
        greaterThanOrEqualTo(text.bottom),
      );
    });

    testWidgets('no steps draws nothing and does not fail', (tester) async {
      await tester.pumpWidget(ttTestApp(_list(const [])));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TtStepList)).height, 0);
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(ttTestApp(brightness: brightness, _list()));
        await expectTtAccessible(tester);
      }
    });
  });
}
