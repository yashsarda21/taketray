import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtVideoSurface`: the black, always-dark ground of the tag player, shown
/// on its own and with every piece of the player chrome composed on it.
final WidgetbookComponent ttVideoSurfaceComponent = WidgetbookComponent(
  name: 'TtVideoSurface',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final scrims = context.knobs.boolean(
          label: 'scrims',
          initialValue: true,
        );
        final photo = context.knobs.int.slider(
          label: 'photo (0 = none)',
          initialValue: 2,
          max: 12,
        );
        return TtVideoSurface(
          scrims: scrims,
          child: SizedBox.expand(
            child: photo == 0
                ? null
                : Image(image: wbThumb(photo), fit: BoxFit.cover),
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'Tag player (composed)',
      builder: (context) {
        final total = context.knobs.int.slider(
          label: 'clips',
          initialValue: 12,
          min: 1,
          max: 150,
        );
        final current = context.knobs.int.slider(
          label: 'current clip',
          initialValue: 4,
          max: 149,
        );
        final multi = context.knobs.boolean(label: 'Pick several');
        final hasPrevious = context.knobs.boolean(
          label: 'has previous reels',
          initialValue: true,
        );
        final long = context.knobs.boolean(label: 'long clip (large scrub)');
        final allReels = context.knobs.boolean(
          label: 'All reels (a reel outside the dock)',
        );
        return _ComposedPlayer(
          allReels: allReels,
          total: total,
          current: current.clamp(0, total - 1),
          multi: multi,
          hasPrevious: hasPrevious,
          long: long,
        );
      },
    ),
  ],
);

/// Every piece of the tag player, laid out as in the full-screen route
/// (D-181): the clip over the whole screen, the top on its scrim, the dock
/// at the bottom, and the rail of Skip and Same 4 dp above it.
class _ComposedPlayer extends StatelessWidget {
  const new({
    required this.total,
    required this.current,
    required this.multi,
    required this.hasPrevious,
    required this.long,
    required this.allReels,
  });

  final int total;
  final int current;
  final bool multi;
  final bool hasPrevious;
  final bool long;
  final bool allReels;

  @override
  Widget build(BuildContext context) {
    final names = ['Lisbon trip', 'Autumn recipes', 'Summer weekend'];
    final tt = context.tt;
    final dock = TtReelDock(
      semanticLabel: 'Reels',
      title: multi ? 'Pick reels' : 'Add to reel',
      scrub: _SeekDemo(long: long),
      actions: [
        if (!multi)
          TtButton(
            label: 'Pick several',
            icon: Symbols.library_add_check_rounded,
            kind: TtButtonKind.text,
            size: TtButtonSize.small,
            onPressed: () {},
          ),
        if (allReels)
          TtButton(
            label: 'All reels',
            icon: Symbols.apps_rounded,
            kind: TtButtonKind.text,
            size: TtButtonSize.small,
            onPressed: () {},
          ),
        if (multi)
          TtButton(
            label: 'Cancel',
            kind: TtButtonKind.text,
            size: TtButtonSize.small,
            onPressed: () {},
          ),
      ],
      footer: multi
          ? TtButton(
              label: 'Add to 2 reels & next',
              expand: true,
              onPressed: () {},
            )
          : null,
      chips: [
        for (var i = 0; i < names.length; i++)
          TtReelChip(
            name: names[i],
            countText: '${14 - i * 3} clips',
            semanticLabel: 'Add to ${names[i]}',
            cover: i == 2 ? null : wbThumb(1 + i),
            multiSelect: multi,
            style: TtReelChipStyle.onVideo,
            state: multi && i < 2
                ? TtReelChipState.picked
                : TtReelChipState.idle,
            onTap: () {},
          ),
        if (!multi)
          TtNewReelChip(
            title: 'New reel',
            subtitle: 'Add this clip to it',
            style: TtReelChipStyle.onVideo,
            onTap: () {},
          ),
      ],
    );
    return TtVideoSurface(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: wbThumb(2), fit: BoxFit.cover),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TtPlayerTopScrim(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + tt.spacing.xxs,
                  bottom: TtMetrics.playerTopScrimFade,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TtSegmentBar(
                      total: total,
                      current: current,
                      done: {for (var i = 0; i < current; i += 2) i},
                    ),
                    TtPlayerHeader(
                      leading: TtIconButton(
                        icon: Symbols.close_rounded,
                        semanticLabel: 'Close tagging',
                        style: TtIconButtonStyle.onVideo,
                        onPressed: () {},
                      ),
                      previous: TtHeaderChevron(
                        semanticLabel: 'Previous clip',
                        onPressed: current > 0 ? () {} : null,
                      ),
                      title: '${current + 1} of $total',
                      subtitle: 'Scene 2 of 4 · 11:02–11:10 am',
                      wrapSubtitle: true,
                      next: TtHeaderChevron(
                        semanticLabel: 'Next clip',
                        onPressed: current < total - 1 ? () {} : null,
                      ),
                      trailing: TtIconButton(
                        icon: Symbols.volume_off_rounded,
                        semanticLabel: 'Unmute',
                        style: TtIconButtonStyle.onVideo,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: dock),
          if (!multi)
            // The rail sits 4 dp above the dock: a fixed guess of the dock's
            // height here (the app measures it).
            PositionedDirectional(
              end: TtMetrics.railInsetEnd,
              bottom: _dockGuess + TtMetrics.railAboveDock,
              child: Column(
                spacing: TtMetrics.railGap,
                children: [
                  TtRailButton(
                    icon: Symbols.redo_rounded,
                    label: 'Skip',
                    semanticLabel: 'Skip this clip',
                    onPressed: () {},
                  ),
                  TtRailButton(
                    icon: Symbols.repeat_rounded,
                    label: 'Same',
                    detail: hasPrevious ? names.take(2).join(', ') : null,
                    semanticLabel: hasPrevious
                        ? 'Same as previous: ${names.take(2).join(', ')}'
                        : 'Same as previous: nothing tagged yet',
                    onPressed: hasPrevious ? () {} : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// About the dock's height at 1x with a scrub line, the header and two rows
/// of chips, for the catalog's rail.
const double _dockGuess = 246;

/// A scrub bar that follows the finger.
class _SeekDemo extends StatefulWidget {
  const new({required this.long});

  final bool long;

  @override
  State<_SeekDemo> createState() => _SeekDemoState();
}

class _SeekDemoState extends State<_SeekDemo> {
  double _progress = 0.26;

  @override
  Widget build(BuildContext context) {
    return TtScrubBar(
      progress: _progress,
      positionText: widget.long ? '1:12' : '0:03',
      durationText: widget.long ? '4:32' : '0:12',
      semanticLabel: 'Playback position',
      semanticValue: widget.long ? '1:12 of 4:32' : '0:03 of 0:12',
      semanticIncreasedValue: '5 percent later',
      semanticDecreasedValue: '5 percent earlier',
      large: widget.long,
      hint: widget.long ? 'Drag to skim · 4:32 clip' : null,
      onSeek: (value) => setState(() => _progress = value),
    );
  }
}
