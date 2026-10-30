import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_test_app.dart';

/// The drawn bar (the widget itself spans the row and aligns the bar).
Size _bar(WidgetTester tester) => tester.getSize(
  find.descendant(
    of: find.byType(TtSkeletonLine),
    matching: find.byType(DecoratedBox),
  ),
);

void main() {
  group('TtSkeletonLine', () {
    testWidgets('is 12 dp high and 40 % of the width by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(child: SizedBox(width: 300, child: TtSkeletonLine())),
        ),
      );
      expect(_bar(tester), const Size(120, 12));
    });

    testWidgets('takes its width from widthFactor', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            child: SizedBox(
              width: 200,
              child: TtSkeletonLine(widthFactor: 0.75),
            ),
          ),
        ),
      );
      expect(_bar(tester).width, 150);
    });

    testWidgets('is hidden from a screen reader and does not animate', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(const TtSkeletonLine()));
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        find.descendant(
          of: find.byType(TtSkeletonLine),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      semantics.dispose();
    });
  });

  group('TtClipTileSkeleton', () {
    Widget tile({bool disableAnimations = false}) => ttTestApp(
      const Center(child: SizedBox(width: 108, child: TtClipTileSkeleton())),
      disableAnimations: disableAnimations,
    );

    testWidgets('is a 3:4 tile', (tester) async {
      await tester.pumpWidget(tile());
      expect(
        tester.getSize(find.byType(TtClipTileSkeleton)),
        const Size(108, 144),
      );
    });

    testWidgets('shimmers while animations are on', (tester) async {
      await tester.pumpWidget(tile());
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('does not shimmer under disableAnimations', (tester) async {
      await tester.pumpWidget(tile(disableAnimations: true));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('stops when animations are removed while it is shown', (
      tester,
    ) async {
      await tester.pumpWidget(tile());
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(tile(disableAnimations: true));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('is hidden from a screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(tile());
      expect(
        find.descendant(
          of: find.byType(TtClipTileSkeleton),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      semantics.dispose();
    });
  });

  group('TtSkeletonCount', () {
    testWidgets('is a 48 x 16 dp bar with 8 dp corners, hidden from readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(const Align(child: TtSkeletonCount())));

      expect(tester.getSize(find.byType(TtSkeletonCount)), const Size(48, 16));
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(TtSkeletonCount),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      final scheme = tester.element(find.byType(TtSkeletonCount)).scheme;
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(decoration.color, scheme.surfaceContainerHighest);
      expect(
        find.descendant(
          of: find.byType(TtSkeletonCount),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(tester.getSemantics(find.byType(TtSkeletonCount)).label, '');
      semantics.dispose();
    });
  });
}
