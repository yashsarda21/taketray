import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtReelPickRow`: a reel in the reel picker sheet.
final WidgetbookComponent ttReelPickRowComponent = WidgetbookComponent(
  name: 'TtReelPickRow',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final name = context.knobs.string(
          label: 'name',
          initialValue: 'Lisbon trip',
        );
        final clips = context.knobs.int.slider(
          label: 'clips',
          initialValue: 12,
          max: 2000,
        );
        final cover = context.knobs.int.slider(
          label: 'cover (0 = none)',
          initialValue: 1,
          max: 12,
        );
        final multi = context.knobs.boolean(
          label: 'several reels (check box)',
          initialValue: true,
        );
        final selected = context.knobs.boolean(label: 'chosen');
        final countText = '$clips clips';
        return ColoredBox(
          color: context.scheme.surfaceContainerLow,
          child: Align(
            alignment: Alignment.topCenter,
            child: TtReelPickRow(
              name: name,
              countText: countText,
              semanticLabel: '$name, $countText',
              selected: selected,
              multi: multi,
              cover: cover == 0 ? null : wbThumb(cover),
              onTap: () {},
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtReelPickNewRow`: the "New reel" row at the top of the picker.
final WidgetbookComponent ttReelPickNewRowComponent = WidgetbookComponent(
  name: 'TtReelPickNewRow',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) => ColoredBox(
        color: context.scheme.surfaceContainerLow,
        child: Align(
          alignment: Alignment.topCenter,
          child: TtReelPickNewRow(
            label: context.knobs.string(
              label: 'label',
              initialValue: 'New reel',
            ),
            onTap: () {},
          ),
        ),
      ),
    ),
  ],
);
