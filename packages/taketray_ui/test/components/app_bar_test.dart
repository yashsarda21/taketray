import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

/// A bar in a column, so it takes its own height.
Widget _bar(
  TtAppBar bar, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) => ttTestApp(
  Column(
    children: [
      bar,
      const Expanded(child: SizedBox()),
    ],
  ),
  textScale: textScale,
  brightness: brightness,
);

TtIconButton _action(String label, {VoidCallback? onPressed}) => TtIconButton(
  icon: Symbols.search_rounded,
  semanticLabel: label,
  style: TtIconButtonStyle.glass,
  onPressed: onPressed ?? () {},
);

TtIconButton _back() => TtIconButton(
  icon: Symbols.arrow_back_rounded,
  semanticLabel: 'Back',
  style: TtIconButtonStyle.glass,
  onPressed: () {},
);

void main() {
  group('TtAppBar', () {
    testWidgets('is 64 dp high, or 80 dp when large', (tester) async {
      await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
      expect(tester.getSize(find.byType(TtAppBar)).height, 64);
      await tester.pumpWidget(
        _bar(const TtAppBar(title: 'Reels', large: true)),
      );
      expect(tester.getSize(find.byType(TtAppBar)).height, 80);
    });

    test('preferredSize is 64 dp, or 80 dp when large', () {
      expect(
        const TtAppBar(title: 'a').preferredSize,
        const Size.fromHeight(64),
      );
      expect(
        const TtAppBar(title: 'a', large: true).preferredSize,
        const Size.fromHeight(80),
      );
    });

    testWidgets('shows the title and subtitle', (tester) async {
      await tester.pumpWidget(
        _bar(const TtAppBar(title: 'Trip to Lisbon', subtitle: '12 clips')),
      );
      expect(find.text('Trip to Lisbon'), findsOneWidget);
      expect(find.text('12 clips'), findsOneWidget);
    });

    testWidgets('large uses pageTitle, default uses screenTitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bar(const TtAppBar(title: 'Reels', large: true)),
      );
      final tt = tester.element(find.byType(TtAppBar)).tt;
      expect(
        tester.widget<Text>(find.text('Reels')).style?.fontSize,
        tt.text.pageTitle.fontSize,
      );
      await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
      expect(
        tester.widget<Text>(find.text('Reels')).style?.fontSize,
        tt.text.screenTitle.fontSize,
      );
    });

    testWidgets('the title is announced as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
      expect(
        tester
            .getSemantics(find.text('Reels'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('puts leading first and actions last, 4 dp apart', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bar(
          TtAppBar(
            title: 'Reel',
            leading: _back(),
            actions: [_action('Search'), _action('More')],
          ),
        ),
      );
      final bar = tester.getRect(find.byType(TtAppBar));
      final back = tester.getRect(
        find.widgetWithIcon(TtIconButton, Symbols.arrow_back_rounded),
      );
      expect(back.left - bar.left, 4);
      expect(back.size, const Size(48, 48));
      final actions = find.widgetWithIcon(TtIconButton, Symbols.search_rounded);
      final last = tester.getRect(actions.last);
      expect(bar.right - last.right, 4);
      final first = tester.getRect(actions.first);
      expect(last.left - first.right, 4);
      // Centred vertically in the 64 dp bar.
      expect(back.center.dy, bar.center.dy);
    });

    testWidgets('the large bar starts 16 dp in and sits 10 dp down', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bar(TtAppBar(title: 'Reels', large: true, actions: [_action('Go')])),
      );
      final bar = tester.getRect(find.byType(TtAppBar));
      expect(tester.getRect(find.text('Reels')).left - bar.left, 16);
      // 80 dp with 10 dp above: the 48 dp action is centred in the other 70.
      final action = tester.getRect(find.byType(TtIconButton));
      expect(action.center.dy - bar.top, 10 + 70 / 2);
    });

    testWidgets('selection mode uses secondaryContainer, else surface', (
      tester,
    ) async {
      Color? fill() {
        final box = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(TtAppBar),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        return box.color;
      }

      await tester.pumpWidget(
        _bar(const TtAppBar(title: '3 selected', selection: true)),
      );
      final scheme = Theme.of(tester.element(find.byType(TtAppBar)))
          .colorScheme;
      expect(fill(), scheme.secondaryContainer);
      await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
      expect(fill(), scheme.surface);
    });

    testWidgets('glass actions sit on a circle, except in selection mode', (
      tester,
    ) async {
      final circles = find.descendant(
        of: find.byType(TtIconButton),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      await tester.pumpWidget(
        _bar(TtAppBar(title: 'Reels', actions: [_action('A'), _action('B')])),
      );
      expect(circles, findsNWidgets(2));
      await tester.pumpWidget(
        _bar(
          TtAppBar(
            title: '2 selected',
            selection: true,
            actions: [_action('A'), _action('B')],
          ),
        ),
      );
      expect(circles, findsNothing);
      final scheme = Theme.of(tester.element(find.byType(TtAppBar)))
          .colorScheme;
      final iconElement = tester.element(
        find.byIcon(Symbols.search_rounded).first,
      );
      expect(IconTheme.of(iconElement).color, scheme.onSecondaryContainer);
    });

    testWidgets('a long title ends in an ellipsis and keeps the actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bar(
          TtAppBar(
            title: 'Weekend in the mountains with the whole family and friends',
            subtitle: 'A long subtitle that goes on and on and on and on',
            leading: _back(),
            actions: [_action('Search'), _action('More')],
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(TtAppBar));
      expect(bar.height, 64);
      expect(
        tester.getRect(find.byType(TtIconButton).last).right,
        lessThanOrEqualTo(bar.right),
      );
      expect(
        tester
            .getRect(
              find.text(
                'Weekend in the mountains with the whole family and friends',
              ),
            )
            .right,
        lessThanOrEqualTo(tester.getRect(find.byType(TtIconButton).at(1)).left),
      );
    });

    testWidgets('at 2x the title stays inside the bar', (tester) async {
      for (final large in [false, true]) {
        await tester.pumpWidget(
          _bar(
            TtAppBar(
              title: 'Reels',
              subtitle: large ? null : 'Sub',
              large: large,
            ),
            textScale: 2,
          ),
        );
        final bar = tester.getRect(find.byType(TtAppBar));
        final title = tester.getRect(find.text('Reels'));
        expect(title.top, greaterThanOrEqualTo(bar.top));
        expect(title.bottom, lessThanOrEqualTo(bar.bottom));
        if (!large) {
          expect(
            tester.getRect(find.text('Sub')).bottom,
            lessThanOrEqualTo(bar.bottom),
          );
        }
      }
    });

    testWidgets('works as Scaffold.appBar and keeps clear of the status bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TakeTrayTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 24)),
            child: child!,
          ),
          home: const Scaffold(appBar: TtAppBar(title: 'Reels')),
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(TtAppBar));
      expect(bar.height, 64 + 24);
      expect(tester.getRect(find.text('Reels')).top, greaterThanOrEqualTo(24));
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _bar(
            TtAppBar(
              title: 'Trip to Lisbon',
              subtitle: '12 clips',
              leading: _back(),
              actions: [_action('Search'), _action('More')],
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });

      testWidgets('selection mode passes the guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _bar(
            TtAppBar(
              title: '3 selected',
              selection: true,
              leading: _back(),
              actions: [_action('Tag'), _action('Delete')],
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
