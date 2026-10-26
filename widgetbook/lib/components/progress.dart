import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtProgressBar`: determinate (a share of the work) or indeterminate.
final WidgetbookComponent ttProgressBarComponent = WidgetbookComponent(
  name: 'TtProgressBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final indeterminate = context.knobs.boolean(label: 'indeterminate');
        final percent = context.knobs.int.slider(
          label: 'percent',
          initialValue: 40,
          max: 100,
        );
        final label = context.knobs.string(
          label: 'label (empty for none)',
          initialValue: '7 of 12 clips',
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtProgressBar(
            value: indeterminate ? null : percent / 100,
            label: label.isEmpty ? null : label,
          ),
        );
      },
    ),
  ],
);
