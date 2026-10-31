import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _rows = [
  TtTagDoneRow(name: 'Lisbon trip', count: '+5'),
  TtTagDoneRow(name: 'Garden', count: '+2'),
  TtTagDoneRow(name: 'Skipped', count: '3'),
];

Widget _done({
  List<TtTagDoneRow> rows = _rows,
  VoidCallback? onPrimary,
  VoidCallback? onSecondary,
  String body = '10 clips sorted. Nice work.',
}) => TtTagDone(
  title: 'All done!',
  body: body,
  rows: rows,
  primaryLabel: 'See your reels',
  onPrimary: onPrimary ?? () {},
  secondaryLabel: 'Back to To tag',
  onSecondary: onSecondary ?? () {},
);

void main() {
  group('TtTagDone', () {
    testWidgets('shows the badge, title, body, rows and both actions', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_done()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
      expect(find.text('All done!'), findsOneWidget);
      expect(find.text('10 clips sorted. Nice work.'), findsOneWidget);
      for (final row in _rows) {
        expect(find.text(row.name), findsOneWidget);
        expect(find.text(row.count), findsOneWidget);
      }
      expect(find.text('See your reels'), findsOneWidget);
      expect(find.text('Back to To tag'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is always dark: black, with white text, in the light app '
        'theme', (tester) async {
      await tester.pumpWidget(ttTestApp(_done()));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('All done!'));
      expect(context.tt.colors.videoBackground, const Color(0xFF000000));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtTagDone),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, context.tt.colors.videoBackground);
      expect(
        tester.widget<Text>(find.text('All done!')).style!.color,
        context.tt.colors.onVideo,
      );
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('the badge is a 96 dp success circle with a 48 dp check', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_done()));
      await tester.pumpAndSettle();
      final badge = tester.getSize(find.byKey(const ValueKey('tt-done-badge')));
      expect(badge, const Size(96, 96));
      final colors = tester.element(find.text('All done!')).tt.colors;
      final box = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('tt-done-badge')),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, colors.success);
      final icon = tester.widget<Icon>(find.byIcon(Symbols.check_rounded));
      expect(icon.size, 48);
      expect(icon.color, colors.onSuccess);
    });

    testWidgets('the badge pops in, and does not move with reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_done()));
      double scale() => tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('tt-done-badge')),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .entry(0, 0);
      expect(scale(), closeTo(0.4, 0.05));
      await tester.pumpAndSettle();
      expect(scale(), closeTo(1, 0.001));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(ttTestApp(_done(), disableAnimations: true));
      expect(scale(), closeTo(1, 0.001));
    });

    testWidgets('done rows read name then count', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_done()));
      await tester.pumpAndSettle();
      for (final row in _rows) {
        final data = tester
            .getSemantics(find.text(row.name))
            .getSemanticsData();
        expect(data.label, '${row.name}\n${row.count}');
      }
      handle.dispose();
    });

    testWidgets('the title is a heading; the badge is not announced', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_done()));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('All done!'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tt-done-badge')),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('the actions call their handlers', (tester) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(
        ttTestApp(
          _done(onPrimary: () => primary++, onSecondary: () => secondary++),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('See your reels'));
      await tester.tap(find.text('Back to To tag'));
      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('the secondary action is white text on the black ground', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_done()));
      await tester.pumpAndSettle();
      final colors = tester.element(find.text('All done!')).tt.colors;
      final text = Theme.of(tester.element(find.text('Back to To tag')));
      expect(text.colorScheme.primary, colors.onVideo);
      // The main action keeps the theme's own primary.
      final main = Theme.of(tester.element(find.text('See your reels')));
      expect(main.colorScheme.primary, isNot(colors.onVideo));
    });

    testWidgets('the summary is at most 300 dp wide, centred, with a divider '
        'between rows and none after the last', (tester) async {
      await tester.pumpWidget(ttTestApp(_done()));
      await tester.pumpAndSettle();
      final summary = tester.getRect(
        find.byKey(const ValueKey('tt-done-summary')),
      );
      expect(summary.width, 300);
      expect(summary.center.dx, closeTo(400, 0.5));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tt-done-summary')),
          matching: find.byType(Divider),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('no rows draws no summary', (tester) async {
      await tester.pumpWidget(ttTestApp(_done(rows: const [])));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tt-done-summary')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('25 reels at 2x scroll and the actions stay reachable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var primary = 0;
      await tester.pumpWidget(
        ttTestApp(
          _done(
            rows: [
              for (var i = 0; i < 25; i++)
                TtTagDoneRow(
                  name: 'Saturday morning market walk number $i',
                  count: '+$i',
                ),
            ],
            onPrimary: () => primary++,
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.dragFrom(const Offset(180, 400), const Offset(0, -9000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See your reels'));
      expect(primary, 1);
    });

    testWidgets('a few rows are centred in the screen', (tester) async {
      tester.view.physicalSize = const Size(360, 780) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ttTestApp(_done()));
      await tester.pumpAndSettle();
      final top = tester
          .getRect(find.byKey(const ValueKey('tt-done-badge')))
          .top;
      final bottom = tester.getRect(find.text('Back to To tag')).bottom;
      expect((top + bottom) / 2, closeTo(390, 40));
    });

    testWidgets('a long reel name wraps and the count keeps its place', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _done(
            rows: const [
              TtTagDoneRow(
                name:
                    'Saturday morning market walk with the whole family and '
                    'the dog',
                count: '+12',
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final name = tester.getRect(find.textContaining('Saturday'));
      final count = tester.getRect(find.text('+12'));
      expect(count.left, greaterThanOrEqualTo(name.right));
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('at ${scale}x text it does not overflow', (tester) async {
        await tester.pumpWidget(ttTestApp(_done(), textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(_done(), brightness: brightness));
        await tester.pumpAndSettle();
        await expectTtAccessible(tester);
      });
    }
  });
}
