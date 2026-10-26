import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _sheet({
  String? title = 'New reel',
  bool footer = true,
  bool fullScreen = false,
  double? height,
}) => Align(
  alignment: Alignment.bottomCenter,
  child: SizedBox(
    width: 360,
    height: height,
    child: TtSheet(
      title: title,
      fullScreen: fullScreen,
      footer: footer
          ? Row(
              children: [
                Expanded(
                  child: TtButton(
                    label: 'Cancel',
                    kind: TtButtonKind.tonal,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TtButton(label: 'Create', onPressed: () {}),
                ),
              ],
            )
          : null,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text('Body of the sheet'),
      ),
    ),
  ),
);

/// A page with a button that opens a sheet and stores what it returns.
class _Opener extends StatelessWidget {
  const new({
    required this.onResult,
    this.fullScreen = false,
    this.isDismissible = true,
  });

  final ValueChanged<int?> onResult;
  final bool fullScreen;
  final bool isDismissible;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () async {
        final result = await showTtSheet<int>(
          context,
          fullScreen: fullScreen,
          isDismissible: isDismissible,
          builder: (sheetContext) => TtSheet(
            title: 'Pick one',
            fullScreen: fullScreen,
            footer: TtButton(
              label: 'Done',
              onPressed: () => Navigator.of(sheetContext).pop(7),
            ),
            child: const Text('Sheet body'),
          ),
        );
        onResult(result);
      },
      child: const Text('open'),
    ),
  );
}

/// The drawn panel of the sheet (the `TtSheet` widget also holds the space
/// around it: the inset and the keyboard).
Finder get _panel => find
    .descendant(of: find.byType(TtSheet), matching: find.byType(Material))
    .first;

Rect _panelRect(WidgetTester tester) => tester.getRect(_panel);

/// A 360 x 640 dp phone.
void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('TtSheet', () {
    testWidgets('floats inset 8 dp from the sides and bottom', (tester) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_sheet()));
      final rect = _panelRect(tester);
      final screen = tester.getRect(find.byType(Scaffold));
      expect(rect.left, 8);
      expect(rect.right, 360 - 8);
      expect(screen.bottom - rect.bottom, 8);
    });

    testWidgets('has a 32 dp radius, surfaceContainer fill and a hairline', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_sheet()));
      final material = tester.widget<Material>(_panel);
      final scheme = tester.element(find.byType(TtSheet)).scheme;
      final tt = tester.element(find.byType(TtSheet)).tt;
      expect(material.color, scheme.surfaceContainer);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(32));
      expect(shape.side.color, tt.colors.hairline);
    });

    testWidgets('draws a 32 x 4 drag handle 16 dp under the top', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_sheet()));
      final handle = find.byKey(const ValueKey('tt-sheet-handle'));
      expect(tester.getSize(handle), const Size(32, 4));
      expect(tester.getRect(handle).top - _panelRect(tester).top, 16);
    });

    testWidgets('the title is a heading in title-large, above the body', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_sheet()));
      final semantics = tester.ensureSemantics();
      final style = tester.widget<Text>(find.text('New reel')).style!;
      final scheme = tester.element(find.byType(TtSheet)).scheme;
      expect(style.fontSize, 22);
      expect(style.color, scheme.onSurface);
      expect(
        tester.getSemantics(find.text('New reel')).flagsCollection.isHeader,
        isTrue,
      );
      expect(
        tester.getTopLeft(find.text('New reel')).dy,
        lessThan(tester.getTopLeft(find.text('Body of the sheet')).dy),
      );
      expect(
        tester.getTopLeft(find.text('New reel')).dx - _panelRect(tester).left,
        24,
      );
      semantics.dispose();
    });

    testWidgets('without a title there is no heading', (tester) async {
      await tester.pumpWidget(ttTestApp(_sheet(title: null)));
      expect(find.text('New reel'), findsNothing);
      expect(find.text('Body of the sheet'), findsOneWidget);
    });

    testWidgets('the footer sits under the body, padded 12 / 16 / 16', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_sheet()));
      final panel = _panelRect(tester);
      final body = tester.getRect(find.text('Body of the sheet'));
      final create = tester.getRect(find.widgetWithText(TtButton, 'Create'));
      final cancel = tester.getRect(find.widgetWithText(TtButton, 'Cancel'));
      expect(cancel.top, greaterThan(body.bottom));
      expect(panel.right - create.right, 16);
      expect(cancel.left - panel.left, 16);
      expect(panel.bottom - create.bottom, 16);
    });

    testWidgets('full screen has no inset and no radius', (tester) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_sheet(fullScreen: true, height: 600)));
      final rect = _panelRect(tester);
      expect(rect.left, 0);
      expect(rect.right, 360);
      final shape =
          tester.widget<Material>(_panel).shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.zero);
      expect(rect.height, 600);
    });

    testWidgets('sits above the keyboard', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1
        ..viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ttTestApp(_Opener(onResult: (_) {})));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // 8 dp of inset stay between the sheet and the keyboard.
      expect(_panelRect(tester).bottom, 780 - 300 - 8);
    });

    testWidgets('the sheet of a tall form shrinks to stay above the keyboard', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1
        ..viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTtSheet<void>(
                  context,
                  builder: (_) => TtSheet(
                    title: 'Long',
                    footer: const Text('footer'),
                    child: ListView(
                      shrinkWrap: true,
                      children: [for (var i = 0; i < 60; i++) Text('row $i')],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_panelRect(tester).bottom, 640 - 300 - 8);
      expect(tester.getRect(find.text('footer')).bottom, lessThan(640 - 300));
    });

    testWidgets('a direct sheet adds the keyboard height under itself', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(viewInsets: const EdgeInsets.only(bottom: 250)),
              child: _sheet(),
            ),
          ),
        ),
      );
      final screen = tester.getRect(find.byType(Scaffold));
      expect(_panelRect(tester).bottom, screen.bottom - 250 - 8);
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(ttTestApp(_sheet(), brightness: brightness));
        await expectTtAccessible(tester);
      }
    });
  });

  group('showTtSheet', () {
    testWidgets('returns the value the sheet pops with', (tester) async {
      int? result = -1;
      await tester.pumpWidget(
        ttTestApp(_Opener(onResult: (value) => result = value)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, 7);
      expect(find.text('Sheet body'), findsNothing);
    });

    testWidgets('a tap on the scrim closes it and returns null', (
      tester,
    ) async {
      int? result = -1;
      await tester.pumpWidget(
        ttTestApp(_Opener(onResult: (value) => result = value)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Sheet body'), findsNothing);
    });

    testWidgets('a tap on the scrim does nothing when not dismissible', (
      tester,
    ) async {
      int? result = -1;
      await tester.pumpWidget(
        ttTestApp(
          _Opener(onResult: (value) => result = value, isDismissible: false),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(result, -1);
      expect(find.text('Sheet body'), findsOneWidget);
    });

    testWidgets('a drag down closes it and returns null', (tester) async {
      int? result = -1;
      await tester.pumpWidget(
        ttTestApp(_Opener(onResult: (value) => result = value)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Pick one'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Sheet body'), findsNothing);
    });

    testWidgets('a drag does not close a sheet that is not dismissible', (
      tester,
    ) async {
      int? result = -1;
      await tester.pumpWidget(
        ttTestApp(
          _Opener(onResult: (value) => result = value, isDismissible: false),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Pick one'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(result, -1);
      expect(find.text('Sheet body'), findsOneWidget);
    });

    testWidgets('a full-screen sheet can be dragged away too', (tester) async {
      int? result = -1;
      await tester.pumpWidget(
        ttTestApp(
          _Opener(onResult: (value) => result = value, fullScreen: true),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Pick one'), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('blurs and dims the page behind it', (tester) async {
      await tester.pumpWidget(ttTestApp(_Opener(onResult: (_) {})));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsWidgets);
      final barrier = tester.widget<AnimatedModalBarrier>(
        find.byType(AnimatedModalBarrier).last,
      );
      final scrim = tester.element(find.byType(TtSheet)).scheme.scrim;
      expect(barrier.color.value, scrim.withValues(alpha: 0.5));
    });

    testWidgets('a full-screen sheet fills the screen', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_Opener(onResult: (_) {}, fullScreen: true)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final rect = _panelRect(tester);
      expect(rect.left, 0);
      expect(rect.width, 800);
      expect(rect.top, 0);
    });

    testWidgets('a floating sheet is at most 92 % of the screen high', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTtSheet<void>(
                  context,
                  builder: (_) => TtSheet(
                    title: 'Long',
                    child: ListView(
                      shrinkWrap: true,
                      children: [for (var i = 0; i < 60; i++) Text('row $i')],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(TtSheet)).height,
        lessThanOrEqualTo(600 * 0.92),
      );
    });
  });
}
