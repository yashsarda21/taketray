import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtRecDot`: pulses while live, unless animations are removed.
final WidgetbookComponent ttRecDotComponent = WidgetbookComponent(
  name: 'TtRecDot',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final live = context.knobs.boolean(label: 'live', initialValue: true);
        final reduced = context.knobs.boolean(label: 'animations removed');
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: Padding(
            padding: EdgeInsets.all(context.tt.spacing.xl),
            child: Align(
              alignment: Alignment.topLeft,
              child: TtRecDot(live: live),
            ),
          ),
        );
      },
    ),
  ],
);
