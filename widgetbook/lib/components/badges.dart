import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtCountBadge`: hidden at 0, the number to 99, then "99+".
final WidgetbookComponent ttCountBadgeComponent = WidgetbookComponent(
  name: 'TtCountBadge',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'count',
          initialValue: 7,
          max: 120,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: Align(
            alignment: Alignment.topLeft,
            child: TtCountBadge(count: count),
          ),
        );
      },
    ),
  ],
);
