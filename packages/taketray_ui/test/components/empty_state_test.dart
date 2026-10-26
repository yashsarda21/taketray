import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _empty({
  TtIllustrationKind illustration = TtIllustrationKind.caught,
  String title = 'All caught up',
  String body = 'New clips you shoot will show up here.',
  List<Widget> actions = const [],
}) => TtEmptyState(
  illustration: illustration,
  title: title,
  body: body,
  actions: actions,
);

void main() {
  group('TtIllustration', () {
    testWidgets('every kind is 168 x 140 and hidden from screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final kind in TtIllustrationKind.values) {
        await tester.pumpWidget(ttTestApp(Center(child: TtIllustration(kind))));
        expect(
          tester.getSize(find.byType(TtIllustration)),
          const Size(168, 140),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.bySemanticsLabel(RegExp('.+')),
          findsNothing,
          reason: '$kind',
        );
      }
      handle.dispose();
    });

    test('there are 7 kinds', () {
      expect(TtIllustrationKind.values, hasLength(7));
    });
  });

  group('TtEmptyState', () {
    testWidgets('shows the illustration, title and body', (tester) async {
      await tester.pumpWidget(ttTestApp(_empty()));
      expect(find.byType(TtIllustration), findsOneWidget);
      final scheme = tester.element(find.byType(TtEmptyState)).scheme;
      final title = tester.widget<Text>(find.text('All caught up')).style!;
      expect(title.fontSize, 22);
      expect(title.fontWeight, FontWeight.w700);
      expect(title.color, scheme.onSurface);
      expect(
        tester.widget<Text>(find.text('All caught up')).textAlign,
        TextAlign.center,
      );
      final body = tester.widget<Text>(
        find.text('New clips you shoot will show up here.'),
      );
      expect(body.style!.fontSize, 14);
      expect(body.style!.color, scheme.onSurfaceVariant);
      expect(body.textAlign, TextAlign.center);
    });

    testWidgets('is padded 40 / 32 / 24 and centred', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 360, child: _empty()),
          ),
        ),
      );
      final box = tester.getRect(find.byType(TtEmptyState));
      final ill = tester.getRect(find.byType(TtIllustration));
      expect(ill.top - box.top, 40);
      expect(ill.center.dx, box.center.dx);
      final body = tester.getRect(
        find.text('New clips you shoot will show up here.'),
      );
      // 12 dp body margin + 8 dp gap to the (empty) actions + 24 dp padding.
      expect(box.bottom - body.bottom, 12 + 8 + 24);
    });

    testWidgets('lays the title 20 dp under the illustration and the body '
        '8 dp under the title', (tester) async {
      await tester.pumpWidget(ttTestApp(_empty()));
      final ill = tester.getRect(find.byType(TtIllustration));
      final title = tester.getRect(find.text('All caught up'));
      final body = tester.getRect(
        find.text('New clips you shoot will show up here.'),
      );
      expect(title.top - ill.bottom, 8 + 12);
      expect(body.top - title.bottom, 8);
    });

    testWidgets('the body is at most 280 dp wide', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: _empty(
                body:
                    'A reel is a video you are planning, like London Food '
                    'or Day 1 Vlog. Clips you tag go into it, one by one.',
              ),
            ),
          ),
        ),
      );
      final body = tester.getRect(find.textContaining('A reel is a video'));
      expect(body.width, lessThanOrEqualTo(280));
    });

    testWidgets('actions are stacked in a centred column, 8 dp apart', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        ttTestApp(
          _empty(
            actions: [
              TtButton(
                label: 'Turn on Shooting mode',
                icon: Symbols.videocam_rounded,
                onPressed: () => calls++,
              ),
              TtButton(
                label: 'Add videos',
                kind: TtButtonKind.text,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      final a = tester.getRect(
        find.widgetWithText(TtButton, 'Turn on Shooting mode'),
      );
      final b = tester.getRect(find.widgetWithText(TtButton, 'Add videos'));
      expect(b.top, greaterThanOrEqualTo(a.bottom + 8));
      expect(a.center.dx, closeTo(b.center.dx, 0.01));
      await tester.tap(find.text('Turn on Shooting mode'));
      expect(calls, 1);
    });

    testWidgets('the title is a header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_empty()));
      expect(
        tester
            .getSemantics(find.text('All caught up'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('at 2x a long title and body wrap in full', (tester) async {
      const title = 'No videos in this folder at the moment';
      const body =
          'A reel is a video you are planning, like London Food or Day 1 '
          'Vlog. Clips you tag go into it, and you can add more later.';
      await tester.pumpWidget(
        ttTestApp(
          SingleChildScrollView(
            child: _empty(
              title: title,
              body: body,
              actions: [
                TtButton(
                  label: 'Go to To tag',
                  icon: Symbols.sell_rounded,
                  kind: TtButtonKind.tonal,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final text in [title, body]) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(text))
              .didExceedMaxLines,
          isFalse,
        );
      }
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(
            brightness: brightness,
            _empty(
              actions: [
                TtButton(
                  label: 'Open camera',
                  icon: Symbols.videocam_rounded,
                  kind: TtButtonKind.tonal,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        await expectTtAccessible(tester);
      }
    });
  });
}
