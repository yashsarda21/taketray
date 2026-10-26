import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

void main() {
  group('TtCountBadge', () {
    Future<void> pumpBadge(
      WidgetTester tester,
      int count, {
      Brightness brightness = Brightness.light,
    }) => tester.pumpWidget(
      ttTestApp(
        Center(child: TtCountBadge(count: count)),
        brightness: brightness,
      ),
    );

    testWidgets('shows the count up to 99', (tester) async {
      await pumpBadge(tester, 1);
      expect(find.text('1'), findsOneWidget);
      await pumpBadge(tester, 99);
      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('shows 99+ at 100', (tester) async {
      await pumpBadge(tester, 100);
      expect(find.text('99+'), findsOneWidget);
      await pumpBadge(tester, 1000);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('shows nothing at 0 or below', (tester) async {
      for (final count in [0, -3]) {
        await pumpBadge(tester, count);
        expect(find.byType(Text), findsNothing);
        expect(tester.getSize(find.byType(TtCountBadge)), Size.zero);
      }
    });

    testWidgets('is at least 20 x 18', (tester) async {
      await pumpBadge(tester, 1);
      final size = tester.getSize(find.byType(TtCountBadge));
      expect(size.width, greaterThanOrEqualTo(20));
      expect(size.height, greaterThanOrEqualTo(18));
    });

    testWidgets('clamps its own text scale so it stays small at 2x', (
      tester,
    ) async {
      Future<Size> sizeAt(double scale) async {
        await tester.pumpWidget(
          ttTestApp(
            const Center(child: TtCountBadge(count: 12)),
            textScale: scale,
          ),
        );
        return tester.getSize(find.byType(TtCountBadge));
      }

      final normal = await sizeAt(1);
      final clamped = await sizeAt(TtMetrics.badgeMaxTextScale);
      final doubled = await sizeAt(2);
      // Not in the prototype: decorative overlay, it must not grow over the
      // icon it decorates. 2x is the same as the clamp.
      expect(doubled, clamped);
      expect(doubled.height, lessThanOrEqualTo(normal.height * 1.3 + 1));
      expect(doubled.height, lessThan(24));
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await pumpBadge(tester, 12, brightness: brightness);
        await expectTtAccessible(tester);
      });
    }
  });
}
