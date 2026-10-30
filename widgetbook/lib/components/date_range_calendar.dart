import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtDateRangeCalendar`: a month of days to choose a range from, with its
/// year and month grid, as the date range picker shows it (D-79).
final WidgetbookComponent ttDateRangeCalendarComponent = WidgetbookComponent(
  name: 'TtDateRangeCalendar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final today = DateTime(2026, 10, 28);
        final grid = context.knobs.boolean(label: 'year and month grid');
        final chosen = context.knobs.boolean(
          label: 'a range chosen',
          initialValue: true,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: context.tt.spacing.s),
          child: TtDateRangeCalendar(
            firstDate: DateTime(today.year - 10, today.month, today.day),
            lastDate: today,
            today: today,
            labels: TtDateRangeCalendarLabels.english,
            startOnYearGrid: grid,
            initialRange: chosen
                ? DateTimeRange(
                    start: DateTime(2026, 9, 28),
                    end: DateTime(2026, 10, 3),
                  )
                : null,
          ),
        );
      },
    ),
  ],
);
