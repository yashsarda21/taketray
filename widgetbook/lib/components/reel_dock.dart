import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtReelDock`: the bottom of the full-screen tag player (D-179), over a
/// sample clip: the scrub line, the header with its actions, the reel grid
/// and the footer, on the dock's own scrim.
final WidgetbookComponent ttReelDockComponent = WidgetbookComponent(
  name: 'TtReelDock',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final reels = context.knobs.int.slider(
          label: 'reels (0 = none yet; the grid scrolls past 260 dp)',
          initialValue: 3,
          max: 14,
        );
        final pick = context.knobs.boolean(
          label: 'Pick several (title, actions and footer change)',
        );
        final picked = context.knobs.int.slider(
          label: 'picked reels (Pick several)',
          initialValue: 2,
          max: 14,
        );
        final scrub = context.knobs.boolean(
          label: 'scrub line',
          initialValue: true,
        );
        final photo = context.knobs.int.slider(
          label: 'clip',
          initialValue: 2,
          min: 1,
          max: 12,
        );
        final white = context.knobs.boolean(
          label: 'pure white frame (the worst case)',
        );
        final chips = <Widget>[
          for (var i = 1; i <= reels; i++)
            TtReelChip(
              name: i == 2 ? 'London Food and Drink' : 'Reel $i',
              countText: '${i * 3} clips',
              semanticLabel: 'Add to Reel $i, ${i * 3} clips',
              cover: wbThumb(i),
              state: pick && i <= picked
                  ? TtReelChipState.picked
                  : TtReelChipState.idle,
              multiSelect: pick,
              style: TtReelChipStyle.onVideo,
              onTap: () {},
            ),
          TtNewReelChip(
            title: 'New reel',
            semanticLabel: 'New reel',
            fullWidth: reels == 0,
            style: TtReelChipStyle.onVideo,
            onTap: () {},
          ),
        ];
        TtButton action(String label, IconData? icon) => TtButton(
          label: label,
          icon: icon,
          kind: TtButtonKind.text,
          size: TtButtonSize.small,
          onPressed: () {},
        );
        return TtVideoSurface(
          child: DecoratedBox(
            decoration: white
                ? const BoxDecoration(color: Color(0xFFFFFFFF))
                : BoxDecoration(
                    image: DecorationImage(
                      image: wbThumb(photo),
                      fit: BoxFit.cover,
                    ),
                  ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TtReelDock(
                title: pick ? 'Pick reels' : 'Add to reel',
                semanticLabel: 'Reels',
                chips: chips,
                scrub: scrub
                    ? const TtScrubBar(
                        progress: 0.26,
                        positionText: '1:12',
                        durationText: '4:32',
                        semanticLabel: 'Playback position',
                        semanticValue: '1:12 of 4:32',
                      )
                    : null,
                actions: pick
                    ? [
                        action('All reels', Symbols.apps_rounded),
                        action('Cancel', null),
                      ]
                    : [
                        if (reels >= 2)
                          action(
                            'Pick several',
                            Symbols.library_add_check_rounded,
                          ),
                        if (reels > 3)
                          action('All reels', Symbols.apps_rounded),
                      ],
                emptyText: reels == 0
                    ? "You don't have any reels yet. Create one and this "
                          'clip goes into it.'
                    : null,
                footer: pick
                    ? TtButton(
                        label: 'Add to $picked reels & next',
                        expand: true,
                        onPressed: () {},
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    ),
  ],
);
