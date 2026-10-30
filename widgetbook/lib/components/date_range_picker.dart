import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtDateRangePickerPage`: the full-screen date range picker of Add earlier
/// videos (D-79), without its route; `showTtDateRangePicker` opens it.
final WidgetbookComponent ttDateRangePickerComponent = WidgetbookComponent(
  name: 'TtDateRangePickerPage',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final today = DateTime(2026, 10, 28);
        final chosen = context.knobs.boolean(label: 'a range chosen');
        return TtDateRangePickerPage(
          firstDate: DateTime(today.year - 10, today.month, today.day),
          lastDate: today,
          today: today,
          labels: TtDateRangePickerLabels.english,
          initialRange: chosen
              ? DateTimeRange(
                  start: DateTime(2026, 10, 8),
                  end: DateTime(2026, 10, 10),
                )
              : null,
          onFind: (_) {},
          onClose: () {},
        );
      },
    ),
  ],
);
