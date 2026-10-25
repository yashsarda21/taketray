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
