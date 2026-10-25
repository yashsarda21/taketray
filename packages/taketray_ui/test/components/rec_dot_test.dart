import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_test_app.dart';

void main() {
  group('TtRecDot', () {
    testWidgets('is 10 x 10', (tester) async {
      await tester.pumpWidget(ttTestApp(const Center(child: TtRecDot())));
      expect(tester.getSize(find.byType(TtRecDot)), const Size(10, 10));
    });

    testWidgets('is 8 x 8 when compact', (tester) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtRecDot(compact: true))),
      );
      expect(tester.getSize(find.byType(TtRecDot)), const Size(8, 8));
    });

    testWidgets('an outline is drawn last, 2 dp wide, in its colour', (
      tester,
    ) async {
      const ring = Color(0xFF123456);
      for (final live in [true, false]) {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtRecDot(live: live, outline: ring),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(TtRecDot),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.boxShadow!.last.color, ring);
        expect(decoration.boxShadow!.last.spreadRadius, 2);
        // The dot is still 10 x 10; the ring is paint only.
        expect(tester.getSize(find.byType(TtRecDot)), const Size(10, 10));
      }
    });

    testWidgets('pulses while live', (tester) async {
      await tester.pumpWidget(ttTestApp(const Center(child: TtRecDot())));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('does not animate when live is false', (tester) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtRecDot(live: false))),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('has no running ticker under disableAnimations', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtRecDot()), disableAnimations: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('stops when animations are removed while it is shown', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(const Center(child: TtRecDot())));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtRecDot()), disableAnimations: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('starts when live changes from false to true', (tester) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtRecDot(live: false))),
      );
      await tester.pumpWidget(ttTestApp(const Center(child: TtRecDot())));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });
}
