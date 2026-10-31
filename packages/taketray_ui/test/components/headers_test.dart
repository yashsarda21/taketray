import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

void main() {
  group('TtSceneHeader', () {
    Widget header({
      String title = '9:41 – 10:05 AM',
      VoidCallback? onTag,
      Brightness brightness = Brightness.light,
    }) => ttTestApp(
      TtSceneHeader(
        title: title,
        subtitle: '8 clips · 2:14',
        action: TtButton(
          label: 'Tag scene',
          icon: Symbols.sell_rounded,
          kind: TtButtonKind.tonal,
          size: TtButtonSize.small,
          semanticLabel: 'Tag scene 9:41 – 10:05 AM, 8 clips',
          onPressed: onTag,
        ),
      ),
      brightness: brightness,
    );

    testWidgets('shows the title, the subtitle and the action', (tester) async {
      await tester.pumpWidget(header(onTag: () {}));
      expect(find.text('9:41 – 10:05 AM'), findsOneWidget);
      expect(find.text('8 clips · 2:14'), findsOneWidget);
      expect(find.text('Tag scene'), findsOneWidget);
    });

    testWidgets('the action can be tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(header(onTag: () => taps++));
      await tester.tap(find.text('Tag scene'));
      expect(taps, 1);
    });

    group('selection variant', () {
      Widget selecting({
        required String label,
        VoidCallback? onPressed,
        double textScale = 1,
        Brightness brightness = Brightness.light,
      }) => ttTestApp(
        TtSceneHeader(
          title: '9:41 – 10:05 AM',
          subtitle: '8 clips · 2:14',
          action: TtButton(
            label: label,
            kind: TtButtonKind.text,
            size: TtButtonSize.small,
            onPressed: onPressed,
          ),
        ),
        textScale: textScale,
        brightness: brightness,
      );

      for (final label in ['Select all', 'Unselect']) {
        testWidgets('shows a text "$label" button at the end of the row and '
            'taps it', (tester) async {
          var taps = 0;
          await tester.pumpWidget(
            selecting(label: label, onPressed: () => taps++),
          );
          expect(find.text(label), findsOneWidget);
          expect(find.text('Tag scene'), findsNothing);
          final header = tester.getRect(find.byType(TtSceneHeader));
          final button = tester.getRect(find.byType(TextButton));
          expect(button.right, lessThanOrEqualTo(header.right - 16));
          expect(
            button.left,
            greaterThan(tester.getRect(find.text('8 clips · 2:14')).left),
          );
          expect(button.height, greaterThanOrEqualTo(36));
          await tester.tap(find.text(label));
          expect(taps, 1);
        });
      }

      testWidgets('at 2x the title and the button both fit', (tester) async {
        await tester.pumpWidget(
          selecting(label: 'Select all', onPressed: () {}, textScale: 2),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Select all'), findsOneWidget);
        expect(find.text('9:41 – 10:05 AM'), findsOneWidget);
      });

      for (final brightness in Brightness.values) {
        testWidgets('passes the accessibility guidelines '
            '(${brightness.name})', (tester) async {
          await tester.pumpWidget(
            selecting(
              label: 'Unselect',
              onPressed: () {},
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    });

    testWidgets('is at least 48 dp high with 16 dp gutters', (tester) async {
      await tester.pumpWidget(header(onTag: () {}));
      final box = tester.getRect(find.byType(TtSceneHeader));
      expect(box.height, greaterThanOrEqualTo(48));
      expect(tester.getTopLeft(find.text('9:41 – 10:05 AM')).dx, 16);
    });

    testWidgets('a long title clamps at 2x text and does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          TtSceneHeader(
            title:
                'A scene title that is much too long to fit on one line '
                'of a phone at twice the text size',
            subtitle: '1,204 clips · 12:30:45 in total over the whole day',
            action: TtButton(
              label: 'Tag scene',
              kind: TtButtonKind.tonal,
              size: TtButtonSize.small,
              onPressed: () {},
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(header(onTag: () {}, brightness: brightness));
        await expectTtAccessible(tester);
      });
    }
  });

  group('TtDayHeader', () {
    testWidgets('shows the title and the trailing text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const TtDayHeader(title: 'Day 1 · Fri 12 Jun', trailing: '14 clips'),
        ),
      );
      expect(find.text('Day 1 · Fri 12 Jun'), findsOneWidget);
      expect(find.text('14 clips'), findsOneWidget);
    });

    testWidgets('works without trailing text', (tester) async {
      await tester.pumpWidget(ttTestApp(const TtDayHeader(title: 'Today')));
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('is announced as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(const TtDayHeader(title: 'Today', trailing: '3 clips')),
      );
      final data = tester
          .getSemantics(
            find.descendant(
              of: find.byType(TtDayHeader),
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.header == true,
              ),
            ),
          )
          .getSemanticsData();
      expect(data.flagsCollection.isHeader, isTrue);
      expect(data.label, contains('Today'));
      expect(data.label, contains('3 clips'));
      semantics.dispose();
    });

    testWidgets('a long title wraps and clamps at 2x text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const TtDayHeader(
            title: 'Day 12 · Wednesday 12 November 2025 in a long place name',
            trailing: '1,204 clips',
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            const TtDayHeader(title: 'Today', trailing: '3 clips'),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
