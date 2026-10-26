import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _bar({double? value, String? label, String? semanticLabel}) => Padding(
  padding: const EdgeInsets.all(16),
  child: TtProgressBar(
    value: value,
    label: label,
    semanticLabel: semanticLabel,
  ),
);

void main() {
  group('TtProgressBar', () {
    testWidgets('is a 4 dp track in secondary-container with a primary fill', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_bar(value: 0.4)));
      await tester.pumpAndSettle();
      final scheme = tester.element(find.byType(TtProgressBar)).scheme;
      final track = tester.getRect(
        find.byKey(const ValueKey('tt-progress-track')),
      );
      expect(track.height, 4);
      final trackBox = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('tt-progress-track')),
      );
      expect(
        (trackBox.decoration as BoxDecoration).color,
        scheme.secondaryContainer,
      );
      final fill = tester.getRect(
        find.byKey(const ValueKey('tt-progress-fill')),
      );
      expect(fill.width, closeTo(track.width * 0.4, 0.01));
      expect(fill.height, 4);
      final fillBox = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('tt-progress-fill')),
      );
      expect((fillBox.decoration as BoxDecoration).color, scheme.primary);
    });

    testWidgets('0 % has no fill and 100 % fills the track', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar(value: 0)));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-progress-fill'))).width,
        0,
      );
      await tester.pumpWidget(ttTestApp(_bar(value: 1)));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-progress-fill'))).width,
        tester.getSize(find.byKey(const ValueKey('tt-progress-track'))).width,
      );
    });

    testWidgets('a value outside 0 to 1 is clamped', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar(value: 1.7)));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-progress-fill'))).width,
        tester.getSize(find.byKey(const ValueKey('tt-progress-track'))).width,
      );
    });

    testWidgets('the fill grows over 0.3 s and jumps when animations are '
        'removed', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar(value: 0.2)));
      await tester.pumpAndSettle();
      final track = tester
          .getSize(find.byKey(const ValueKey('tt-progress-track')))
          .width;
      await tester.pumpWidget(ttTestApp(_bar(value: 0.8)));
      await tester.pump(const Duration(milliseconds: 150));
      final mid = tester
          .getSize(find.byKey(const ValueKey('tt-progress-fill')))
          .width;
      expect(mid, greaterThan(track * 0.2));
      expect(mid, lessThan(track * 0.8));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ttTestApp(_bar(value: 0.2), disableAnimations: true),
      );
      await tester.pumpWidget(
        ttTestApp(_bar(value: 0.8), disableAnimations: true),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-progress-fill'))).width,
        closeTo(track * 0.8, 0.01),
      );
    });

    testWidgets('TtProgressBar(value: 0.4) exposes value 40 % in semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_bar(value: 0.4, semanticLabel: 'Copying')),
      );
      await tester.pumpAndSettle();
      final data = tester
          .getSemantics(find.byType(TtProgressBar))
          .getSemanticsData();
      expect(data.value, '40%');
      expect(data.label, 'Copying');
      handle.dispose();
    });

    testWidgets('the semantics label defaults to the visible label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_bar(value: 0.5, label: '7 of 12 clips')),
      );
      await tester.pumpAndSettle();
      final data = tester
          .getSemantics(find.byType(TtProgressBar))
          .getSemanticsData();
      expect(data.label, '7 of 12 clips');
      expect(data.value, '50%');
      handle.dispose();
    });

    testWidgets('an indeterminate bar has no value in semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_bar(semanticLabel: 'Loading')));
      await tester.pump();
      final data = tester
          .getSemantics(find.byType(TtProgressBar))
          .getSemanticsData();
      expect(data.value, isEmpty);
      expect(data.label, 'Loading');
      handle.dispose();
    });

    testWidgets('the label is shown above the bar', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_bar(value: 0.5, label: '7 of 12 clips')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('7 of 12 clips')).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('tt-progress-track'))).top,
        ),
      );
    });

    testWidgets('an indeterminate bar moves, and stands still when animations '
        'are removed', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      await tester.pump();
      final first = tester.getRect(
        find.byKey(const ValueKey('tt-progress-fill')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final second = tester.getRect(
        find.byKey(const ValueKey('tt-progress-fill')),
      );
      expect(second, isNot(first));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(ttTestApp(_bar(), disableAnimations: true));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      final still = tester.getRect(
        find.byKey(const ValueKey('tt-progress-fill')),
      );
      final track = tester.getRect(
        find.byKey(const ValueKey('tt-progress-track')),
      );
      expect(still.width, closeTo(track.width * 0.4, 0.01));
      expect(still.center.dx, closeTo(track.center.dx, 0.01));
    });

    testWidgets('the indeterminate bar stays inside the track', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      final track = tester.getRect(
        find.byKey(const ValueKey('tt-progress-track')),
      );
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final fill = tester.getRect(
          find.byKey(const ValueKey('tt-progress-fill')),
        );
        expect(fill.left, greaterThanOrEqualTo(track.left - 0.01));
        expect(fill.right, lessThanOrEqualTo(track.right + 0.01));
      }
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(
            brightness: brightness,
            _bar(value: 0.4, label: '7 of 12 clips'),
          ),
        );
        await tester.pumpAndSettle();
        await expectTtAccessible(tester);
      }
    });
  });
}
