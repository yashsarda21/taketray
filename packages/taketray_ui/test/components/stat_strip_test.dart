import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _strip({
  bool muted = false,
  bool live = true,
  bool withAction = true,
  String text = 'Shooting since 9:41 AM',
  VoidCallback? onPressed,
}) => Center(
  child: SizedBox(
    width: 360,
    child: TtStatStrip(
      leading: live
          ? const TtRecDot(compact: true)
          : const Icon(Symbols.videocam_off_rounded),
      text: text,
      muted: muted,
      action: withAction
          ? TtButton(
              label: live ? 'Open camera' : 'Turn on',
              icon: live ? Symbols.videocam_rounded : null,
              kind: TtButtonKind.text,
              onPressed: onPressed ?? () {},
            )
          : null,
    ),
  ),
);

void main() {
  group('TtStatStrip', () {
    testWidgets('is at least 48 dp high and shows the leading, text, action', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_strip()));
      expect(tester.getSize(find.byType(TtStatStrip)).height, 48);
      expect(find.byType(TtRecDot), findsOneWidget);
      expect(find.text('Shooting since 9:41 AM'), findsOneWidget);
      expect(find.text('Open camera'), findsOneWidget);
    });

    testWidgets('the record dot is 8 dp when compact', (tester) async {
      await tester.pumpWidget(ttTestApp(_strip()));
      expect(tester.getSize(find.byType(TtRecDot)), const Size(8, 8));
    });

    testWidgets('the text uses label-large in on-surface, or the variant '
        'when muted', (tester) async {
      await tester.pumpWidget(ttTestApp(_strip(live: false)));
      final scheme = tester.element(find.byType(TtStatStrip)).scheme;
      final style = tester
          .widget<Text>(find.text('Shooting since 9:41 AM'))
          .style!;
      expect(style.color, scheme.onSurface);
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w600);
      await tester.pumpWidget(ttTestApp(_strip(live: false, muted: true)));
      expect(
        tester.widget<Text>(find.text('Shooting since 9:41 AM')).style!.color,
        scheme.onSurfaceVariant,
      );
      // The icon follows: 18 dp in the muted colour.
      final icon = tester.widget<Icon>(
        find.byIcon(Symbols.videocam_off_rounded),
      );
      expect(
        icon.color ??
            IconTheme.of(
              tester.element(find.byIcon(Symbols.videocam_off_rounded)),
            ).color,
        scheme.onSurfaceVariant,
      );
    });

    testWidgets('the leading icon is 18 dp', (tester) async {
      await tester.pumpWidget(ttTestApp(_strip(live: false)));
      expect(
        tester.getSize(find.byIcon(Symbols.videocam_off_rounded)),
        const Size.square(18),
      );
    });

    testWidgets('works without an action', (tester) async {
      await tester.pumpWidget(ttTestApp(_strip(withAction: false)));
      expect(find.byType(TtButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the action is tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_strip(onPressed: () => taps++)));
      await tester.tap(find.text('Open camera'));
      expect(taps, 1);
    });

    testWidgets('stat strip action keeps its label and the text wraps at 2x', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_strip(), textScale: 2, disableAnimations: true),
      );
      await tester.pumpAndSettle();
      final text = tester.renderObject<RenderParagraph>(
        find.text('Shooting since 9:41 AM'),
      );
      final label = tester.renderObject<RenderParagraph>(
        find.text('Open camera'),
      );
      // Neither is cut short, and the text takes at most two lines.
      expect(text.didExceedMaxLines, isFalse);
      expect(label.didExceedMaxLines, isFalse);
      expect(
        tester.getSize(find.text('Shooting since 9:41 AM')).height,
        lessThanOrEqualTo(2 * 40),
      );
      // The action sits under the text instead of squeezing it.
      final strip = tester.getRect(find.byType(TtStatStrip));
      expect(
        tester.getRect(find.byType(TtButton)).top,
        greaterThanOrEqualTo(
          tester.getRect(find.text('Shooting since 9:41 AM')).bottom,
        ),
      );
      expect(
        tester.getRect(find.byType(TtButton)).right,
        lessThanOrEqualTo(strip.right),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 1.3x on 360 dp the action stays beside the text and '
        'nothing is cut', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_strip(), textScale: 1.3, disableAnimations: true),
      );
      await tester.pumpAndSettle();
      final text = tester.renderObject<RenderParagraph>(
        find.text('Shooting since 9:41 AM'),
      );
      final label = tester.renderObject<RenderParagraph>(
        find.text('Open camera'),
      );
      expect(text.didExceedMaxLines, isFalse);
      expect(label.didExceedMaxLines, isFalse);
      expect(
        tester.getRect(find.byType(TtButton)).left,
        greaterThanOrEqualTo(
          tester.getRect(find.text('Shooting since 9:41 AM')).right,
        ),
      );
      expect(
        tester.getRect(find.byType(TtButton)).right,
        lessThanOrEqualTo(tester.getRect(find.byType(TtStatStrip)).right),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the action stays beside the text at 1x', (tester) async {
      await tester.pumpWidget(ttTestApp(_strip()));
      expect(
        tester.getRect(find.byType(TtButton)).left,
        greaterThanOrEqualTo(
          tester.getRect(find.text('Shooting since 9:41 AM')).right,
        ),
      );
      expect(tester.getSize(find.byType(TtStatStrip)).height, 48);
    });

    testWidgets('long text at 2x does not overflow', (tester) async {
      for (final live in [true, false]) {
        await tester.pumpWidget(
          ttTestApp(
            _strip(
              live: live,
              text:
                  'Shooting since 9:41 AM, with a much longer description '
                  'than there is room for',
            ),
            textScale: 2,
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the live dot is hidden from semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_strip()));
      expect(find.bySemanticsLabel('Shooting since 9:41 AM'), findsOneWidget);
      handle.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(_strip(muted: true, live: false), brightness: brightness),
        );
        await expectTtAccessible(tester);
        await tester.pumpWidget(
          ttTestApp(_strip(), brightness: brightness, disableAnimations: true),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
