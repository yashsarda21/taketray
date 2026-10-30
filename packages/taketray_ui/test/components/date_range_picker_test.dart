import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

// Today is Wednesday 28 Oct 2026; the picker reaches ten years back.
final DateTime _today = DateTime(2026, 10, 28);
final DateTime _first = DateTime(2016, 10, 28);

DateTime _d(int y, int m, int d) => DateTime(y, m, d);
Finder _cell(DateTime d) => find.byKey(ValueKey<DateTime>(d));

/// What the last picker returned, and whether it has returned yet.
class _Result {
  bool done = false;
  DateTimeRange? range;

  void finish(DateTimeRange? value) {
    range = value;
    done = true;
  }
}

final Finder _find = find.widgetWithText(FilledButton, 'Find videos');

bool _findEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_find).onPressed != null;

/// A page with a button that opens the picker, as the sheet does.
Future<_Result> _open(
  WidgetTester tester, {
  DateTimeRange? initial,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool disableAnimations = true,
  Locale? locale,
  FocusNode? opener,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final result = _Result();
  await tester.pumpWidget(
    ttTestApp(
      Builder(
        builder: (context) => Focus(
          focusNode: opener,
          child: TextButton(
            onPressed: () async {
              result.finish(
                await showTtDateRangePicker(
                  context,
                  firstDate: _first,
                  lastDate: _today,
                  currentDate: _today,
                  initialDateRange: initial,
                  labels: TtDateRangePickerLabels.english,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
      textScale: textScale,
      brightness: brightness,
      disableAnimations: disableAnimations,
      locale: locale,
    ),
  );
  opener?.requestFocus();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Future<void> _tapDay(WidgetTester tester, DateTime d) async {
  await tester.tap(_cell(d));
  await tester.pumpAndSettle();
}

ColorScheme _scheme(WidgetTester tester) =>
    tester.element(find.byType(TtDateRangePickerPage)).scheme;

void main() {
  group('the page', () {
    testWidgets('has a Close button, the title and the Find videos button', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Choose dates'), findsOneWidget);
      expect(find.byIcon(Symbols.close_rounded), findsOneWidget);
      expect(_find, findsOneWidget);
      // On the surface, full screen.
      final page = tester.getRect(find.byType(TtDateRangePickerPage));
      expect(page, const Rect.fromLTWH(0, 0, 360, 800));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtDateRangePickerPage),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, _scheme(tester).surface);
    });

    testWidgets('Find videos is off until a day is chosen', (tester) async {
      await _open(tester);

      expect(_findEnabled(tester), isFalse);
      await _tapDay(tester, _d(2026, 10, 8));
      expect(_findEnabled(tester), isTrue);
    });

    testWidgets('Find videos is a large button, 56 dp, in a fixed bottom bar', (
      tester,
    ) async {
      await _open(tester);

      final button = tester.getRect(_find);
      expect(button.height, 56);
      // 16 dp sides, 16 dp under it (12 dp above, with the hairline).
      expect(button.left, 16);
      expect(button.right, 360 - 16);
      expect(800 - button.bottom, 16);
      // It does not move when the calendar scrolls.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );
      await tester.pump();
      expect(tester.getRect(_find), button);
    });

    testWidgets('a hairline of onSurface at 9 % sits above the bar', (
      tester,
    ) async {
      await _open(tester);

      final bar = tester.widget<DecoratedBox>(
        find.ancestor(of: _find, matching: find.byType(DecoratedBox)).first,
      );
      final decoration = bar.decoration as BoxDecoration;
      expect(
        (decoration.border! as Border).top.color,
        _scheme(tester).onSurface.withValues(alpha: TtMetrics.hairlineOpacity),
      );
      expect(decoration.color, _scheme(tester).surface);
    });

    testWidgets('Clear shows only while days are chosen, and clears them', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text('Clear'), findsNothing);

      await _tapDay(tester, _d(2026, 10, 8));
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Clear'), findsNothing);
      expect(_findEnabled(tester), isFalse);
      expect(find.text('Tap the first day'), findsOneWidget);
    });

    testWidgets('Clear is there when the picker opens on a last range', (
      tester,
    ) async {
      await _open(
        tester,
        initial: DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10)),
      );

      expect(find.text('Clear'), findsOneWidget);
      expect(_findEnabled(tester), isTrue);
    });
  });

  group('the summary', () {
    Finder polite() => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true,
      description: 'a live region',
    );

    testWidgets('says what the next tap does', (tester) async {
      await _open(tester);
      expect(find.text('Tap the first day'), findsOneWidget);
      expect(find.text('Then tap the last day.'), findsOneWidget);

      await _tapDay(tester, _d(2026, 10, 8));
      expect(find.text('Oct 8 – …'), findsOneWidget);
      expect(
        find.text('Tap the last day, or Find videos for Oct 8 only.'),
        findsOneWidget,
      );

      await _tapDay(tester, _d(2026, 10, 10));
      expect(find.text('Oct 8 – Oct 10'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
    });

    testWidgets('one day is the day and "1 day"', (tester) async {
      await _open(tester);

      await _tapDay(tester, _d(2026, 10, 8));
      await _tapDay(tester, _d(2026, 10, 8));

      expect(find.text('Oct 8'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
    });

    testWidgets('a date in another year carries its year', (tester) async {
      await _open(
        tester,
        initial: DateTimeRange(start: _d(2025, 12, 30), end: _d(2026, 1, 2)),
      );

      expect(find.text('Dec 30, 2025 – Jan 2'), findsOneWidget);
      expect(find.text('4 days'), findsOneWidget);
    });

    testWidgets('follows the phone: 8 Oct on en-GB', (tester) async {
      await _open(tester, locale: const Locale('en', 'GB'));
      await _tapDay(tester, _d(2026, 10, 8));

      expect(find.text('8 Oct – …'), findsOneWidget);
    });

    testWidgets('is a polite live region', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);

      expect(polite(), findsOneWidget);
      final label = tester
          .getSemantics(find.text('Tap the first day'))
          .getSemanticsData();
      expect(label.flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    });

    testWidgets('counts days across a daylight-saving change', (tester) async {
      await _open(
        tester,
        initial: DateTimeRange(start: _d(2026, 3, 27), end: _d(2026, 3, 30)),
      );

      expect(find.text('4 days'), findsOneWidget);
    });
  });

  group('closing and returning', () {
    testWidgets('Close returns null', (tester) async {
      final result = await _open(tester);
      await _tapDay(tester, _d(2026, 10, 8));

      await tester.tap(find.byIcon(Symbols.close_rounded));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.range, isNull);
      expect(find.byType(TtDateRangePickerPage), findsNothing);
    });

    testWidgets('going back returns null', (tester) async {
      final result = await _open(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.range, isNull);
    });

    testWidgets('one day returns end == start', (tester) async {
      final result = await _open(tester);
      await _tapDay(tester, _d(2026, 10, 9));
      await _tapDay(tester, _d(2026, 10, 9));

      await tester.tap(_find);
      await tester.pumpAndSettle();

      expect(
        result.range,
        DateTimeRange(start: _d(2026, 10, 9), end: _d(2026, 10, 9)),
      );
    });

    testWidgets('only the first day chosen counts that one day', (
      tester,
    ) async {
      final result = await _open(tester);
      await _tapDay(tester, _d(2026, 10, 9));

      await tester.tap(_find);
      await tester.pumpAndSettle();

      expect(
        result.range,
        DateTimeRange(start: _d(2026, 10, 9), end: _d(2026, 10, 9)),
      );
    });

    testWidgets('two days return the range', (tester) async {
      final result = await _open(tester);
      await _tapDay(tester, _d(2026, 10, 8));
      await _tapDay(tester, _d(2026, 10, 10));

      await tester.tap(_find);
      await tester.pumpAndSettle();

      expect(
        result.range,
        DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10)),
      );
    });

    testWidgets('it reopens on the last range, in its month', (tester) async {
      final result = await _open(
        tester,
        initial: DateTimeRange(start: _d(2026, 9, 28), end: _d(2026, 10, 3)),
      );

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('6 days'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _cell(_d(2026, 9, 28)),
                matching: find.byType(Text),
              ),
            )
            .style!
            .color,
        _scheme(tester).onPrimary,
      );
      // And Find videos returns that range unchanged.
      await tester.tap(_find);
      await tester.pumpAndSettle();
      expect(
        result.range,
        DateTimeRange(start: _d(2026, 9, 28), end: _d(2026, 10, 3)),
      );
    });

    testWidgets('a first date, last date and initial range are respected', (
      tester,
    ) async {
      await _open(tester);

      // Future days are off.
      await tester.tap(_cell(_d(2026, 10, 29)), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Tap the first day'), findsOneWidget);
    });
  });

  group('quick ranges', () {
    testWidgets('are Yesterday, Last week, This month and Last month', (
      tester,
    ) async {
      await _open(tester);

      for (final label in [
        'Yesterday',
        'Last week',
        'This month',
        'Last month',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('Yesterday fills the calendar with yesterday, and nothing '
        'closes', (tester) async {
      final result = await _open(tester);

      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 27'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
      expect(find.byType(TtDateRangePickerPage), findsOneWidget);
      expect(result.done, isFalse, reason: 'nothing is counted or added');
      expect(_findEnabled(tester), isTrue);
    });

    testWidgets('Last week is the whole week before this one (Sunday first)', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('Last week'));
      await tester.pumpAndSettle();

      // Wed 28 Oct: this week began Sunday 25 Oct, so last week is 18-24.
      expect(find.text('Oct 18 – Oct 24'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
    });

    testWidgets("Last week follows the locale's first day (Monday)", (
      tester,
    ) async {
      await _open(tester, locale: const Locale('en', 'GB'));

      await tester.tap(find.text('Last week'));
      await tester.pumpAndSettle();

      // This week began Monday 26 Oct: last week is Monday 19 to Sunday 25.
      expect(find.text('19 Oct – 25 Oct'), findsOneWidget);
    });

    testWidgets('This month runs from the 1st to today', (tester) async {
      await _open(tester);

      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 1 – Oct 28'), findsOneWidget);
      expect(find.text('28 days'), findsOneWidget);
    });

    testWidgets('Last month is the whole of the month before, and shows it', (
      tester,
    ) async {
      await _open(tester);

      await tester.ensureVisible(find.text('Last month'));
      await tester.tap(find.text('Last month'));
      await tester.pumpAndSettle();

      expect(find.text('Sep 1 – Sep 30'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('Last month in January is December of the year before', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTtDateRangePicker(
                context,
                firstDate: _d(2016, 1, 10),
                lastDate: _d(2026, 1, 10),
                currentDate: _d(2026, 1, 10),
                labels: TtDateRangePickerLabels.english,
              ),
              child: const Text('open'),
            ),
          ),
          disableAnimations: true,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Last month'));
      await tester.tap(find.text('Last month'));
      await tester.pumpAndSettle();

      expect(find.text('December 2025'), findsOneWidget);
      expect(find.text('Dec 1, 2025 – Dec 31, 2025'), findsOneWidget);
    });

    testWidgets('the chip that matches the range is the selected one', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);
      bool selected(String label) =>
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .getSemanticsData()
              .flagsCollection
              .isSelected ==
          ui.Tristate.isTrue;

      expect(selected('Yesterday'), isFalse);
      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();
      expect(selected('Yesterday'), isTrue);
      expect(selected('Last week'), isFalse);

      // Picking another day takes the choice away from the chip.
      await _tapDay(tester, _d(2026, 10, 20));
      expect(selected('Yesterday'), isFalse);
      semantics.dispose();
    });

    testWidgets('a chip works after a range was chosen by hand', (
      tester,
    ) async {
      await _open(tester);
      await _tapDay(tester, _d(2026, 10, 2));
      await _tapDay(tester, _d(2026, 10, 3));

      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();

      expect(find.text('1 day'), findsOneWidget);
    });
  });

  group('focus and motion', () {
    testWidgets('focus moves to the title when it opens', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);

      final data = tester
          .getSemantics(find.text('Choose dates'))
          .getSemanticsData();
      expect(data.flagsCollection.isFocused, ui.Tristate.isTrue);
      expect(data.flagsCollection.isHeader, isTrue);
      semantics.dispose();
    });

    testWidgets('focus returns to the row that opened it', (tester) async {
      final opener = FocusNode();
      addTearDown(opener.dispose);
      await _open(tester, opener: opener);
      expect(opener.hasPrimaryFocus, isFalse, reason: 'the title has it');

      await tester.tap(find.byIcon(Symbols.close_rounded));
      await tester.pumpAndSettle();

      expect(opener.hasPrimaryFocus, isTrue);
    });

    testWidgets('it rises 24 dp and fades in over medium2', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTtDateRangePicker(
                context,
                firstDate: _first,
                lastDate: _today,
                currentDate: _today,
                labels: TtDateRangePickerLabels.english,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final top = tester.getTopLeft(find.byType(TtDateRangePickerPage)).dy;
      expect(top, greaterThan(20));
      expect(top, lessThanOrEqualTo(24));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.getTopLeft(find.byType(TtDateRangePickerPage)).dy, 0);
    });

    testWidgets('with animations removed it does not travel', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTtDateRangePicker(
                context,
                firstDate: _first,
                lastDate: _today,
                currentDate: _today,
                labels: TtDateRangePickerLabels.english,
              ),
              child: const Text('open'),
            ),
          ),
          disableAnimations: true,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(tester.getTopLeft(find.byType(TtDateRangePickerPage)).dy, 0);
    });
  });

  group('looks', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: nothing chosen is accessible', (
        tester,
      ) async {
        await _open(tester, brightness: brightness);

        await expectTtAccessible(tester);
      });

      testWidgets('${brightness.name}: a range chosen is accessible', (
        tester,
      ) async {
        await _open(
          tester,
          brightness: brightness,
          initial: DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10)),
        );

        await expectTtAccessible(tester, includeDisabledText: true);
      });
    }

    testWidgets('at 2x text and 360 dp nothing overflows and the chips wrap', (
      tester,
    ) async {
      await _open(
        tester,
        textScale: 2,
        initial: DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10)),
      );

      expect(tester.takeException(), isNull);
      // The four quick ranges are all in view, in rows, not in a scroller.
      for (final label in [
        'Yesterday',
        'Last week',
        'This month',
        'Last month',
      ]) {
        final rect = tester.getRect(find.text(label));
        expect(rect.right, lessThanOrEqualTo(360 - 16), reason: label);
      }
      // The bottom bar stays on the screen.
      expect(tester.getRect(_find).bottom, lessThanOrEqualTo(800));
      expect(tester.getRect(_find).left, greaterThanOrEqualTo(0));
      // And the days can be reached by scrolling.
      await tester.scrollUntilVisible(
        _cell(_d(2026, 10, 20)),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(_cell(_d(2026, 10, 20)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 2x text the whole title "Choose dates" shows, wrapped', (
      tester,
    ) async {
      await _open(
        tester,
        textScale: 2,
        initial: DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10)),
      );

      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(find.text('Choose dates'));
      expect(title.overflow, isNot(TextOverflow.ellipsis));
      expect(title.maxLines, isNull);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Choose dates'))
            .didExceedMaxLines,
        isFalse,
      );
      // Clear is still there, and the title keeps clear of it.
      expect(find.text('Clear'), findsOneWidget);
      expect(
        tester.getRect(find.text('Choose dates')).right,
        lessThanOrEqualTo(tester.getRect(find.text('Clear')).left),
      );
    });

    testWidgets('at 2x text the year and month grid fits', (tester) async {
      await _open(tester, textScale: 2);

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
