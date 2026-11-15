import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtStatusLayout`: a whole-screen status with its buttons at the bottom.
final WidgetbookComponent ttStatusLayoutComponent = WidgetbookComponent(
  name: 'TtStatusLayout',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final tone = context.knobs.object.dropdown<TtStatusTone>(
          label: 'tone',
          options: TtStatusTone.values,
          initialOption: TtStatusTone.error,
          labelBuilder: (tone) => tone.name,
        );
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Phone storage is full',
        );
        final body = context.knobs.string(
          label: 'body (empty for none)',
          initialValue:
              '7 of 12 clips were copied before space ran out. Free up some '
              'space, then try again.',
        );
        final actions = context.knobs.int.slider(
          label: 'buttons',
          initialValue: 2,
          max: 3,
        );
        return TtStatusLayout(
          icon: switch (tone) {
            TtStatusTone.primary => Symbols.folder_copy_rounded,
            TtStatusTone.error => Symbols.sd_card_alert_rounded,
            TtStatusTone.warning => Symbols.warning_rounded,
            TtStatusTone.success => Symbols.check_circle_rounded,
          },
          tone: tone,
          title: title,
          body: body.isEmpty ? null : Text(body),
          actions: [
            if (actions > 0)
              TtButton(label: 'Try again', expand: true, onPressed: () {}),
            if (actions > 1)
              TtButton(
                label: 'Delete copies and stop',
                kind: TtButtonKind.text,
                expand: true,
                onPressed: () {},
              ),
            if (actions > 2)
              TtButton(
                label: 'Cancel',
                kind: TtButtonKind.outlined,
                expand: true,
                onPressed: () {},
              ),
          ],
        );
      },
    ),
  ],
);
