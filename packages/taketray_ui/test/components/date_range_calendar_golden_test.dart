import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

// Today is Wednesday 28 Oct 2026; the picker reaches ten years back.
final DateTime _today = DateTime(2026, 10, 28);

/// The calendar as the picker shows it: 12 dp sides on a 360 dp phone.
Widget _calendar({DateTimeRange? range, bool grid = false}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  child: TtDateRangeCalendar(
    firstDate: DateTime(2016, 10, 28),
    lastDate: _today,
    today: _today,
    labels: TtDateRangeCalendarLabels.english,
    initialRange: range,
    startOnYearGrid: grid,
  ),
);

DateTimeRange _r(DateTime a, DateTime b) => DateTimeRange(start: a, end: b);

void main() {
  ttGoldenTest(
    'Date range calendar',
    fileName: 'date_range_calendar',
    scenarios: [
      TtScenario('nothing chosen, this month', _calendar()),
      TtScenario(
        'first day chosen (one day)',
        _calendar(range: _r(DateTime(2026, 10, 9), DateTime(2026, 10, 9))),
      ),
      TtScenario(
        'a range',
        _calendar(range: _r(DateTime(2026, 10, 8), DateTime(2026, 10, 10))),
      ),
      TtScenario(
        'a range across two months',
        _calendar(range: _r(DateTime(2026, 9, 28), DateTime(2026, 10, 3))),
      ),
      TtScenario(
        'a range ending today',
        _calendar(range: _r(DateTime(2026, 10, 26), _today)),
      ),
      TtScenario(
        'the earliest month',
        _calendar(range: _r(DateTime(2016, 10, 28), DateTime(2016, 10, 30))),
      ),
      TtScenario(
        'a month of six rows',
        _calendar(range: _r(DateTime(2026, 8, 12), DateTime(2026, 8, 14))),
      ),
      TtScenario(
        'year and month grid',
        _calendar(
          range: _r(DateTime(2026, 9, 28), DateTime(2026, 10, 3)),
          grid: true,
        ),
      ),
      TtScenario(
        'year and month grid, ten years back',
        _calendar(
          range: _r(DateTime(2016, 10, 28), DateTime(2016, 10, 30)),
          grid: true,
        ),
      ),
    ],
  );
}
