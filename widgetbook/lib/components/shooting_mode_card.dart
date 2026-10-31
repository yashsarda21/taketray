import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtShootingModeCard`: off (quiet) or on (the black media hero). The rows
/// show in both (D-90); the to-tag strip and the camera button only on.
final WidgetbookComponent ttShootingModeCardComponent = WidgetbookComponent(
  name: 'TtShootingModeCard',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final on = context.knobs.boolean(label: 'on', initialValue: true);
        final subtitle = context.knobs.string(
          label: 'subtitle',
          initialValue: on
              ? 'On since 9:41 AM'
              : 'Off. Turn on before you start filming, and new videos '
                    'wait in To tag.',
        );
        final backdrop = context.knobs.int.slider(
          label: 'backdrop (0 = none, 13 = fails to load)',
          initialValue: 2,
          max: 13,
        );
        final camera = context.knobs.boolean(
          label: 'camera button',
          initialValue: true,
        );
        final references = context.knobs.boolean(
          label: 'references row',
          initialValue: true,
        );
        final earlier = context.knobs.boolean(
          label: 'add earlier videos row (on and off)',
          initialValue: true,
        );
        final toTag = context.knobs.boolean(
          label: 'to-tag strip',
          initialValue: true,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtShootingModeCard(
            on: on,
            title: on ? 'Shooting mode on' : 'Shooting mode',
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
            rows: [
              if (references)
                TtCardRow(
                  kind: TtCardRowKind.link,
                  icon: Symbols.link_rounded,
                  title: 'References · 4',
                  subtitle: 'From 2 Recording reels',
                  semanticLabel: 'References, 4, from your Recording reels',
                  onPressed: () {},
                ),
              if (earlier)
                TtCardRow(
                  kind: TtCardRowKind.link,
                  icon: Symbols.history_rounded,
                  title: 'Add earlier videos',
                  subtitle: on
                      ? 'Shot before Shooting mode was on'
                      : 'From your camera folder',
                  semanticLabel: on
                      ? 'Add earlier videos, shot before Shooting mode was on'
                      : 'Add earlier videos, from your camera folder',
                  onPressed: () {},
                ),
            ],
            toTagStrip: toTag
                ? TtCardRow(
                    kind: TtCardRowKind.strip,
                    icon: Symbols.sell_rounded,
                    title: '3 clips to tag',
                    trailingText: 'Tag now',
                    onPressed: () {},
                  )
                : null,
          ),
        );
      },
    ),
  ],
);

/// `TtCardRow`: a link row (references) or a to-tag strip (with trailing
/// text), as inside the "on" Shooting mode card.
final WidgetbookComponent ttCardRowComponent = WidgetbookComponent(
  name: 'TtCardRow',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'References · 4',
        );
        final subtitle = context.knobs.string(
          label: 'subtitle',
          initialValue: 'From 2 Recording reels',
        );
        final strip = context.knobs.boolean(
          label: 'to-tag strip (trailing text)',
        );
        final trailing = context.knobs.string(
          label: 'trailing text',
          initialValue: 'Tag now',
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(image: wbThumb(2), fit: BoxFit.cover),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.tt.spacing.xxl),
            child: TtCardRow(
              kind: strip ? TtCardRowKind.strip : TtCardRowKind.link,
              icon: strip ? Symbols.sell_rounded : Symbols.link_rounded,
              title: title,
              subtitle: subtitle.isEmpty ? null : subtitle,
              trailingText: strip ? trailing : null,
              onPressed: () {},
            ),
          ),
        );
      },
    ),
  ],
);
