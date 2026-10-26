import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _snack({
  String message = 'Clip deleted',
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
}) => Align(
  alignment: Alignment.bottomCenter,
  child: SizedBox(
    width: 328,
    child: TtSnack(
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  ),
);

class _Opener extends StatelessWidget {
  const new({this.onAction, this.duration});

  final VoidCallback? onAction;
  final Duration? duration;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => showTtSnack(
            context,
            message: 'First message',
            actionLabel: 'Undo',
            onAction: onAction,
            duration: duration,
          ),
          child: const Text('one'),
        ),
        TextButton(
          onPressed: () => showTtSnack(
            context,
            message: 'Second message',
            icon: Symbols.check_circle_rounded,
          ),
          child: const Text('two'),
        ),
      ],
    ),
  );
}

void main() {
  group('TtSnack', () {
    testWidgets('shows the message', (tester) async {
      await tester.pumpWidget(ttTestApp(_snack()));
      expect(find.text('Clip deleted'), findsOneWidget);
      expect(find.byType(TtButton), findsNothing);
    });

    testWidgets('is at least 48 dp high with 18 dp corners', (tester) async {
      await tester.pumpWidget(ttTestApp(_snack()));
      expect(tester.getSize(find.byType(TtSnack)).height, 48);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(TtSnack),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(18));
      final scheme = tester.element(find.byType(TtSnack)).scheme;
      expect(decoration.color, scheme.inverseSurface.withValues(alpha: 0.94));
    });

    testWidgets('the message is body-medium on inverse-on-surface', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_snack()));
      final style = tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.text('Clip deleted'),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style;
      final scheme = tester.element(find.byType(TtSnack)).scheme;
      expect(style.color, scheme.onInverseSurface);
      expect(style.fontSize, 14);
    });

    testWidgets('shows a 20 dp icon in inverse-primary', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_snack(icon: Symbols.check_circle_rounded)),
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Symbols.check_circle_rounded),
      );
      final scheme = tester.element(find.byType(TtSnack)).scheme;
      expect(icon.size, 20);
      expect(icon.color, scheme.inversePrimary);
    });

    testWidgets('the action calls onAction and is in the inverse accent', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        ttTestApp(_snack(actionLabel: 'Undo', onAction: () => calls++)),
      );
      await tester.tap(find.text('Undo'));
      expect(calls, 1);
      final scheme = tester.element(find.byType(TtSnack)).scheme;
      final primary = Theme.of(tester.element(find.text('Undo')))
          .colorScheme
          .primary;
      // Nudged from inverse-primary towards on-inverse-surface for contrast.
      expect(primary, isNot(scheme.inversePrimary));
      expect(
        primary,
        Color.lerp(scheme.inversePrimary, scheme.onInverseSurface, 0.15),
      );
      expect(
        tester.getSize(find.widgetWithText(TtButton, 'Undo')).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('a long message at 2x wraps and keeps the action whole', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          _snack(
            message:
                'Removed 3 clips from "Autumn recipes and other long names"',
            actionLabel: 'Undo',
            onAction: () {},
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Undo'), findsOneWidget);
      final undo = tester.getRect(find.widgetWithText(TtButton, 'Undo'));
      expect(undo.right, lessThanOrEqualTo(360));
      expect(undo.width, greaterThan(60));
    });

    testWidgets('is a live region', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_snack()));
      expect(
        tester
            .getSemantics(find.text('Clip deleted'))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(
            _snack(actionLabel: 'Undo', onAction: () {}),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      }
    });
  });

  group('showTtSnack', () {
    testWidgets('shows a floating snack with the message', (tester) async {
      await tester.pumpWidget(ttTestApp(const _Opener()));
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      expect(find.byType(TtSnack), findsOneWidget);
      expect(find.text('First message'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(
        bar.behavior ?? SnackBarBehavior.floating,
        SnackBarBehavior.floating,
      );
    });

    testWidgets('a second snack replaces the first', (tester) async {
      await tester.pumpWidget(ttTestApp(const _Opener()));
      await tester.tap(find.text('one'));
      await tester.pump();
      await tester.tap(find.text('two'));
      await tester.pumpAndSettle();
      expect(find.text('First message'), findsNothing);
      expect(find.text('Second message'), findsOneWidget);
      expect(find.byType(TtSnack), findsOneWidget);
    });

    testWidgets('Undo calls onAction exactly once and closes the snack', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(ttTestApp(_Opener(onAction: () => calls++)));
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(TtSnack), findsNothing);
    });

    testWidgets('a second tap on Undo while it closes does nothing', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(ttTestApp(_Opener(onAction: () => calls++)));
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('closes with the action reason when Undo is tapped', (
      tester,
    ) async {
      late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => controller = showTtSnack(
                context,
                message: 'Clip deleted',
                actionLabel: 'Undo',
                onAction: () {},
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await controller.closed, SnackBarClosedReason.action);
    });

    testWidgets('floats 16 dp from the sides and 12 dp from the bottom', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ttTestApp(const _Opener()));
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(TtSnack));
      expect(rect.left, 16);
      expect(rect.right, 360 - 16);
      expect(rect.bottom, 640 - 12);
      // proto.css: .snack padding 6 around a 44 dp text button: 56 dp.
      expect(rect.height, 56);
    });

    testWidgets('an Undo snack stays while a screen reader is on', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(ttTestApp(_Opener(onAction: () {})));
      // Settle the entry animation, then wait well past the timeout.
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('First message'), findsOneWidget);
      // A snack without an action still times out.
      await tester.tap(find.text('two'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(TtSnack), findsNothing);
    });

    testWidgets('lasts 4 s, or 6 s with Undo (proto app.js snack())', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_Opener(onAction: () {})));
      // A snack without an action: gone after 4 s.
      await tester.tap(find.text('two'));
      await tester.pumpAndSettle();
      // Settle after each wait: a timer that fired has started the exit
      // animation, which a single pump would still show. The timer starts
      // when the entry animation ends, about 0.4 s before the first settle
      // returns, so the waits below leave that much margin.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Second message'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(TtSnack), findsNothing);

      // A snack with Undo: still there at 5 s, gone after 6 s.
      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('First message'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.byType(TtSnack), findsNothing);
    });

    testWidgets('goes away by itself after the duration', (tester) async {
      await tester.pumpWidget(
        ttTestApp(const _Opener(duration: Duration(seconds: 2))),
      );
      await tester.tap(find.text('one'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TtSnack), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(TtSnack), findsNothing);
    });

    testWidgets('returns the controller of the snack bar', (tester) async {
      late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  controller = showTtSnack(context, message: 'Hello'),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      controller.close();
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
    });
  });
}
