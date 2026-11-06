import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtStepList`: a numbered list of short steps.
final WidgetbookComponent ttStepListComponent = WidgetbookComponent(
  name: 'TtStepList',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'steps',
          initialValue: 3,
          min: 1,
          max: 9,
        );
        final text = context.knobs.string(
          label: 'step text',
          initialValue: 'Tap Never sleeping apps and add TakeTray.',
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtStepList([for (var i = 0; i < count; i++) text]),
        );
      },
    ),
  ],
);
