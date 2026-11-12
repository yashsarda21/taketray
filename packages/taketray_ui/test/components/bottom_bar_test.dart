import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _longTitle = 'Select all the clips that you shot this week';
const _longSubtitle =
    '2 min 40 s · added in shooting order, so nothing needs sorting';

Widget _bar({
  String title = '3 videos picked',
  String subtitle = '1 min 20 s · added in shooting order',
  String action = 'Add 3',
  VoidCallback? onPressed,
  Key? key,
}) => Align(
  alignment: Alignment.bottomCenter,
  child: TtBottomBar(
    key: key,
    title: title,
    subtitle: subtitle,
    action: TtButton(label: action, onPressed: onPressed),
  ),
);

DecoratedBox _decorated(WidgetTester tester) => tester.widget<DecoratedBox>(
  find
      .descendant(
        of: find.byType(TtBottomBar),
        matching: find.byType(DecoratedBox),
      )
      .first,
);

void main() {
  group('TtBottomBar', () {
    testWidgets('is a surface-container bar with a 1 dp outline-variant line '
        'on top and no other border', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      final scheme = tester.element(find.byType(TtBottomBar)).scheme;
      final decoration = _decorated(tester).decoration as BoxDecoration;
      expect(decoration.color, scheme.surfaceContainer);
      final border = decoration.border! as Border;
      expect(border.top, BorderSide(color: scheme.outlineVariant));
      expect(border.top.width, 1);
      expect(border.bottom, BorderSide.none);
      expect(border.left, BorderSide.none);
      expect(border.right, BorderSide.none);
    });

    testWidgets('fills the width; 16 dp at the sides and 12 dp above and '
        'below the 48 dp button', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      final bar = tester.getRect(find.byType(TtBottomBar));
      expect(bar.width, 800);
      final button = tester.getRect(find.byType(TtButton));
      expect(button.height, 48);
      expect(bar.right - button.right, 16);
      // The line is drawn on the bar's top edge; it adds no height.
      expect(bar.height, 12 + 48 + 12);
      expect(button.top - bar.top, 12);
      expect(bar.bottom - button.bottom, 12);
      expect(tester.getRect(find.text('3 videos picked')).left - bar.left, 16);
    });

    testWidgets('title is title-small in on-surface, subtitle body-small in '
        'on-surface-variant, the title above the subtitle', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      final scheme = tester.element(find.byType(TtBottomBar)).scheme;
      final title = tester.widget<Text>(find.text('3 videos picked')).style!;
      expect(title.color, scheme.onSurface);
      expect(title.fontSize, 14);
      expect(title.fontWeight, FontWeight.w600);
      final subtitle = tester
          .widget<Text>(find.text('1 min 20 s · added in shooting order'))
          .style!;
      expect(subtitle.color, scheme.onSurfaceVariant);
      expect(subtitle.fontSize, 12);
      expect(
        tester.getRect(find.text('3 videos picked')).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.text('1 min 20 s · added in shooting order')).top,
        ),
      );
    });

    testWidgets('the text takes the room the action leaves and sits 12 dp '
        'from it', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      final button = tester.getRect(find.byType(TtButton));
      final title = tester.getRect(find.text('3 videos picked'));
      expect(title.right, lessThanOrEqualTo(button.left - 12));
      final column = tester.getRect(
        find.ancestor(
          of: find.text('3 videos picked'),
          matching: find.byType(Column),
        ),
      );
      expect(button.left - column.right, 12);
    });

    testWidgets('both lines wrap at 2x text, are not cut, and the button '
        'keeps its 48 dp height', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _bar(title: _longTitle, subtitle: _longSubtitle),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.renderObject<RenderParagraph>(find.text(_longTitle));
      final subtitle = tester.renderObject<RenderParagraph>(
        find.text(_longSubtitle),
      );
      expect(title.didExceedMaxLines, isFalse);
      expect(subtitle.didExceedMaxLines, isFalse);
      // Wrapped: more than one line each (a title line is 20 dp at 1x).
      expect(title.size.height, greaterThan(2 * 14 * 1.3));
      expect(subtitle.size.height, greaterThan(2 * 12 * 1.3));
      final button = tester.getRect(find.byType(TtButton));
      expect(button.height, greaterThanOrEqualTo(48));
      // The bar grew to hold the text.
      final bar = tester.getRect(find.byType(TtBottomBar));
      expect(
        bar.height,
        greaterThanOrEqualTo(
          tester.getRect(find.text(_longTitle)).height +
              tester.getRect(find.text(_longSubtitle)).height +
              24,
        ),
      );
      // Still beside the text.
      expect(
        button.left,
        greaterThanOrEqualTo(tester.getRect(find.text(_longTitle)).right),
      );
      expect(button.right, lessThanOrEqualTo(bar.right - 16));
    });

    testWidgets('a short action stays exactly 48 dp at 2x', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar(action: 'Add'), textScale: 2));
      expect(tester.getRect(find.byType(TtButton)).height, 48);
    });

    testWidgets('keeps the action tappable, and a disabled action does not '
        'fire', (tester) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_bar(onPressed: () => taps++)));
      await tester.tap(find.text('Add 3'));
      expect(taps, 1);
      await tester.pumpWidget(ttTestApp(_bar()));
      await tester.tap(find.text('Add 3'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(TtButton)).height, 48);
    });

    testWidgets('the two lines are one live region node, the action its own '
        'node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_bar(onPressed: () {})));
      final node = tester.getSemantics(find.text('3 videos picked'));
      final data = node.getSemanticsData();
      expect(
        data.label,
        '3 videos picked\n1 min 20 s · added in shooting order',
      );
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(
        tester.getSemantics(find.byType(TtButton)),
        matchesSemantics(
          label: 'Add 3',
          isButton: true,
          isEnabled: true,
          isFocusable: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('keeps clear of the system bars: the bottom inset is added '
        'under the content, the top inset is not', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 40, bottom: 24)),
              child: _bar(),
            ),
          ),
        ),
      );
      final bar = tester.getRect(find.byType(TtBottomBar));
      expect(bar.height, 12 + 48 + 12 + 24);
      final button = tester.getRect(find.byType(TtButton));
      expect(button.top - bar.top, 12);
    });

    testWidgets('takes a key', (tester) async {
      const key = ValueKey('bar');
      await tester.pumpWidget(ttTestApp(_bar(key: key)));
      expect(find.byKey(key), findsOneWidget);
      expect(tester.widget(find.byKey(key)), isA<TtBottomBar>());
    });

    testWidgets('updates its text when it changes', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      await tester.pumpWidget(
        ttTestApp(_bar(title: 'No videos picked', subtitle: 'Pick some')),
      );
      expect(find.text('3 videos picked'), findsNothing);
      expect(find.text('No videos picked'), findsOneWidget);
    });

    testWidgets('is accessible in light and dark', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(_bar(onPressed: () {}), brightness: brightness),
        );
        await expectTtAccessible(tester);
      }
    });
  });
}
