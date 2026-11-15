import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/onboarding/views/step_dots.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget dots, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: TakeTrayTheme.light(),
    darkTheme: TakeTrayTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: dots),
    ),
  ),
);

/// The dots, left to right: each is a [DecoratedBox] under [StepDots].
List<({Rect rect, Color color})> _dots(WidgetTester tester) => [
  for (final element
      in find
          .descendant(
            of: find.byType(StepDots),
            matching: find.byType(DecoratedBox),
          )
          .evaluate())
    (
      rect: tester.getRect(find.byWidget(element.widget)),
      color:
          ((element.widget as DecoratedBox).decoration as BoxDecoration).color!,
    ),
];

void main() {
  testWidgets('four dots by default: the current one is a 24 x 8 pill in '
      'primary, the others 8 x 8 in outline-variant, 6 dp apart', (
    tester,
  ) async {
    for (var index = 0; index < 4; index++) {
      await _pump(tester, StepDots(index: index));
      final scheme = Theme.of(tester.element(find.byType(StepDots)))
          .colorScheme;
      final dots = _dots(tester);
      expect(dots, hasLength(4), reason: 'index $index');
      var left = 0.0;
      for (var i = 0; i < 4; i++) {
        final on = i == index;
        expect(dots[i].rect.size, Size(on ? 24 : 8, 8), reason: '$index/$i');
        expect(
          dots[i].color,
          on ? scheme.primary : scheme.outlineVariant,
          reason: '$index/$i',
        );
        expect(dots[i].rect.left, closeTo(left, 0.01), reason: '$index/$i');
        left += dots[i].rect.width + 6;
      }
      expect(
        tester.getSize(find.byType(StepDots)),
        const Size(24 + 3 * 8 + 3 * 6, 8),
        reason: 'index $index',
      );
    }
  });

  testWidgets('the dots are rounded to a pill', (tester) async {
    await _pump(tester, const StepDots(index: 0));
    for (final element
        in find
            .descendant(
              of: find.byType(StepDots),
              matching: find.byType(DecoratedBox),
            )
            .evaluate()) {
      final deco = (element.widget as DecoratedBox).decoration as BoxDecoration;
      expect(deco.borderRadius, BorderRadius.circular(4));
    }
  });

  testWidgets('follows the dark theme', (tester) async {
    await _pump(tester, const StepDots(index: 1), brightness: Brightness.dark);
    final scheme = Theme.of(tester.element(find.byType(StepDots))).colorScheme;
    final dots = _dots(tester);
    expect(dots[1].color, scheme.primary);
    expect(dots[0].color, scheme.outlineVariant);
    expect(scheme.brightness, Brightness.dark);
  });

  testWidgets('another count draws that many dots', (tester) async {
    await _pump(tester, const StepDots(index: 0, count: 3));
    expect(_dots(tester), hasLength(3));
    await _pump(tester, const StepDots(index: 0, count: 1));
    expect(_dots(tester), hasLength(1));
  });

  testWidgets('the size does not change with the text size', (tester) async {
    await _pump(tester, const StepDots(index: 0), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(StepDots)), const Size(66, 8));
  });

  group('semantics', () {
    testWidgets('one node: Step n of 4, with no child nodes', (tester) async {
      final handle = tester.ensureSemantics();
      for (var index = 0; index < 4; index++) {
        await _pump(tester, StepDots(index: index));
        final node = tester.getSemantics(find.byType(StepDots));
        expect(node.label, 'Step ${index + 1} of 4');
        var children = 0;
        node.visitChildren((_) {
          children++;
          return true;
        });
        expect(children, 0, reason: 'index $index');
      }
      handle.dispose();
    });

    testWidgets('the label follows the count', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const StepDots(index: 1, count: 3));
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the label is found by a screen reader through the whole '
        'screen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const StepDots(index: 0));
      expect(find.bySemanticsLabel('Step 1 of 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 4'), findsNothing);
      handle.dispose();
    });
  });

  group('bad input', () {
    test('an index outside the dots is refused', () {
      expect(() => StepDots(index: -1), throwsAssertionError);
      expect(() => StepDots(index: 4), throwsAssertionError);
      expect(() => StepDots(index: 3, count: 3), throwsAssertionError);
    });

    test('no dots is refused', () {
      expect(() => StepDots(index: 0, count: 0), throwsAssertionError);
    });
  });
}
