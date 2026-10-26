import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

SemanticsData _semantics(WidgetTester tester) =>
    tester.getSemantics(find.byType(TtStatusPill)).getSemanticsData();

Widget _pill(
  TtStatusKind kind, {
  String label = 'Ready to edit',
  bool onMedia = false,
  bool large = false,
  VoidCallback? onPressed,
  String? semanticLabel,
}) {
  final pill = TtStatusPill(
    kind: kind,
    label: label,
    onMedia: onMedia,
    large: large,
    onPressed: onPressed,
    semanticLabel: semanticLabel,
  );
  return Center(
    child: onMedia
        ? ColoredBox(color: const Color(0xFF332244), child: pill)
        : pill,
  );
}

Color _iconColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon).first).color!;

void main() {
  group('TtStatusPill', () {
    testWidgets('shows the label and the icon of each kind', (tester) async {
      const icons = {
        TtStatusKind.collecting: Symbols.radio_button_checked_rounded,
        TtStatusKind.ready: Symbols.content_cut_rounded,
        TtStatusKind.published: Symbols.check_circle_rounded,
      };
      for (final MapEntry(:key, :value) in icons.entries) {
        await tester.pumpWidget(ttTestApp(_pill(key, label: 'Label')));
        expect(find.text('Label'), findsOneWidget);
        expect(find.byIcon(value), findsOneWidget);
        // Filled glyphs.
        expect(tester.widget<Icon>(find.byIcon(value)).fill, 1);
      }
    });

    testWidgets('is 24 dp high, and 32 dp when large', (tester) async {
      await tester.pumpWidget(ttTestApp(_pill(TtStatusKind.ready)));
      expect(tester.getSize(find.byType(TtStatusPill)).height, 24);
      await tester.pumpWidget(
        ttTestApp(_pill(TtStatusKind.ready, large: true)),
      );
      expect(tester.getSize(find.byType(TtStatusPill)).height, 32);
    });

    testWidgets('the caret shows only when it can be pressed', (tester) async {
      await tester.pumpWidget(ttTestApp(_pill(TtStatusKind.ready)));
      expect(find.byIcon(Symbols.arrow_drop_down_rounded), findsNothing);
      await tester.pumpWidget(
        ttTestApp(_pill(TtStatusKind.ready, onPressed: () {})),
      );
      expect(find.byIcon(Symbols.arrow_drop_down_rounded), findsOneWidget);
    });

    testWidgets('uses the status colours on a surface', (tester) async {
      await tester.pumpWidget(ttTestApp(_pill(TtStatusKind.collecting)));
      final tt = tester.element(find.byType(TtStatusPill)).tt;
      expect(_iconColor(tester), tt.colors.record);
      await tester.pumpWidget(ttTestApp(_pill(TtStatusKind.published)));
      expect(_iconColor(tester), tt.colors.onSuccessContainer);
    });

    testWidgets('on media it is dark glass with the on-media icon colour', (
      tester,
    ) async {
      final colours = <TtStatusKind, Color Function(TtThemeData)>{
        TtStatusKind.collecting: (tt) => tt.colors.recordOnMedia,
        TtStatusKind.ready: (tt) => tt.colors.readyOnMedia,
        TtStatusKind.published: (tt) => tt.colors.publishedOnMedia,
      };
      for (final MapEntry(:key, :value) in colours.entries) {
        await tester.pumpWidget(ttTestApp(_pill(key, onMedia: true)));
        final tt = tester.element(find.byType(TtStatusPill)).tt;
        expect(_iconColor(tester), value(tt));
        expect(
          find.descendant(
            of: find.byType(TtStatusPill),
            matching: find.byType(BackdropFilter),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.byType(Text)).style!.color,
          tt.colors.onMedia,
        );
      }
      await tester.pumpWidget(ttTestApp(_pill(TtStatusKind.ready)));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('onPressed is called on tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(_pill(TtStatusKind.ready, onPressed: () => taps++)),
      );
      await tester.tap(find.byType(TtStatusPill));
      expect(taps, 1);
    });

    testWidgets('has a 48 dp tap target when pressable', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_pill(TtStatusKind.ready, onPressed: () {})),
      );
      expect(tester.getSize(find.byType(TtStatusPill)).height, 48);
    });

    testWidgets('is a button with the semantic label when pressable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          _pill(
            TtStatusKind.ready,
            onPressed: () {},
            semanticLabel: 'Status: Ready to edit. Change status',
          ),
        ),
      );
      final data = _semantics(tester);
      expect(data.label, 'Status: Ready to edit. Change status');
      expect(data.flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('says its label and is no button when it cannot be pressed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_pill(TtStatusKind.ready)));
      final data = _semantics(tester);
      expect(data.label, 'Ready to edit');
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
      semantics.dispose();
    });

    testWidgets('a long label ends in an ellipsis at 2x text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 140,
              child: TtStatusPill(
                kind: TtStatusKind.ready,
                label: 'A very long status label that cannot fit',
                onPressed: () {},
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TtStatusPill)).width,
        lessThanOrEqualTo(140),
      );
    });

    for (final brightness in Brightness.values) {
      for (final onMedia in [false, true]) {
        testWidgets('passes the accessibility guidelines '
            '(${brightness.name}, ${onMedia ? 'on media' : 'on a surface'})', (
          tester,
        ) async {
          for (final kind in TtStatusKind.values) {
            await tester.pumpWidget(
              ttTestApp(
                _pill(
                  kind,
                  onMedia: onMedia,
                  large: true,
                  onPressed: () {},
                  semanticLabel: 'Status. Change status',
                ),
                brightness: brightness,
              ),
            );
            await expectTtAccessible(tester);
          }
        });
      }
    }
  });
}
