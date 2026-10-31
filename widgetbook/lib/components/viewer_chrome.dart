import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtReelTag`: the chip naming a reel on the clip viewer.
final WidgetbookComponent ttReelTagComponent = WidgetbookComponent(
  name: 'TtReelTag / TtReelTagRow',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'reels',
          initialValue: 2,
          min: 1,
          max: 6,
        );
        const names = [
          'Lisbon trip',
          'London Food',
          'Autumn recipes',
          'Saturday morning market walk',
          'Trams',
          'Rooftops',
        ];
        return TtVideoSurface(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: context.tt.spacing.xl),
              child: TtReelTagRow(
                label: 'In',
                names: names.take(count).toList(),
              ),
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtViewerActions`: the icon-over-label action bar under a clip.
final WidgetbookComponent ttViewerActionsComponent = WidgetbookComponent(
  name: 'TtViewerActions',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final four = context.knobs.boolean(label: 'four actions');
        final actions = [
          TtViewerAction(
            icon: Symbols.library_add_rounded,
            label: 'Add to reel',
            onPressed: () {},
          ),
          TtViewerAction(
            icon: Symbols.drive_file_move_rounded,
            label: 'Move',
            onPressed: () {},
          ),
          TtViewerAction(
            icon: Symbols.playlist_remove_rounded,
            label: 'Remove',
            onPressed: () {},
          ),
          if (four)
            TtViewerAction(
              icon: Symbols.share_rounded,
              label: 'Share',
              onPressed: () {},
            ),
        ];
        return TtVideoSurface(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: context.tt.spacing.xl),
              child: TtViewerActions(actions: actions),
            ),
          ),
        );
      },
    ),
  ],
);
