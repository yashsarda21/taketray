import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

// Today is Wednesday 28 Oct 2026; the picker reaches ten years back.
final DateTime _today = DateTime(2026, 10, 28);
final DateTime _first = DateTime(2016, 10, 28);

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// The cell of day [d] (the key the calendar gives every day it shows).
Finder _cell(DateTime d) => find.byKey(ValueKey<DateTime>(d));

Widget _calendar({
  DateTimeRange? initialRange,
  ValueChanged<DateTimeRange?>? onChanged,
  TtDateRangeCalendarController? controller,
  DateTime? first,
  DateTime? last,
}) => Padding(
  // 360 dp wide with the 12 dp sides the picker gives it.
  padding: EdgeInsets.zero,
  child: SingleChildScrollView(
    child: TtDateRangeCalendar(
      firstDate: first ?? _first,
      lastDate: last ?? _today,
      today: _today,
      labels: TtDateRangeCalendarLabels.english,
      initialRange: initialRange,
      onChanged: onChanged,
      controller: controller,
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget calendar, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool disableAnimations = true,
  Locale? locale,
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // A fresh tree, so a second _pump in a test starts a new calendar.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ttTestApp(
      calendar,
      textScale: textScale,
      brightness: brightness,
      disableAnimations: disableAnimations,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

ColorScheme _scheme(WidgetTester tester) =>
    tester.element(find.byType(TtDateRangeCalendar)).scheme;

TextStyle _dayStyle(WidgetTester tester, DateTime d) => tester
    .widget<Text>(find.descendant(of: _cell(d), matching: find.byType(Text)))
    .style!;

/// The circle drawn behind a day, or null.
BoxDecoration? _circle(WidgetTester tester, DateTime d) {
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: _cell(d), matching: find.byType(DecoratedBox)),
  )) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
      return decoration;
    }
  }
  return null;
}

/// The colours of the band drawn behind a day (full or half).
List<Color> _bands(WidgetTester tester, DateTime d) => [
  for (final box in tester.widgetList<ColoredBox>(
    find.descendant(of: _cell(d), matching: find.byType(ColoredBox)),
  ))
    box.color,
];

SemanticsData _semantics(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

bool _enabled(WidgetTester tester, Finder icon) {
  final button = tester.widget<IconButton>(
    find.ancestor(of: icon, matching: find.byType(IconButton)),
  );
  return button.onPressed != null;
}

final Finder _next = find.byIcon(Symbols.chevron_right_rounded);
final Finder _previous = find.byIcon(Symbols.chevron_left_rounded);

void main() {
  group('the month', () {
    testWidgets('shows the month name and the days of that month', (
      tester,
    ) async {
      await _pump(tester, _calendar());

      expect(find.text('October 2026'), findsOneWidget);
      // 1 Oct 2026 is a Thursday; weeks start on Sunday in the default locale,
      // so the grid starts on Sunday 27 Sep and ends on Saturday 31 Oct.
      expect(_cell(_d(2026, 9, 27)), findsOneWidget);
      expect(_cell(_d(2026, 9, 26)), findsNothing);
      expect(_cell(_d(2026, 10, 31)), findsOneWidget);
      expect(_cell(_d(2026, 11, 1)), findsNothing);
    });

    testWidgets("opens on the month of the initial range's last day", (
      tester,
    ) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 8, 30),
            end: _d(2026, 9, 2),
          ),
        ),
      );

      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets("the weekday row starts on the locale's first day", (
      tester,
    ) async {
      await _pump(tester, _calendar(), locale: const Locale('en', 'US'));
      List<String> letters() => [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(TtDateRangeCalendar),
            matching: find.byType(Text),
          ),
        ))
          if (const {'S', 'M', 'T', 'W', 'F'}.contains(text.data)) text.data!,
      ];
      expect(letters().take(7), ['S', 'M', 'T', 'W', 'T', 'F', 'S']);

      // en-GB weeks start on Monday: the first column is a Monday.
      await _pump(tester, _calendar(), locale: const Locale('en', 'GB'));
      expect(letters().take(7), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
      // 1 Oct 2026 is a Thursday: the grid starts on Monday 28 Sep.
      expect(_cell(_d(2026, 9, 28)), findsOneWidget);
      expect(_cell(_d(2026, 9, 27)), findsNothing);
      // ... and ends on Sunday 1 Nov.
      expect(_cell(_d(2026, 11, 1)), findsOneWidget);
      expect(_cell(_d(2026, 11, 2)), findsNothing);
    });

    testWidgets('a 31-day month that starts on the last weekday has 6 rows', (
      tester,
    ) async {
      // 1 Aug 2026 is a Saturday, the last day of a Sunday-first week.
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 8, 5),
            end: _d(2026, 8, 6),
          ),
        ),
      );

      expect(find.text('August 2026'), findsOneWidget);
      expect(_cell(_d(2026, 7, 26)), findsOneWidget);
      expect(_cell(_d(2026, 8, 31)), findsOneWidget);
      // 31 Aug is a Monday: the sixth row runs to Saturday 5 Sep.
      expect(_cell(_d(2026, 9, 5)), findsOneWidget);
      expect(_cell(_d(2026, 9, 6)), findsNothing);
      final top = tester.getTopLeft(_cell(_d(2026, 7, 26))).dy;
      final bottom = tester.getTopLeft(_cell(_d(2026, 8, 30))).dy;
      expect((bottom - top) / 48, 5, reason: 'six rows of 48 dp');
    });

    testWidgets('February of a leap year has a 29th and no 30th', (
      tester,
    ) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2024, 2, 27),
            end: _d(2024, 2, 29),
          ),
        ),
      );

      expect(find.text('February 2024'), findsOneWidget);
      expect(_cell(_d(2024, 2, 29)), findsOneWidget);
      // The day after the 29th is 1 March, drawn as a day of another month.
      expect(_cell(_d(2024, 3, 1)), findsOneWidget);
      expect(
        _dayStyle(tester, _d(2024, 2, 29)).color,
        _scheme(tester).onPrimary,
        reason: 'the 29th is in the month (and is the last chosen day)',
      );
      expect(
        _dayStyle(tester, _d(2024, 3, 1)).color,
        _scheme(tester).onSurfaceVariant,
        reason: 'a day of the next month',
      );
    });

    testWidgets('February of a normal year ends on the 28th', (tester) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 2, 3),
            end: _d(2026, 2, 4),
          ),
        ),
      );

      // 1 Feb 2026 is a Sunday and 28 Feb a Saturday: four exact rows.
      expect(_cell(_d(2026, 2, 1)), findsOneWidget);
      expect(_cell(_d(2026, 1, 31)), findsNothing);
      expect(_cell(_d(2026, 2, 28)), findsOneWidget);
      expect(_cell(_d(2026, 3, 1)), findsNothing);
    });

    testWidgets('days are 48 x 48 dp, 7 columns inside 12 dp sides at 360 dp', (
      tester,
    ) async {
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _calendar(),
        ),
      );

      final target = find.descendant(
        of: _cell(_d(2026, 10, 8)),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(target), const Size(48, 48));
      expect(tester.getSize(_cell(_d(2026, 10, 8))), const Size(48, 48));
      // Sunday 27 Sep is the first column: 12 dp from the edge.
      expect(tester.getTopLeft(_cell(_d(2026, 9, 27))).dx, 12);
      expect(tester.getTopRight(_cell(_d(2026, 10, 3))).dx, 348);
    });

    testWidgets('on a wider phone the columns share the extra width', (
      tester,
    ) async {
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _calendar(),
        ),
        size: const Size(412, 800),
      );

      expect(
        tester.getSize(_cell(_d(2026, 10, 8))).width,
        closeTo(388 / 7, 0.01),
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: _cell(_d(2026, 10, 8)),
                matching: find.byType(InkWell),
              ),
            )
            .width,
        48,
        reason: 'the target stays 48 dp',
      );
    });
  });

  group('tapping days', () {
    late List<DateTimeRange?> changes;
    late TtDateRangeCalendarController controller;

    setUp(() {
      changes = [];
      controller = TtDateRangeCalendarController();
      addTearDown(controller.dispose);
    });

    Future<void> tap(WidgetTester tester, DateTime d) async {
      await tester.tap(_cell(d));
      await tester.pumpAndSettle();
    }

    Future<void> pumpIt(WidgetTester tester) => _pump(
      tester,
      _calendar(controller: controller, onChanged: changes.add),
    );

    testWidgets('the first tap picks the first day', (tester) async {
      await pumpIt(tester);

      await tap(tester, _d(2026, 10, 8));

      expect(controller.start, _d(2026, 10, 8));
      expect(controller.end, isNull);
      // One day so far: a range of that single day (Find videos counts it).
      expect(changes, [
        DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 8)),
      ]);
    });

    testWidgets('the second tap picks the last day', (tester) async {
      await pumpIt(tester);

      await tap(tester, _d(2026, 10, 8));
      await tap(tester, _d(2026, 10, 10));

      expect(controller.start, _d(2026, 10, 8));
      expect(controller.end, _d(2026, 10, 10));
      expect(
        changes.last,
        DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10)),
      );
    });

    testWidgets('the same day twice means one day', (tester) async {
      await pumpIt(tester);

      await tap(tester, _d(2026, 10, 8));
      await tap(tester, _d(2026, 10, 8));

      expect(controller.start, _d(2026, 10, 8));
      expect(controller.end, _d(2026, 10, 8), reason: 'both ends chosen');
      expect(
        changes.last,
        DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 8)),
      );
    });

    testWidgets('a tap before the first day moves the first day', (
      tester,
    ) async {
      await pumpIt(tester);

      await tap(tester, _d(2026, 10, 8));
      await tap(tester, _d(2026, 10, 5));

      expect(controller.start, _d(2026, 10, 5));
      expect(controller.end, isNull, reason: 'still waiting for the last day');
      // And the next tap after it is the last day.
      await tap(tester, _d(2026, 10, 9));
      expect(controller.start, _d(2026, 10, 5));
      expect(controller.end, _d(2026, 10, 9));
    });

    testWidgets('a tap after a full range starts again', (tester) async {
      await pumpIt(tester);
      await tap(tester, _d(2026, 10, 8));
      await tap(tester, _d(2026, 10, 10));

      await tap(tester, _d(2026, 10, 20));

      expect(controller.start, _d(2026, 10, 20));
      expect(controller.end, isNull);
      expect(
        changes.last,
        DateTimeRange(start: _d(2026, 10, 20), end: _d(2026, 10, 20)),
      );
    });

    testWidgets('a tap before a full range also starts again, not extends', (
      tester,
    ) async {
      await pumpIt(tester);
      await tap(tester, _d(2026, 10, 8));
      await tap(tester, _d(2026, 10, 10));

      await tap(tester, _d(2026, 10, 2));

      expect(controller.start, _d(2026, 10, 2));
      expect(controller.end, isNull);
    });

    testWidgets(
      'a tap on the only day after it was chosen twice starts again',
      (tester) async {
        await pumpIt(tester);
        await tap(tester, _d(2026, 10, 8));
        await tap(tester, _d(2026, 10, 8));

        await tap(tester, _d(2026, 10, 8));

        expect(controller.start, _d(2026, 10, 8));
        expect(controller.end, isNull);
      },
    );

    testWidgets('a day of another month can be tapped, and the month stays', (
      tester,
    ) async {
      await pumpIt(tester);

      await tap(tester, _d(2026, 9, 30));

      expect(controller.start, _d(2026, 9, 30));
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('future days are off: nothing happens', (tester) async {
      await pumpIt(tester);

      await tester.tap(_cell(_d(2026, 10, 29)), warnIfMissed: false);
      await tester.tap(_cell(_d(2026, 10, 31)), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(controller.start, isNull);
      expect(changes, isEmpty);
    });

    testWidgets('today is the last day that can be tapped', (tester) async {
      await pumpIt(tester);

      await tap(tester, _today);

      expect(controller.start, _today);
    });

    testWidgets('nothing before the first date can be tapped', (tester) async {
      // The controller opens on the first date's month, then is cleared.
      controller.setRange(DateTimeRange(start: _first, end: _first));
      await _pump(
        tester,
        _calendar(controller: controller, onChanged: changes.add),
      );
      controller.clear();
      await tester.pumpAndSettle();
      changes.clear();
      expect(find.text('October 2016'), findsOneWidget);

      await tester.tap(_cell(_d(2016, 10, 27)), warnIfMissed: false);
      await tester.tap(_cell(_d(2016, 10, 1)), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(controller.start, isNull);
      expect(changes, isEmpty);

      await tap(tester, _first);
      expect(controller.start, _first, reason: 'the first date itself is on');
    });

    testWidgets("a controller's changes redraw the days", (tester) async {
      await pumpIt(tester);

      controller.setRange(
        DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10)),
      );
      await tester.pumpAndSettle();

      expect(_circle(tester, _d(2026, 10, 8))!.color, _scheme(tester).primary);
      expect(_circle(tester, _d(2026, 10, 10))!.color, _scheme(tester).primary);
      expect(
        changes.last,
        DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10)),
      );

      controller.clear();
      await tester.pumpAndSettle();
      expect(_circle(tester, _d(2026, 10, 8))?.color, isNull);
      expect(changes.last, isNull);
    });

    testWidgets('setRange shows the month of the last day', (tester) async {
      await pumpIt(tester);

      controller.setRange(
        DateTimeRange(start: _d(2026, 8, 20), end: _d(2026, 9, 3)),
      );
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
    });
  });

  group('how the days look', () {
    DateTimeRange range() =>
        DateTimeRange(start: _d(2026, 10, 8), end: _d(2026, 10, 10));

    testWidgets('first and last day are primary circles with onPrimary text', (
      tester,
    ) async {
      await _pump(tester, _calendar(initialRange: range()));
      final scheme = _scheme(tester);

      for (final day in [_d(2026, 10, 8), _d(2026, 10, 10)]) {
        expect(_circle(tester, day)!.color, scheme.primary);
        final style = _dayStyle(tester, day);
        expect(style.color, scheme.onPrimary);
        expect(style.fontWeight, FontWeight.w700);
        expect(
          style.fontVariations,
          contains(const ui.FontVariation('wght', 700)),
        );
      }
    });

    testWidgets('days between wear the container band and onPrimaryContainer', (
      tester,
    ) async {
      await _pump(tester, _calendar(initialRange: range()));
      final scheme = _scheme(tester);

      expect(_bands(tester, _d(2026, 10, 9)), [scheme.primaryContainer]);
      expect(_circle(tester, _d(2026, 10, 9)), isNull);
      expect(
        _dayStyle(tester, _d(2026, 10, 9)).color,
        scheme.onPrimaryContainer,
      );
      // Half a cell of band under each end (the other half is the surface).
      for (final end in [_d(2026, 10, 8), _d(2026, 10, 10)]) {
        expect(_bands(tester, end), [scheme.primaryContainer]);
      }
      final startBand = find.descendant(
        of: _cell(_d(2026, 10, 8)),
        matching: find.byType(ColoredBox),
      );
      final cell = tester.getRect(_cell(_d(2026, 10, 8)));
      final band = tester.getRect(startBand.first);
      expect(band.width, closeTo(cell.width / 2, 0.01));
      expect(band.right, cell.right, reason: 'the band runs on to the right');
      final endBand = tester.getRect(
        find
            .descendant(
              of: _cell(_d(2026, 10, 10)),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      final endCell = tester.getRect(_cell(_d(2026, 10, 10)));
      expect(endBand.width, closeTo(endCell.width / 2, 0.01));
      expect(endBand.left, endCell.left, reason: 'it comes in from the left');
      // Days outside the range have no band.
      expect(_bands(tester, _d(2026, 10, 7)), isEmpty);
      expect(_bands(tester, _d(2026, 10, 11)), isEmpty);
    });

    testWidgets('one day, or a first day alone, has no band', (tester) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 10, 9),
            end: _d(2026, 10, 9),
          ),
        ),
      );

      expect(_circle(tester, _d(2026, 10, 9))!.color, _scheme(tester).primary);
      expect(_bands(tester, _d(2026, 10, 9)), isEmpty);
    });

    testWidgets('today has a 1 dp primary ring and primary text', (
      tester,
    ) async {
      await _pump(tester, _calendar());
      final scheme = _scheme(tester);

      final ring = _circle(tester, _today)!;
      expect(ring.color, isNull);
      expect(ring.border, Border.all(color: scheme.primary));
      expect(_dayStyle(tester, _today).color, scheme.primary);
    });

    testWidgets('a day is onSurface at weight 600, of another month 500', (
      tester,
    ) async {
      await _pump(tester, _calendar());
      final scheme = _scheme(tester);

      final day = _dayStyle(tester, _d(2026, 10, 14));
      expect(day.color, scheme.onSurface);
      expect(day.fontWeight, FontWeight.w600);
      expect(day.fontVariations, contains(const ui.FontVariation('wght', 600)));
      final other = _dayStyle(tester, _d(2026, 9, 29));
      expect(other.color, scheme.onSurfaceVariant);
      expect(other.fontWeight, FontWeight.w500);
      expect(
        other.fontVariations,
        contains(const ui.FontVariation('wght', 500)),
      );
    });

    testWidgets('an off day is onSurfaceVariant, weight 400, crossed out', (
      tester,
    ) async {
      await _pump(tester, _calendar());
      final scheme = _scheme(tester);

      final off = _dayStyle(tester, _d(2026, 10, 30));
      expect(off.color, scheme.onSurfaceVariant);
      expect(off.fontWeight, FontWeight.w400);
      expect(off.decoration, TextDecoration.lineThrough);
      expect(off.color!.a, 1, reason: 'no opacity: it stays readable');
      expect(_dayStyle(tester, _d(2026, 10, 27)).decoration, isNull);
    });
  });

  group('between months', () {
    testWidgets('‹ and › change the month', (tester) async {
      await _pump(tester, _calendar());

      await tester.tap(_previous);
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);

      await tester.tap(_next);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('› stops at the month of the last date', (tester) async {
      await _pump(tester, _calendar());

      expect(_enabled(tester, _next), isFalse);
      await tester.tap(_next, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(_enabled(tester, _previous), isTrue);
    });

    testWidgets('› still works in the month before the last one', (
      tester,
    ) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 9, 3),
            end: _d(2026, 9, 4),
          ),
        ),
      );

      expect(_enabled(tester, _next), isTrue);
    });

    testWidgets('‹ stops at the month of the first date', (tester) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(start: _first, end: _first),
        ),
      );

      expect(find.text('October 2016'), findsOneWidget);
      expect(_enabled(tester, _previous), isFalse);
      expect(_enabled(tester, _next), isTrue);
      await tester.tap(_previous, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('October 2016'), findsOneWidget);
    });

    testWidgets('the disabled arrow is drawn at 38 % opacity', (tester) async {
      await _pump(tester, _calendar());

      final button = tester.widget<IconButton>(
        find.ancestor(of: _next, matching: find.byType(IconButton)),
      );
      expect(
        button.style!.foregroundColor!.resolve({WidgetState.disabled}),
        _scheme(tester).onSurface
            .withValues(alpha: TtMetrics.disabledContentOpacity),
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        _scheme(tester).onSurface,
      );
    });

    testWidgets('a swipe left shows the next month, right the previous', (
      tester,
    ) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 9, 3),
            end: _d(2026, 9, 4),
          ),
        ),
      );

      await tester.fling(_cell(_d(2026, 9, 15)), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);

      await tester.fling(_cell(_d(2026, 10, 15)), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      await tester.fling(_cell(_d(2026, 9, 15)), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);
    });

    testWidgets('a swipe cannot pass the limits', (tester) async {
      await _pump(tester, _calendar());

      await tester.fling(_cell(_d(2026, 10, 15)), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget, reason: 'no future');

      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(start: _first, end: _first),
        ),
      );
      await tester.fling(_cell(_d(2016, 10, 15)), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('October 2016'), findsOneWidget, reason: 'no earlier');
    });

    testWidgets("a slow drag of a day's width also changes the month", (
      tester,
    ) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 9, 3),
            end: _d(2026, 9, 4),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(_cell(_d(2026, 9, 15))),
      );
      // The first move only starts the drag (past the touch slop); a day's
      // width (48 dp) of slow drag follows it.
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(seconds: 1));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('a small slip of the finger does not change the month', (
      tester,
    ) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 9, 3),
            end: _d(2026, 9, 4),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(_cell(_d(2026, 9, 15))),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('a new month slides in 24 dp and fades, over medium1', (
      tester,
    ) async {
      await _pump(tester, _calendar(), disableAnimations: false);
      // 27 Sep is in the Sunday column of both October's and September's grid.
      final settled = tester.getTopLeft(_cell(_d(2026, 9, 27))).dx;

      await tester.tap(_previous);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      // Going back: the new month comes in from the left, 24 dp away.
      final start = tester.getTopLeft(_cell(_d(2026, 9, 27))).dx;
      expect(start, lessThan(settled - 20));
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: _cell(_d(2026, 9, 27)),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, lessThan(0.2));

      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(_cell(_d(2026, 9, 27))).dx, settled);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: _cell(_d(2026, 9, 27)),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );
    });

    testWidgets('going forward the new month comes in from the right', (
      tester,
    ) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 9, 3),
            end: _d(2026, 9, 4),
          ),
        ),
        disableAnimations: false,
      );
      final settled = tester.getTopLeft(_cell(_d(2026, 9, 27))).dx;

      await tester.tap(_next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(
        tester.getTopLeft(_cell(_d(2026, 9, 27))).dx,
        greaterThan(settled + 20),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('with animations removed a month does not travel', (
      tester,
    ) async {
      await _pump(tester, _calendar());
      final settled = tester.getTopLeft(_cell(_d(2026, 9, 27))).dx;

      await tester.tap(_previous);
      await tester.pump();

      expect(tester.getTopLeft(_cell(_d(2026, 9, 27))).dx, settled);
      expect(
        find.ancestor(
          of: _cell(_d(2026, 9, 27)),
          matching: find.byType(Opacity),
        ),
        findsNothing,
        reason: 'no fade either: it is just there',
      );
    });
  });

  group('the year and month grid', () {
    testWidgets('startOnYearGrid opens it at first', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: TtDateRangeCalendar(
            firstDate: _first,
            lastDate: _today,
            today: _today,
            labels: TtDateRangeCalendarLabels.english,
            startOnYearGrid: true,
          ),
        ),
      );

      expect(find.text('Year'), findsOneWidget);
      expect(_cell(_d(2026, 10, 8)), findsNothing);
    });

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
    }

    testWidgets('the month name opens it and hides the days and arrows', (
      tester,
    ) async {
      await _pump(tester, _calendar());

      await open(tester);

      expect(_cell(_d(2026, 10, 8)), findsNothing);
      expect(_next, findsNothing);
      expect(_previous, findsNothing);
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.byIcon(Symbols.arrow_drop_up_rounded), findsOneWidget);
    });

    testWidgets('years run from this year back ten years, newest first', (
      tester,
    ) async {
      await _pump(tester, _calendar());
      await open(tester);

      final years = [for (var y = 2026; y >= 2016; y--) y];
      for (final y in years) {
        expect(find.text('$y'), findsOneWidget);
      }
      expect(find.text('2027'), findsNothing);
      expect(find.text('2015'), findsNothing);
      final tops = [for (final y in years) tester.getTopLeft(find.text('$y'))];
      for (var i = 1; i < tops.length; i++) {
        final before = tops[i - 1];
        final after = tops[i];
        expect(
          after.dy > before.dy ||
              (after.dy == before.dy && after.dx > before.dx),
          isTrue,
          reason: '${years[i]} comes after ${years[i - 1]}',
        );
      }
    });

    testWidgets('shows the 12 months of the chosen year, the open one chosen', (
      tester,
    ) async {
      await _pump(tester, _calendar());
      await open(tester);
      final scheme = _scheme(tester);

      for (final m in const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
      ]) {
        expect(find.text(m), findsOneWidget);
      }
      Color? fill(String text) {
        final box = tester.widget<Material>(
          find
              .ancestor(of: find.text(text), matching: find.byType(Material))
              .first,
        );
        return box.color;
      }

      expect(fill('Oct'), scheme.primary, reason: 'the open month');
      expect(fill('Sep'), scheme.surfaceContainerHigh);
      expect(fill('2026'), scheme.primary, reason: 'the open year');
      expect(fill('2025'), scheme.surfaceContainerHigh);
    });

    testWidgets('months after this month are off, before the first month too', (
      tester,
    ) async {
      await _pump(tester, _calendar());
      await open(tester);

      Material pill(String text) => tester.widget<Material>(
        find
            .ancestor(of: find.text(text), matching: find.byType(Material))
            .first,
      );
      final scheme = _scheme(tester);
      for (final m in ['Nov', 'Dec']) {
        final text = tester.widget<Text>(find.text(m)).style!;
        expect(text.decoration, TextDecoration.lineThrough, reason: m);
        expect(text.color, scheme.onSurfaceVariant);
        expect(
          pill(m).type,
          MaterialType.transparency,
          reason: '$m has no fill',
        );
      }
      expect(tester.widget<Text>(find.text('Sep')).style!.decoration, isNull);

      // An off month cannot be tapped: the grid stays open.
      await tester.tap(find.text('Nov'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Year'), findsOneWidget);

      // 2016: only October to December exist (the first date is 28 Oct).
      await tester.tap(find.text('2016'));
      await tester.pumpAndSettle();
      for (final m in [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
      ]) {
        expect(
          tester.widget<Text>(find.text(m)).style!.decoration,
          TextDecoration.lineThrough,
          reason: m,
        );
      }
      for (final m in ['Oct', 'Nov', 'Dec']) {
        expect(tester.widget<Text>(find.text(m)).style!.decoration, isNull);
      }
    });

    testWidgets('a month goes back to its days, in that year', (tester) async {
      await _pump(tester, _calendar());
      await open(tester);

      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();

      expect(find.text('March 2024'), findsOneWidget);
      expect(_cell(_d(2024, 3, 14)), findsOneWidget);
      expect(find.text('Year'), findsNothing);
    });

    testWidgets('the month name closes it again', (tester) async {
      await _pump(tester, _calendar());
      await open(tester);

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();

      expect(find.text('Year'), findsNothing);
      expect(_cell(_d(2026, 10, 8)), findsOneWidget);
      expect(find.byIcon(Symbols.arrow_drop_down_rounded), findsOneWidget);
    });

    testWidgets('it opens on the year of the month on show', (tester) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2023, 5, 2),
            end: _d(2023, 5, 3),
          ),
        ),
      );

      await tester.tap(find.text('May 2023'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Material>(
              find
                  .ancestor(
                    of: find.text('2023'),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        _scheme(tester).primary,
      );
    });

    testWidgets('months holding chosen days get a 1 dp primary ring', (
      tester,
    ) async {
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 9, 28),
            end: _d(2026, 10, 3),
          ),
        ),
      );
      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      final scheme = _scheme(tester);

      ShapeBorder? border(String text) => tester
          .widget<Material>(
            find
                .ancestor(of: find.text(text), matching: find.byType(Material))
                .first,
          )
          .shape;

      expect(
        border('Sep'),
        StadiumBorder(side: BorderSide(color: scheme.primary)),
      );
      // The open month is filled, so no ring.
      expect(border('Oct'), const StadiumBorder());
      expect(border('Aug'), const StadiumBorder());
    });

    testWidgets('the pills have at least 48 dp height and 5 em width', (
      tester,
    ) async {
      await _pump(tester, _calendar());
      await open(tester);
      // 5 em of the label style at 1x, text scaled.
      final em = tester.widget<Text>(find.text('Oct')).style!.fontSize!;

      final oct = tester.getSize(
        find
            .ancestor(of: find.text('Oct'), matching: find.byType(InkWell))
            .first,
      );
      expect(oct.height, greaterThanOrEqualTo(48));
      expect(oct.width, greaterThanOrEqualTo(5 * em));
    });

    testWidgets('at 2x text there are fewer columns and nothing overflows', (
      tester,
    ) async {
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _calendar(),
        ),
        textScale: 2,
      );
      await open(tester);

      expect(tester.takeException(), isNull);
      final jan = tester.getTopLeft(find.text('Jan'));
      final feb = tester.getTopLeft(find.text('Feb'));
      final mar = tester.getTopLeft(find.text('Mar'));
      final aprilRow = tester.getTopLeft(find.text('Apr')).dy;
      final columns = [jan, feb, mar].where((o) => o.dy == jan.dy).length;
      expect(columns, lessThan(4), reason: 'fewer columns at 2x text');
      expect(aprilRow, greaterThanOrEqualTo(jan.dy));
      for (final text in ['Jan', 'Oct', '2026']) {
        final box = tester.getRect(
          find
              .ancestor(of: find.text(text), matching: find.byType(InkWell))
              .first,
        );
        expect(box.right, lessThanOrEqualTo(348));
        expect(box.left, greaterThanOrEqualTo(12));
      }
    });

    testWidgets(
      'picking a year keeps the month on show until a month is picked',
      (tester) async {
        await _pump(tester, _calendar());
        await open(tester);

        await tester.tap(find.text('2020'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('October 2026'));
        await tester.pumpAndSettle();

        expect(find.text('October 2026'), findsOneWidget, reason: 'unchanged');
      },
    );
  });

  group('semantics', () {
    testWidgets('the days are a table of rows of cells with full-date labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _calendar());

      final table = tester.getSemantics(
        find.bySemanticsLabel('October 2026').first,
      );
      expect(table.getSemanticsData().role, ui.SemanticsRole.table);
      expect(
        tester.getSemantics(_cell(_d(2026, 10, 14))).getSemanticsData().role,
        ui.SemanticsRole.cell,
      );
      expect(
        find.bySemanticsLabel('Wednesday, October 14, 2026'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'first, last, in the range, the only day, today, not available',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          _calendar(
            initialRange: DateTimeRange(
              start: _d(2026, 10, 8),
              end: _d(2026, 10, 10),
            ),
          ),
        );
        String label(DateTime d) => _semantics(tester, _cell(d)).label;

        expect(label(_d(2026, 10, 8)), 'Thursday, October 8, 2026, first day');
        expect(label(_d(2026, 10, 9)), 'Friday, October 9, 2026, in the range');
        expect(label(_d(2026, 10, 10)), 'Saturday, October 10, 2026, last day');
        expect(label(_d(2026, 10, 11)), 'Sunday, October 11, 2026');
        expect(label(_today), 'Wednesday, October 28, 2026, today');
        expect(
          label(_d(2026, 10, 29)),
          'Thursday, October 29, 2026, not available',
        );
        handle.dispose();
      },
    );

    testWidgets('the only day, and a first day waiting for its last day', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TtDateRangeCalendarController();
      addTearDown(controller.dispose);
      await _pump(tester, _calendar(controller: controller));

      controller.tapDay(_d(2026, 10, 9));
      await tester.pumpAndSettle();
      expect(
        _semantics(tester, _cell(_d(2026, 10, 9))).label,
        'Friday, October 9, 2026, first day',
      );
      controller.tapDay(_d(2026, 10, 9));
      await tester.pumpAndSettle();
      expect(
        _semantics(tester, _cell(_d(2026, 10, 9))).label,
        'Friday, October 9, 2026, the only day',
      );
      handle.dispose();
    });

    testWidgets('today that is also chosen says both, and an off day is not '
        'a button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(start: _d(2026, 10, 27), end: _today),
        ),
      );

      expect(
        _semantics(tester, _cell(_today)).label,
        'Wednesday, October 28, 2026, last day, today',
      );
      expect(
        _semantics(
          tester,
          _cell(_d(2026, 10, 30)),
        ).hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      expect(
        _semantics(
          tester,
          _cell(_d(2026, 10, 14)),
        ).hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('chosen days are marked selected, the others are not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 10, 8),
            end: _d(2026, 10, 10),
          ),
        ),
      );

      for (final d in [_d(2026, 10, 8), _d(2026, 10, 9), _d(2026, 10, 10)]) {
        expect(
          _semantics(tester, _cell(d)).flagsCollection.isSelected,
          ui.Tristate.isTrue,
          reason: '$d',
        );
      }
      for (final d in [_d(2026, 10, 7), _d(2026, 10, 11), _d(2026, 9, 30)]) {
        expect(
          _semantics(tester, _cell(d)).flagsCollection.isSelected,
          isNot(ui.Tristate.isTrue),
          reason: '$d',
        );
      }
      handle.dispose();
    });

    testWidgets('the month button, ‹ and ›', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _calendar());

      expect(
        find.bySemanticsLabel('Choose month and year. Now October 2026'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Previous month'), findsOneWidget);
      expect(find.bySemanticsLabel('Next month'), findsOneWidget);
      // At this month › is disabled.
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Next month'))
            .getSemanticsData()
            .flagsCollection
            .isEnabled,
        ui.Tristate.isFalse,
      );

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Back to the days'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Back to the days'))
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        ui.Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('years are radio buttons; months say chosen days and '
        'availability', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _calendar(
          initialRange: DateTimeRange(
            start: _d(2026, 9, 28),
            end: _d(2026, 10, 3),
          ),
        ),
      );
      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();

      final year = _semantics(tester, find.bySemanticsLabel('2026'));
      expect(year.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(year.flagsCollection.isChecked, ui.CheckedState.isTrue);
      final other = _semantics(tester, find.bySemanticsLabel('2025'));
      expect(other.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(other.flagsCollection.isChecked, ui.CheckedState.isFalse);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Year'))
            .getSemanticsData()
            .role,
        ui.SemanticsRole.radioGroup,
      );

      expect(
        find.bySemanticsLabel('September 2026, has chosen days'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('October 2026, has chosen days'),
        findsWidgets,
      );
      expect(find.bySemanticsLabel('August 2026'), findsOneWidget);
      expect(
        find.bySemanticsLabel('November 2026, not available'),
        findsOneWidget,
      );
      expect(
        _semantics(
          tester,
          find.bySemanticsLabel('November 2026, not available'),
        ).hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      handle.dispose();
    });
  });

  group('looks at any size', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: a chosen range is accessible', (
        tester,
      ) async {
        await _pump(
          tester,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _calendar(
              initialRange: DateTimeRange(
                start: _d(2026, 10, 8),
                end: _d(2026, 10, 10),
              ),
            ),
          ),
          brightness: brightness,
        );

        // The off days (29 to 31 Oct) are measured too: AA, not exempt.
        await expectTtAccessible(tester, includeDisabledText: true);
      });

      testWidgets('${brightness.name}: the year and month grid is accessible', (
        tester,
      ) async {
        await _pump(
          tester,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _calendar(),
          ),
          brightness: brightness,
        );
        await tester.tap(find.text('October 2026'));
        await tester.pumpAndSettle();

        await expectTtAccessible(tester);
      });
    }

    testWidgets('at 2x text and 360 dp nothing overflows', (tester) async {
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _calendar(
            initialRange: DateTimeRange(
              start: _d(2026, 10, 8),
              end: _d(2026, 10, 10),
            ),
          ),
        ),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(TtDateRangeCalendar)).right, 348);
      await tester.tap(_cell(_d(2026, 10, 20)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('right to left: the band and the swipe follow the direction', (
      tester,
    ) async {
      await _pump(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: _calendar(
            initialRange: DateTimeRange(
              start: _d(2026, 9, 8),
              end: _d(2026, 9, 10),
            ),
          ),
        ),
      );
      final cell = tester.getRect(_cell(_d(2026, 9, 8)));
      final band = tester.getRect(
        find
            .descendant(
              of: _cell(_d(2026, 9, 8)),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(band.left, cell.left, reason: "the first day's band points left");

      // A swipe right is "forward" in right-to-left.
      await tester.fling(_cell(_d(2026, 9, 15)), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
    });
  });
}
