import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtClipTile`: a clip in a grid, with every badge it can carry.
final WidgetbookComponent ttClipTileComponent = WidgetbookComponent(
  name: 'TtClipTile',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final thumb = context.knobs.int.slider(
          label: 'thumbnail (0 = fails to load)',
          initialValue: 1,
          max: 12,
        );
        final time = context.knobs.string(
          label: 'time',
          initialValue: '9:41 AM',
        );
        final duration = context.knobs.string(
          label: 'duration',
          initialValue: '0:32',
        );
        final reelCount = context.knobs.int.slider(
          label: 'reel count',
          initialValue: 1,
          max: 12,
        );
        final horizontal = context.knobs.boolean(label: 'horizontal');
        final selecting = context.knobs.boolean(label: 'selecting');
        final selected = context.knobs.boolean(label: 'selected');
        final marked = context.knobs.boolean(label: 'mark');
        final markLabel = context.knobs.string(
          label: 'mark label',
          initialValue: 'Skipped',
        );
        final inVn = context.knobs.boolean(label: 'in VN folder');
        final vnLabel = context.knobs.string(
          label: 'VN label',
          initialValue: 'In VN folder',
        );
        final enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        final width = context.knobs.double.slider(
          label: 'width',
          initialValue: 107,
          min: 60,
          max: 240,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: TtClipTile(
                thumbnail: thumb == 0
                    ? MemoryImage(Uint8List(8))
                    : wbThumb(thumb),
                semanticLabel: 'Clip, $time, $duration',
                timeText: time,
                durationText: duration,
                reelCount: reelCount,
                horizontal: horizontal,
                selected: selecting ? selected : null,
                mark: marked
                    ? TtClipMark(
                        icon: Symbols.visibility_off_rounded,
                        label: markLabel,
                      )
                    : null,
                vnLabel: inVn ? vnLabel : null,
                enabled: enabled,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtMissingClipTile`: a clip that is gone from the phone.
final WidgetbookComponent ttMissingClipTileComponent = WidgetbookComponent(
  name: 'TtMissingClipTile',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final label = context.knobs.string(
          label: 'label',
          initialValue: 'Missing from phone',
        );
        final withRemove = context.knobs.boolean(
          label: 'Remove button',
          initialValue: true,
        );
        final removeLabel = context.knobs.string(
          label: 'Remove label',
          initialValue: 'Remove',
        );
        final width = context.knobs.double.slider(
          label: 'width',
          initialValue: 107,
          min: 60,
          max: 240,
        );
        final grown = context.knobs.boolean(
          label: 'height grown for the text (TtMissingClipTile.heightFor)',
        );
        final natural = width / context.tt.sizes.clipTileAspect;
        final needed = grown
            ? TtMissingClipTile.heightFor(
                context,
                width: width,
                label: label,
                removeLabel: withRemove ? removeLabel : null,
              )
            : natural;
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: grown && needed > natural ? needed : null,
              child: TtMissingClipTile(
                label: label,
                removeLabel: withRemove ? removeLabel : null,
                onRemove: () {},
              ),
            ),
          ),
        );
      },
    ),
  ],
);
