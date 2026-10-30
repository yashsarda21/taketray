import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

// Today is Wednesday 28 Oct 2026; the picker reaches ten years back.
final DateTime _today = DateTime(2026, 10, 28);

/// The picker page as the phone shows it: full screen, 360 x 640 dp.
Widget _page({DateTimeRange? range}) => SizedBox(
  height: 640,
  child: TtDateRangePickerPage(
    firstDate: DateTime(2016, 10, 28),
    lastDate: _today,
    today: _today,
    labels: TtDateRangePickerLabels.english,
    initialRange: range,
    onFind: (_) {},
    onClose: () {},
  ),
);

DateTimeRange _r(DateTime a, DateTime b) => DateTimeRange(start: a, end: b);

void main() {
  ttGoldenTest(
    'Date range picker',
    fileName: 'date_range_picker',
    scenarios: [
      TtScenario('nothing chosen', _page()),
      TtScenario(
        'one day',
        _page(range: _r(DateTime(2026, 10, 9), DateTime(2026, 10, 9))),
      ),
      TtScenario(
        'a range',
        _page(range: _r(DateTime(2026, 10, 8), DateTime(2026, 10, 10))),
      ),
      TtScenario(
        'a range across two months',
        _page(range: _r(DateTime(2026, 9, 28), DateTime(2026, 10, 3))),
      ),
      TtScenario(
        'a quick range: last week',
        _page(range: _r(DateTime(2026, 10, 18), DateTime(2026, 10, 24))),
      ),
    ],
  );
}
