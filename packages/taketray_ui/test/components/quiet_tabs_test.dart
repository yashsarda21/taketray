import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _tabs = [
  TtQuietTab<String>('all', 'All', 12, semanticLabel: 'Show all reels, 12'),
  TtQuietTab<String>(
    'collecting',
    'Collecting',
    5,
    semanticLabel: 'Show Collecting reels, 5',
  ),
  TtQuietTab<String>('ready', 'Ready', 4, semanticLabel: 'Show Ready reels, 4'),
  TtQuietTab<String>(
    'published',
    'Published',
    3,
    semanticLabel: 'Show Published reels, 3',
  ),
];

Widget _tabsOf({
  String value = 'all',
  ValueChanged<String>? onChanged,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) => ttTestApp(
  TtQuietTabs<String>(
    tabs: _tabs,
    value: value,
    onChanged: onChanged ?? (_) {},
    semanticLabel: 'Show reels',
  ),
  textScale: textScale,
  brightness: brightness,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The fill of the tab whose label is [label].
Color _fill(WidgetTester tester, String label) => tester
    .widget<Material>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    )
    .color!;

Rect _fillRect(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
);

/// The plain behaviour as a desktop platform has it: a [RawScrollbar] on every
/// scrollable, sideways ones too (Material's own skips those).
class _DesktopScrollBehavior extends ScrollBehavior {
  const new();

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.macOS;
}

void main() {
  group('TtQuietTabs', () {
    testWidgets('the chosen tab is filled secondaryContainer; the others are '
        'transparent', (tester) async {
      await tester.pumpWidget(_tabsOf(value: 'ready'));
      final scheme = tester.element(find.byType(TtQuietTabs<String>)).scheme;

      expect(_fill(tester, 'Ready'), scheme.secondaryContainer);
      for (final other in ['All', 'Collecting', 'Published']) {
        expect(_fill(tester, other).a, 0, reason: other);
      }
      expect(
        tester.widget<Text>(find.text('Ready')).style?.color,
        scheme.onSecondaryContainer,
      );
      expect(
        tester.widget<Text>(find.text('Collecting')).style?.color,
        scheme.onSurfaceVariant,
      );
    });

    testWidgets('a value that no tab has chooses none', (tester) async {
      await tester.pumpWidget(_tabsOf(value: 'nothing'));
      for (final label in ['All', 'Collecting', 'Ready', 'Published']) {
        expect(_fill(tester, label).a, 0, reason: label);
      }
    });

    testWidgets('a tab is 40 dp with a 48 dp target; the count is tabular at '
        '.8 after the label with a 6 dp gap', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_tabsOf());
      final tt = tester.element(find.byType(TtQuietTabs<String>)).tt;

      final rect = _fillRect(tester, 'Collecting');
      expect(rect.height, 40);
      // padding 0 14 round the label, a 6 dp gap, the count.
      final label = tester.getRect(find.text('Collecting'));
      final count = tester.getRect(find.text('5'));
      expect(label.left - rect.left, 14);
      expect(count.left - label.right, 6);
      expect(rect.right - count.right, 14);

      final target = tester
          .getSemantics(find.bySemanticsLabel('Show Collecting reels, 5'))
          .rect;
      expect(target.height, greaterThanOrEqualTo(48));
      expect(target.width, greaterThanOrEqualTo(48));

      final style = tester.widget<Text>(find.text('5')).style!;
      expect(
        style.fontFeatures,
        contains(const ui.FontFeature.tabularFigures()),
      );
      expect(style.color!.a, closeTo(0.8, 0.01));
      expect(
        tester.widget<Text>(find.text('Collecting')).style?.fontSize,
        tt.text.material.labelLarge!.fontSize,
      );
      semantics.dispose();
    });

    testWidgets('tabs are 4 dp apart, 12 dp in from the edge, 10 dp of room '
        'under them', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_tabsOf());
      final all = tester.getRect(
        find.bySemanticsLabel('Show all reels, 12').first,
      );
      expect(tester.getRect(find.text('All')).left - 14, 12);
      expect(all, isNotNull);
      final bar = tester.getRect(find.byType(TtQuietTabs<String>));
      // 48 dp targets, then 10 dp under them.
      expect(bar.height, 48 + 10);
      // The visible pills are 4 dp + the target slack apart.
      final a = _fillRect(tester, 'All');
      final b = _fillRect(tester, 'Collecting');
      expect(b.left - a.right, 4);
    });

    testWidgets('a tap calls onChanged with its value, also on the 4 dp '
        'above the pill', (tester) async {
      _phone(tester);
      final values = <String>[];
      await tester.pumpWidget(_tabsOf(onChanged: values.add));

      await tester.tap(find.text('Ready'));
      expect(values, ['ready']);
      final pill = _fillRect(tester, 'All');
      await tester.tapAt(pill.topCenter - const Offset(0, 3));
      expect(values, ['ready', 'all']);
      // Tapping the chosen tab calls too (the screen decides).
      await tester.tap(find.text('All'));
      expect(values, ['ready', 'all', 'all']);
    });

    testWidgets('a group named "Show reels"; each tab read by its label and '
        'toggled when chosen', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_tabsOf(value: 'collecting'));

      final group = tester.getSemantics(find.bySemanticsLabel('Show reels'));
      expect(group.label, 'Show reels');

      final toggled = <String>[];
      for (final tab in _tabs) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(tab.semanticLabel))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue, reason: tab.label);
        // Every tab has a toggled state (aria-pressed), true only if chosen.
        expect(
          data.flagsCollection.isToggled,
          isNot(ui.Tristate.none),
          reason: tab.label,
        );
        if (data.flagsCollection.isToggled == ui.Tristate.isTrue) {
          toggled.add(tab.label);
        }
        // The visible label and count are not nodes of their own.
        expect(data.label, tab.semanticLabel);
      }
      expect(toggled, ['Collecting']);
      semantics.dispose();
    });

    testWidgets('a tab can be tapped by a screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      final values = <String>[];
      await tester.pumpWidget(_tabsOf(onChanged: values.add));
      tester.semantics.tap(find.semantics.byLabel('Show Published reels, 3'));
      expect(values, ['published']);
      semantics.dispose();
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('one row that scrolls sideways at 360 dp, with no '
          'scrollbar (${scale}x)', (tester) async {
        _phone(tester);
        await tester.pumpWidget(_tabsOf(textScale: scale));
        expect(find.byType(Scrollbar), findsNothing);
        final tops = {
          for (final l in ['All', 'Collecting', 'Ready', 'Published'])
            tester.getRect(find.text(l)).top,
        };
        expect(tops, hasLength(1), reason: 'one row');
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        expect(scrollable.position.axis, Axis.horizontal);
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        // Scroll to the last one and tap it.
        final values = <String>[];
        await tester.pumpWidget(
          _tabsOf(textScale: scale, onChanged: values.add),
        );
        await tester.drag(
          find.byType(TtQuietTabs<String>),
          const Offset(-600, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Published'));
        expect(values, ['published']);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the scrollbar stays off even under a behaviour that draws '
        'one on a desktop platform', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: TakeTrayTheme.light(),
          home: Scaffold(
            // The plain behaviour puts a RawScrollbar on every scrollable of
            // a desktop platform (Material's own skips sideways ones).
            body: ScrollConfiguration(
              behavior: const _DesktopScrollBehavior(),
              child: TtQuietTabs<String>(
                tabs: _tabs,
                value: 'all',
                onChanged: (_) {},
                semanticLabel: 'Show reels',
              ),
            ),
          ),
        ),
      );
      expect(find.byType(RawScrollbar), findsNothing);
      expect(find.byType(Scrollbar), findsNothing);
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: accessible', (tester) async {
        await tester.pumpWidget(
          _tabsOf(value: 'ready', brightness: brightness),
        );
        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: accessible at 2x', (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _tabsOf(value: 'ready', brightness: brightness, textScale: 2),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
