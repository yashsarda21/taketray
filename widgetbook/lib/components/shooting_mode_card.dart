import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtShootingModeCard`: off (one quiet row) or on (the black card with Open
/// camera and up to two glass chips). Toggle `on` to see the height and the
/// chips animate.
final WidgetbookComponent ttShootingModeCardComponent = WidgetbookComponent(
  name: 'TtShootingModeCard / TtShootingCardChip',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final on = context.knobs.boolean(label: 'on', initialValue: true);
        final subtitle = context.knobs.string(
          label: 'subtitle',
          initialValue: on
              ? 'Since 9:41 AM'
              : 'Off · turn it on before you film',
        );
        final backdrop = context.knobs.int.slider(
          label: 'backdrop (0 = none, 13 = fails to load)',
          initialValue: 2,
          max: 13,
        );
        final camera = context.knobs.boolean(
          label: 'Open camera',
          initialValue: true,
        );
        final references = context.knobs.boolean(
          label: 'References chip',
          initialValue: true,
        );
        final earlier = context.knobs.boolean(
          label: 'Earlier videos chip',
          initialValue: true,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtShootingModeCard(
            on: on,
            title: on ? 'Shooting' : 'Shooting mode',
            subtitle: subtitle,
            semanticLabel: on ? 'Shooting mode, on' : 'Shooting mode, off',
            switchSemanticLabel: 'Shooting mode',
            onChanged: (_) {},
            backdrop: switch (backdrop) {
              0 => null,
              13 => MemoryImage(Uint8List(8)),
              _ => wbThumb(backdrop),
            },
            cameraLabel: camera ? 'Open camera' : null,
            onOpenCamera: () {},
            chips: [
              if (references)
                TtShootingCardChip(
                  icon: Symbols.link_rounded,
                  label: 'References · 4',
                  semanticLabel: 'References, 4, from your Collecting reels',
                  onPressed: () {},
                ),
              if (earlier)
                TtShootingCardChip(
                  icon: Symbols.history_rounded,
                  label: 'Earlier videos',
                  semanticLabel:
                      'Add earlier videos, shot before Shooting mode was on',
                  onPressed: () {},
                ),
            ],
          ),
        );
      },
    ),
  ],
);
