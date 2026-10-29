import 'package:flutter/material.dart';

import '../support/tt_golden.dart';

/// The date range picker "Add earlier videos" opens (D-78), as the phone
/// shows it: a full-screen page, 360 x 640 dp, with today fixed on
/// 2026-10-28.
Widget _picker({DateTimeRange? range}) => MediaQuery(
  data: const MediaQueryData(size: Size(360, 640)),
  child: SizedBox(
    height: 640,
    child: DateRangePickerDialog(
      firstDate: DateTime(2016, 10, 28),
      lastDate: DateTime(2026, 10, 28),
      currentDate: DateTime(2026, 10, 28),
      initialDateRange: range,
      helpText: 'Choose dates',
      saveText: 'Find videos',
    ),
  ),
);

void main() {
  ttGoldenTest(
    'Date range picker',
    fileName: 'date_picker',
    scenarios: [
      TtScenario('nothing chosen', _picker()),
      TtScenario(
        'a range chosen',
        _picker(
          range: DateTimeRange(
            start: DateTime(2026, 10, 20),
            end: DateTime(2026, 10, 24),
          ),
        ),
      ),
    ],
  );
}
