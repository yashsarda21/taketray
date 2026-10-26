import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _two = [
  TtDialogAction<String>('Cancel', 'cancel'),
  TtDialogAction<String>('Keep', 'keep'),
];

Widget _dialog({
  String title = 'Delete reel?',
  String? body = 'Its clips stay in your gallery.',
  Widget? content,
  List<TtDialogAction<String>> actions = _two,
}) => Center(
  child: TtDialog<String>(
    title: title,
    body: body,
    content: content,
    actions: actions,
  ),
);

class _Opener extends StatelessWidget {
  const new({required this.onResult});

  final ValueChanged<String?> onResult;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () async {
        final result = await showTtDialog<String>(
          context,
          title: 'Delete reel?',
          body: 'Its clips stay in your gallery.',
          actions: _two,
        );
        onResult(result);
      },
      child: const Text('open'),
    ),
  );
}

TtButton _button(WidgetTester tester, String label) =>
    tester.widget<TtButton>(find.widgetWithText(TtButton, label));

void main() {
  group('TtDialog', () {
    testWidgets('shows the title, the body and the actions', (tester) async {
      await tester.pumpWidget(ttTestApp(_dialog()));
      expect(find.text('Delete reel?'), findsOneWidget);
      expect(find.text('Its clips stay in your gallery.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
    });

    testWidgets('is 312 dp wide with 32 dp corners, in the high surface', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_dialog()));
      expect(tester.getSize(find.byType(TtDialog<String>)).width, 312);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtDialog<String>),
              matching: find.byType(Material),
            )
            .first,
      );
      final scheme = tester.element(find.byType(TtDialog<String>)).scheme;
      expect(material.color, scheme.surfaceContainerHigh);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(32));
    });

    testWidgets(
      'the title is a 22 dp heading, the body is on-surface-variant',
      (tester) async {
        await tester.pumpWidget(ttTestApp(_dialog()));
        final scheme = tester.element(find.byType(TtDialog<String>)).scheme;
        final title = tester.widget<Text>(find.text('Delete reel?')).style!;
        expect(title.fontSize, 22);
        expect(title.fontWeight, FontWeight.w800);
        expect(title.color, scheme.onSurface);
        final body = tester
            .widget<Text>(find.text('Its clips stay in your gallery.'))
            .style!;
        expect(body.color, scheme.onSurfaceVariant);
      },
    );

    testWidgets('padding is 26 / 22 / 18 with 16 under the title', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_dialog()));
      final panel = tester.getRect(find.byType(TtDialog<String>));
      final title = tester.getRect(find.text('Delete reel?'));
      expect(title.left - panel.left, 22);
      final body = tester.getRect(find.text('Its clips stay in your gallery.'));
      expect(body.left - panel.left, 22);
      final buttons = tester.getRect(find.widgetWithText(TtButton, 'Keep'));
      expect(panel.right - buttons.right, 22);
      expect(panel.bottom - buttons.bottom, 18);
    });

    testWidgets('two actions are side by side with equal widths', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_dialog()));
      final a = tester.getRect(find.widgetWithText(TtButton, 'Cancel'));
      final b = tester.getRect(find.widgetWithText(TtButton, 'Keep'));
      expect(a.width, b.width);
      expect(a.top, b.top);
      expect(b.left - a.right, 8);
      expect(a.height, 48);
    });

    testWidgets('the last action is primary, the others are tonal', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_dialog()));
      expect(_button(tester, 'Keep').kind, TtButtonKind.filled);
      expect(_button(tester, 'Cancel').kind, TtButtonKind.tonal);
    });

    testWidgets('a destructive last action uses the error colours', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _dialog(
            actions: const [
              TtDialogAction<String>('Cancel', 'cancel'),
              TtDialogAction<String>('Delete', 'delete', destructive: true),
            ],
          ),
        ),
      );
      expect(_button(tester, 'Delete').kind, TtButtonKind.danger);
      expect(_button(tester, 'Cancel').kind, TtButtonKind.tonal);
    });

    testWidgets('a single action fills the width', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _dialog(actions: const [TtDialogAction<String>('Got it', 'ok')]),
        ),
      );
      final panel = tester.getRect(find.byType(TtDialog<String>));
      final button = tester.getRect(find.widgetWithText(TtButton, 'Got it'));
      expect(button.width, panel.width - 44);
    });

    testWidgets('shows custom content under the body', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_dialog(content: const Text('Extra content'))),
      );
      expect(
        tester.getTopLeft(find.text('Extra content')).dy,
        greaterThan(
          tester.getBottomLeft(find.text('Its clips stay in your gallery.')).dy,
        ),
      );
    });

    testWidgets('stacks actions that do not fit side by side at 2x', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _dialog(
            actions: const [
              TtDialogAction<String>('Keep it', 'keep'),
              TtDialogAction<String>('Remove clip', 'remove'),
            ],
          ),
          textScale: 2,
        ),
      );
      final a = tester.getRect(find.widgetWithText(TtButton, 'Keep it'));
      final b = tester.getRect(find.widgetWithText(TtButton, 'Remove clip'));
      expect(b.top, greaterThanOrEqualTo(a.bottom));
      expect(a.left, b.left);
      expect(a.width, b.width);
      // Neither label is cut.
      for (final label in ['Keep it', 'Remove clip']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(paragraph.size.width, lessThanOrEqualTo(b.width));
      }
    });

    testWidgets('keeps short actions side by side at 1x', (tester) async {
      await tester.pumpWidget(ttTestApp(_dialog()));
      final a = tester.getRect(find.widgetWithText(TtButton, 'Cancel'));
      final b = tester.getRect(find.widgetWithText(TtButton, 'Keep'));
      expect(a.top, b.top);
    });

    testWidgets('actions are 48 dp buttons with 12 dp sides', (tester) async {
      await tester.pumpWidget(ttTestApp(_dialog()));
      for (final label in ['Cancel', 'Keep']) {
        expect(_button(tester, label).size, TtButtonSize.dialog);
      }
    });

    testWidgets('the prototype dialogs keep their actions side by side', (
      tester,
    ) async {
      // tt-style.css: .dlg .acts .btn { padding: 0 12px }: these fit their
      // half of the 268 dp row at 1x.
      for (final (first, last) in [
        ('Keep copying', 'Stop'),
        ('Not yet', 'Delete copies'),
        ('Keep it on', 'Turn off'),
      ]) {
        await tester.pumpWidget(
          ttTestApp(
            _dialog(
              actions: [
                TtDialogAction<String>(first, 'a'),
                TtDialogAction<String>(last, 'b', destructive: true),
              ],
            ),
          ),
        );
        final a = tester.getRect(find.widgetWithText(TtButton, first));
        final b = tester.getRect(find.widgetWithText(TtButton, last));
        expect(a.top, b.top, reason: '$first / $last');
        for (final label in [first, last]) {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse,
            reason: label,
          );
        }
      }
    });

    testWidgets('a stacked action too long for one line at 2x wraps whole', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _dialog(
            title: 'Mark Autumn recipes as Ready to edit?',
            actions: const [
              TtDialogAction<String>('Not now', 'no'),
              TtDialogAction<String>('Mark as Ready to edit', 'yes'),
            ],
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final a = tester.getRect(find.widgetWithText(TtButton, 'Not now'));
      final b = tester.getRect(
        find.widgetWithText(TtButton, 'Mark as Ready to edit'),
      );
      expect(b.top, greaterThanOrEqualTo(a.bottom));
      for (final label in ['Not now', 'Mark as Ready to edit']) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(label))
              .didExceedMaxLines,
          isFalse,
          reason: label,
        );
      }
    });

    testWidgets('a long title and body at 2x stay whole and scroll', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          _dialog(
            title: 'Remove all of the clips from this very long reel name?',
            body: List.filled(
              3,
              'The clips stay in your gallery and in the other reels '
              'they are in. This only changes this reel.',
            ).join(' '),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      // The actions stay on the screen.
      expect(
        tester.getRect(find.widgetWithText(TtButton, 'Keep')).bottom,
        lessThanOrEqualTo(640),
      );
    });

    testWidgets('is announced by its title', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_dialog()));
      expect(
        tester.getSemantics(find.byType(TtDialog<String>)).label,
        contains('Delete reel?'),
      );
      semantics.dispose();
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(ttTestApp(_dialog(), brightness: brightness));
        await expectTtAccessible(tester);
      }
    });
  });

  group('showTtDialog', () {
    testWidgets('returns the value of the tapped action and closes', (
      tester,
    ) async {
      String? result = 'unset';
      await tester.pumpWidget(
        ttTestApp(_Opener(onResult: (value) => result = value)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete reel?'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(result, 'keep');
      expect(find.text('Delete reel?'), findsNothing);
    });

    testWidgets('returns null when dismissed by tapping the scrim', (
      tester,
    ) async {
      String? result = 'unset';
      await tester.pumpWidget(
        ttTestApp(_Opener(onResult: (value) => result = value)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Delete reel?'), findsNothing);
    });

    testWidgets('dims and blurs the page behind it', (tester) async {
      await tester.pumpWidget(ttTestApp(_Opener(onResult: (_) {})));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsWidgets);
      final barrier = tester.widget<AnimatedModalBarrier>(
        find.byType(AnimatedModalBarrier).last,
      );
      final scrim = tester.element(find.byType(TtDialog<String>)).scheme.scrim;
      expect(barrier.color.value, scrim.withValues(alpha: 0.5));
    });

    testWidgets('keeps 24 dp from the screen edges', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ttTestApp(_Opener(onResult: (_) {})));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(TtDialog<String>));
      expect(rect.left, greaterThanOrEqualTo(24));
      expect(rect.right, lessThanOrEqualTo(320 - 24));
    });

    testWidgets('is 312 dp wide and centred on a 360 dp phone', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ttTestApp(_Opener(onResult: (_) {})));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(TtDialog<String>));
      expect(rect.left, 24);
      expect(rect.width, 312);
      expect(rect.center.dy, closeTo(320, 0.5));
    });

    testWidgets('moves above the keyboard', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1
        ..viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ttTestApp(_Opener(onResult: (_) {})));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(TtDialog<String>));
      expect(rect.bottom, lessThanOrEqualTo(640 - 300 - 24));
    });
  });
}
