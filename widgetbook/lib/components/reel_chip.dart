import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtReelChip`: a reel in the tag panel, tapped to tag the clip.
final WidgetbookComponent ttReelChipComponent = WidgetbookComponent(
  name: 'TtReelChip',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final name = context.knobs.string(
          label: 'name',
          initialValue: 'Lisbon trip',
        );
        final count = context.knobs.int.slider(
          label: 'clips',
          initialValue: 12,
          max: 2000,
        );
        final cover = context.knobs.int.slider(
          label: 'cover (0 = none, 13 = fails to load)',
          initialValue: 1,
          max: 13,
        );
        final state = context.knobs.object.dropdown<TtReelChipState>(
          label: 'state',
          options: TtReelChipState.values,
          labelBuilder: (v) => v.name,
        );
        final multi = context.knobs.boolean(label: 'multi-select');
        final width = context.knobs.double.slider(
          label: 'width (164 in the panel)',
          initialValue: 164,
          min: 100,
          max: 328,
        );
        final countText = '$count clips';
        return TtVideoSurface(
          child: Builder(
            builder: (context) => ColoredBox(
              color: context.scheme.surfaceContainer,
              child: Padding(
                padding: EdgeInsets.all(context.tt.spacing.m),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: TtReelChip(
                      name: name,
                      countText: countText,
                      semanticLabel: 'Add to $name, $countText',
                      cover: switch (cover) {
                        0 => null,
                        13 => MemoryImage(Uint8List(8)),
                        _ => wbThumb(cover),
                      },
                      state: state,
                      multiSelect: multi,
                      onTap: () {},
                      onLongPress: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ],
);
