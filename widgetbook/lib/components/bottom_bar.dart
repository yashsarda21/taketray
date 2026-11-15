import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtBottomBar`: what is picked, and the button that goes on.
final WidgetbookComponent ttBottomBarComponent = WidgetbookComponent(
  name: 'TtBottomBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: '3 videos picked',
        );
        final subtitle = context.knobs.string(
          label: 'subtitle',
          initialValue: '1 min 20 s · added in shooting order',
        );
        final label = context.knobs.string(
          label: 'button',
          initialValue: 'Add 3',
        );
        final enabled = context.knobs.boolean(
          label: 'button on',
          initialValue: true,
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: TtBottomBar(
            title: title,
            subtitle: subtitle,
            action: TtButton(label: label, onPressed: enabled ? () {} : null),
          ),
        );
      },
    ),
  ],
);
