import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

SemanticsData _semantics(WidgetTester tester, Type type) =>
    tester.getSemantics(find.byType(type)).getSemanticsData();

void main() {
  group('TtSwitch', () {
    testWidgets('calls onChanged with the opposite value when tapped', (
      tester,
    ) async {
      final values = <bool>[];
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtSwitch(
              value: false,
              semanticLabel: 'Keep screen on',
              onChanged: values.add,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtSwitch));
      expect(values, [true]);

      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtSwitch(
              value: true,
              semanticLabel: 'Keep screen on',
              onChanged: values.add,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtSwitch));
      expect(values, [true, false]);
    });

    testWidgets('a null onChanged is disabled and ignores taps', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtSwitch(
              value: true,
              semanticLabel: 'Keep screen on',
              onChanged: null,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtSwitch), warnIfMissed: false);
      expect(
        _semantics(tester, TtSwitch).flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('has switch semantics with the label and toggled state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      for (final value in [true, false]) {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtSwitch(
                value: value,
                semanticLabel: 'Keep screen on',
                onChanged: (_) {},
              ),
            ),
          ),
        );
        final data = _semantics(tester, TtSwitch);
        expect(data.label, 'Keep screen on');
        expect(
          data.flagsCollection.isToggled,
          value ? ui.Tristate.isTrue : ui.Tristate.isFalse,
        );
      }
      semantics.dispose();
    });

    testWidgets('has a 48 dp tap target around the 52 x 32 track', (
      tester,
    ) async {
      var changes = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtSwitch(
              value: false,
              semanticLabel: 'Keep screen on',
              onChanged: (_) => changes++,
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byType(TtSwitch));
      expect(box.height, greaterThanOrEqualTo(48));
      expect(box.width, greaterThanOrEqualTo(52));

      // A tap above the 32 dp track still lands.
      await tester.tapAt(box.topCenter + const Offset(0, 2));
      expect(changes, 1);

      final semantics = tester.ensureSemantics();
      final rect = tester.getSemantics(find.byType(TtSwitch)).rect;
      expect(rect.height, greaterThanOrEqualTo(48));
      semantics.dispose();
    });

    testWidgets('the thumb animates, and jumps under remove animations', (
      tester,
    ) async {
      Widget app({required bool value, required bool reduced}) => ttTestApp(
        Center(
          child: TtSwitch(
            value: value,
            semanticLabel: 'Keep screen on',
            onChanged: (_) {},
          ),
        ),
        disableAnimations: reduced,
      );
      Finder thumb() => find.byKey(const ValueKey('tt-switch-thumb'));

      await tester.pumpWidget(app(value: false, reduced: false));
      final before = tester.getRect(thumb());
      await tester.pumpWidget(app(value: true, reduced: false));
      await tester.pump(const Duration(milliseconds: 50));
      final mid = tester.getRect(thumb());
      await tester.pumpAndSettle();
      final after = tester.getRect(thumb());
      expect(mid.left, greaterThan(before.left));
      expect(mid.left, lessThan(after.left));
      expect(after.width, 24);

      await tester.pumpWidget(app(value: false, reduced: true));
      await tester.pumpWidget(app(value: true, reduced: true));
      // No frames pumped: the thumb is already at its final place.
      expect(tester.getRect(thumb()).left, after.left);
      expect(tester.getRect(thumb()).width, 24);
    });

    for (final brightness in Brightness.values) {
      for (final value in [false, true]) {
        testWidgets('passes the accessibility guidelines '
            '(${brightness.name}, ${value ? 'on' : 'off'})', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              Center(
                child: TtSwitch(
                  value: value,
                  semanticLabel: 'Keep screen on',
                  onChanged: (_) {},
                ),
              ),
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    }

    testWidgets('the inverted switch passes on a black card', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: TtSwitch(
                value: true,
                inverted: true,
                semanticLabel: 'Keep screen on',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await expectTtAccessible(tester);
    });
  });

  group('marks', () {
    testWidgets('TtCheckMark shows a check only when checked', (tester) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtCheckMark(checked: false))),
      );
      expect(find.byIcon(Symbols.check_rounded), findsNothing);
      expect(tester.getSize(find.byType(TtCheckMark)), const Size(18, 18));

      await tester.pumpWidget(
        ttTestApp(const Center(child: TtCheckMark(checked: true))),
      );
      expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
    });

    testWidgets('TtRadioMark is 20 x 20 and draws a dot only when selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtRadioMark(selected: false))),
      );
      expect(tester.getSize(find.byType(TtRadioMark)), const Size(20, 20));
      expect(find.byKey(const ValueKey('tt-radio-dot')), findsNothing);

      await tester.pumpWidget(
        ttTestApp(const Center(child: TtRadioMark(selected: true))),
      );
      expect(find.byKey(const ValueKey('tt-radio-dot')), findsOneWidget);
    });

    testWidgets('the marks add no semantics of their own', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TtCheckMark(checked: true),
                TtRadioMark(selected: true),
              ],
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      semantics.dispose();
    });
  });
}
