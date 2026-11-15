import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const IconData _icon = Symbols.sd_card_alert_rounded;

Widget _layout({
  TtStatusTone tone = TtStatusTone.error,
  String title = 'Phone storage is full',
  Widget? body = const Text(
    '7 of 12 clips were copied before space ran out. Free up some space, '
    'then try again.',
  ),
  List<Widget>? actions,
  double width = 360,
  double height = 640,
}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    key: const ValueKey('area'),
    width: width,
    height: height,
    child: TtStatusLayout(
      icon: _icon,
      tone: tone,
      title: title,
      body: body,
      actions:
          actions ??
          [
            TtButton(label: 'Try again', onPressed: () {}),
            TtButton(
              label: 'Delete copies and stop',
              kind: TtButtonKind.text,
              onPressed: () {},
            ),
          ],
    ),
  ),
);

Color _iconColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(_icon)).color!;

void main() {
  group('TtStatusLayout tone', () {
    testWidgets('primary, error, warning and success colour the icon with '
        'the theme roles, in light and dark', (tester) async {
      for (final brightness in Brightness.values) {
        for (final (tone, pick)
            in <(TtStatusTone, Color Function(ColorScheme, TtColors))>[
              (TtStatusTone.primary, (s, c) => s.primary),
              (TtStatusTone.error, (s, c) => s.error),
              (TtStatusTone.warning, (s, c) => s.tertiary),
              (TtStatusTone.success, (s, c) => c.success),
            ]) {
          await tester.pumpWidget(
            ttTestApp(_layout(tone: tone), brightness: brightness),
          );
          final context = tester.element(find.byType(TtStatusLayout));
          expect(
            _iconColor(tester),
            pick(context.scheme, context.tt.colors),
            reason: '$tone $brightness',
          );
        }
      }
    });

    testWidgets('the four tones are four different colours', (tester) async {
      final colors = <Color>{};
      for (final tone in TtStatusTone.values) {
        await tester.pumpWidget(ttTestApp(_layout(tone: tone)));
        colors.add(_iconColor(tester));
      }
      expect(colors, hasLength(4));
    });
  });

  group('TtStatusLayout content', () {
    testWidgets('a 48 dp icon, the title, the body: one centred column '
        '12 dp apart', (tester) async {
      await tester.pumpWidget(ttTestApp(_layout()));
      expect(tester.getSize(find.byIcon(_icon)), const Size.square(48));
      final icon = tester.getRect(find.byIcon(_icon));
      final title = tester.getRect(find.text('Phone storage is full'));
      final body = tester.getRect(find.textContaining('7 of 12'));
      expect(title.top - icon.bottom, closeTo(12, 0.5));
      expect(body.top - title.bottom, closeTo(12, 0.5));
      // Centred on the 360 dp width.
      expect(icon.center.dx, closeTo(180, 0.5));
      expect(title.center.dx, closeTo(180, 0.5));
      expect(body.center.dx, closeTo(180, 0.5));
    });

    testWidgets('the block is centred in the space above the actions', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_layout()));
      final first = tester.getRect(find.byIcon(_icon));
      final last = tester.getRect(find.textContaining('7 of 12'));
      final actions = tester.getRect(find.byType(TtButton).first);
      final area = tester.getRect(find.byKey(const ValueKey('area')));
      final above = Rect.fromLTRB(
        area.left,
        area.top,
        area.right,
        actions.top - 12,
      );
      final block = Rect.fromLTRB(
        first.left,
        first.top,
        first.right,
        last.bottom,
      );
      // Centred in the space above the actions' 12 dp top padding.
      expect(block.center.dy, closeTo(above.center.dy, 1));
    });

    testWidgets('keeps 32 dp at the sides: a long title and body wrap inside '
        'and are centred', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _layout(
            title: 'This is a long title that needs several lines to fit',
            body: const Text(
              'And a body that is much longer than one line so that it has '
              'to wrap over several lines.',
            ),
          ),
        ),
      );
      final title = tester.getRect(
        find.text('This is a long title that needs several lines to fit'),
      );
      expect(title.left, greaterThanOrEqualTo(32));
      expect(title.right, lessThanOrEqualTo(360 - 32));
      final text = tester.widget<Text>(
        find.text('This is a long title that needs several lines to fit'),
      );
      expect(text.textAlign, TextAlign.center);
    });

    testWidgets('the title is headline-small in on-surface and a heading '
        'for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_layout()));
      final scheme = tester.element(find.byType(TtStatusLayout)).scheme;
      final style = tester
          .widget<Text>(find.text('Phone storage is full'))
          .style!;
      expect(style.color, scheme.onSurface);
      expect(style.fontSize, 24);
      expect(
        tester.getSemantics(find.text('Phone storage is full')),
        matchesSemantics(label: 'Phone storage is full', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('a plain Text body gets body-medium in on-surface-variant, '
        'centred', (tester) async {
      await tester.pumpWidget(ttTestApp(_layout()));
      final scheme = tester.element(find.byType(TtStatusLayout)).scheme;
      final context = tester.element(find.textContaining('7 of 12'));
      final style = DefaultTextStyle.of(context);
      expect(style.style.color, scheme.onSurfaceVariant);
      expect(style.style.fontSize, 14);
      expect(style.textAlign, TextAlign.center);
    });

    testWidgets('any widget can be the body, such as a progress bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _layout(
            body: const SizedBox(
              key: ValueKey('custom'),
              width: 200,
              height: 20,
            ),
          ),
        ),
      );
      final custom = tester.getRect(find.byKey(const ValueKey('custom')));
      expect(custom.size, const Size(200, 20));
      expect(custom.center.dx, closeTo(180, 0.5));
    });

    testWidgets('without a body there is no gap or widget for it', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_layout(body: null)));
      expect(find.textContaining('7 of 12'), findsNothing);
      expect(tester.takeException(), isNull);
      final icon = tester.getRect(find.byIcon(_icon));
      final title = tester.getRect(find.text('Phone storage is full'));
      expect(title.top - icon.bottom, closeTo(12, 0.5));
      final actions = tester.getRect(find.text('Try again'));
      // Nothing between the title and the actions but free space.
      expect(actions.top - title.bottom, greaterThan(100));
    });

    testWidgets('the icon is decoration, hidden from screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_layout()));
      expect(find.bySemanticsLabel(RegExp('sd_card')), findsNothing);
      final labelled = <String>[];
      void walk(SemanticsNode n) {
        if (n.label.isNotEmpty) labelled.add(n.label);
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(tester.getSemantics(find.byType(TtStatusLayout)));
      expect(
        labelled.where((l) => l.codeUnits.any((c) => c > 0xE000)),
        isEmpty,
      );
      handle.dispose();
    });
  });

  group('TtStatusLayout actions', () {
    testWidgets('are full width less 16 dp each side, 8 dp apart, at the '
        'bottom, in order', (tester) async {
      await tester.pumpWidget(ttTestApp(_layout()));
      final area = tester.getRect(find.byKey(const ValueKey('area')));
      final buttons = tester.getRect(find.byType(TtButton).at(0));
      final second = tester.getRect(find.byType(TtButton).at(1));
      expect(buttons.left, 16);
      expect(buttons.right, 360 - 16);
      expect(second.left, 16);
      expect(second.right, 360 - 16);
      expect(second.top - buttons.bottom, 8);
      expect(buttons.height, 48);
      expect(second.height, 48);
      // 16 dp under the last one.
      expect(area.bottom - second.bottom, 16);
    });

    testWidgets('a wide window keeps them full width of the layout', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_layout(width: 600)));
      expect(tester.getRect(find.byType(TtButton).first).width, 600 - 32);
    });

    testWidgets('are tappable, each its own', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        ttTestApp(
          _layout(
            actions: [
              TtButton(label: 'One', onPressed: () => taps.add('one')),
              TtButton(
                label: 'Two',
                kind: TtButtonKind.text,
                onPressed: () => taps.add('two'),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Two'));
      await tester.tap(find.text('One'));
      expect(taps, ['two', 'one']);
    });

    testWidgets('one action, and none, both lay out', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _layout(
            actions: [TtButton(label: 'Only', onPressed: () {})],
          ),
        ),
      );
      expect(tester.getRect(find.text('Only')).center.dx, closeTo(180, 0.5));
      await tester.pumpWidget(ttTestApp(_layout(actions: const [])));
      expect(tester.takeException(), isNull);
      expect(find.byType(TtButton), findsNothing);
    });

    testWidgets('keep clear of the bottom system bar', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: const EdgeInsets.only(bottom: 24)),
              child: _layout(),
            ),
          ),
        ),
      );
      final area = tester.getRect(find.byKey(const ValueKey('area')));
      final last = tester.getRect(find.byType(TtButton).last);
      expect(area.bottom - last.bottom, 16 + 24);
    });
  });

  group('TtStatusLayout measured numbers', () {
    testWidgets('the actions have 12 dp above them, the block 24 dp above and '
        'below it when it fills the space', (tester) async {
      const height = 420.0;
      await tester.pumpWidget(
        ttTestApp(
          _layout(
            height: height,
            body: const Text(
              'A body of enough words to make the block exactly as tall as '
              'the space above the buttons or taller than it, so that its '
              'padding shows at both ends of the scroll. '
              'A body of enough words to make the block exactly as tall as '
              'the space above the buttons or taller than it.',
            ),
          ),
          textScale: 1.5,
        ),
      );
      final area = tester.getRect(find.byKey(const ValueKey('area')));
      final icon = tester.getRect(find.byIcon(_icon));
      final body = find.textContaining('A body of enough');
      final actionsTop = tester.getRect(find.byType(TtButton).first).top;
      // The block is taller than the space: it starts 24 dp down.
      expect(tester.getRect(body).bottom, greaterThan(actionsTop - 12 - 24));
      expect(icon.top - area.top, 24);
      // Scrolled to the end it ends 24 dp above the space's end, which is
      // 12 dp above the first action.
      await tester.drag(find.byType(Scrollable), const Offset(0, -2000));
      await tester.pump();
      // Within a pixel: the text's last line has its own leading.
      expect(actionsTop - 12 - tester.getRect(body).bottom, closeTo(24, 1));
    });

    testWidgets('the first action is 12 dp under the space that holds the '
        'content', (tester) async {
      await tester.pumpWidget(ttTestApp(_layout()));
      final viewport = tester.getRect(find.byType(Scrollable));
      final first = tester.getRect(find.byType(TtButton).first);
      expect(first.top - viewport.bottom, 12);
    });
  });

  group('TtStatusLayout in a parent with no height limit', () {
    testWidgets('inside a ListView it lays out below the content, with the '
        'actions under it, and does not fail', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          ttTestApp(
            ListView(
              children: [
                TtStatusLayout(
                  icon: _icon,
                  tone: TtStatusTone.warning,
                  title: 'Phone storage is full',
                  body: const Text('Free up some space, then try again.'),
                  actions: [
                    TtButton(label: 'Try again', onPressed: () {}),
                    TtButton(
                      label: 'Cancel',
                      kind: TtButtonKind.text,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull, reason: '$scale');
        final icon = tester.getRect(find.byIcon(_icon));
        final title = tester.getRect(find.text('Phone storage is full'));
        final first = tester.getRect(find.text('Try again'));
        final second = tester.getRect(find.byType(TtButton).last);
        expect(icon.bottom, lessThanOrEqualTo(title.top));
        expect(title.bottom, lessThanOrEqualTo(first.top));
        expect(find.byType(TtButton), findsNWidgets(2));
        expect(
          tester.getRect(find.byType(TtButton).first).width,
          800 - 32,
          reason: '$scale',
        );
        expect(
          second.top - tester.getRect(find.byType(TtButton).first).bottom,
          8,
        );
        // Centred, with the content's 24 dp at the top.
        expect(icon.center.dx, closeTo(400, 0.5));
        expect(icon.top, 24);
      }
    });

    testWidgets('inside a scroll view and a Column the same', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          SingleChildScrollView(
            child: Column(
              children: [
                TtStatusLayout(
                  icon: _icon,
                  tone: TtStatusTone.error,
                  title: 'T',
                  actions: [TtButton(label: 'Go', onPressed: () {})],
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Go'), findsOneWidget);
    });
  });

  group('TtStatusLayout large text', () {
    testWidgets('at 2x on a short screen the content scrolls, the actions '
        'stay in view, and nothing overflows', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _layout(
            height: 480,
            title: 'Phone storage is full and nothing more can be copied',
            body: const Text(
              'Seven of the twelve clips were copied before the space ran '
              'out on the phone. Free up some space, then try again.',
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final area = tester.getRect(find.byKey(const ValueKey('area')));
      for (final button in tester.widgetList(find.byType(TtButton))) {
        final rect = tester.getRect(find.byWidget(button));
        expect(rect.bottom, lessThanOrEqualTo(area.bottom));
        expect(rect.top, greaterThanOrEqualTo(area.top));
      }
      expect(find.byType(Scrollable), findsOneWidget);
      // The block is taller than the space: it scrolls, to its end.
      final body = find.textContaining('Seven of');
      final before = tester.getRect(body);
      final actionsTop = tester.getRect(find.byType(TtButton).first).top;
      expect(before.bottom, greaterThan(actionsTop));
      await tester.drag(find.byType(Scrollable), const Offset(0, -500));
      await tester.pump();
      final after = tester.getRect(body);
      expect(after.top, lessThan(before.top));
      expect(after.bottom, lessThanOrEqualTo(actionsTop));
    });

    testWidgets('with room to spare the content does not scroll off '
        'centre', (tester) async {
      await tester.pumpWidget(ttTestApp(_layout()));
      final before = tester.getRect(find.byIcon(_icon));
      await tester.drag(find.byType(Scrollable), const Offset(0, -200));
      await tester.pump();
      expect(tester.getRect(find.byIcon(_icon)), before);
    });
  });

  testWidgets('every tone is accessible in light and dark, at 1x and 2x', (
    tester,
  ) async {
    for (final tone in TtStatusTone.values) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            ttTestApp(
              _layout(tone: tone),
              brightness: brightness,
              textScale: scale,
            ),
          );
          await expectTtAccessible(tester);
        }
      }
    }
  });
}
