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
        return _ComposedPlayer(
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

/// Every piece of the tag player, laid out as in the prototype's route.
class _ComposedPlayer extends StatelessWidget {
  const new({
    required this.total,
    required this.current,
    required this.multi,
    required this.hasPrevious,
    required this.long,
  });

  final int total;
  final int current;
  final bool multi;
  final bool hasPrevious;
  final bool long;

  @override
  Widget build(BuildContext context) {
    final names = ['Lisbon trip', 'Autumn recipes', 'Summer weekend', 'Garden'];
    return TtVideoSurface(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: context.tt.spacing.xxs),
              child: TtSegmentBar(
                total: total,
                current: current,
                done: {for (var i = 0; i < current; i += 2) i},
              ),
            ),
            TtPlayerHeader(
              leading: TtIconButton(
                icon: Symbols.close_rounded,
                semanticLabel: 'Close tagging',
                style: TtIconButtonStyle.onVideo,
                onPressed: () {},
              ),
              title: '${current + 1} of $total',
              subtitle: 'Scene 2 of 4 · 11:02–11:10 am',
              trailing: TtIconButton(
                icon: Symbols.volume_off_rounded,
                semanticLabel: 'Unmute',
                style: TtIconButtonStyle.onVideo,
                onPressed: () {},
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(context.tt.radii.xl),
                      child: Image(image: wbThumb(2), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    start: 6,
                    child: TtStageArrow(
                      side: TtArrowSide.previous,
                      semanticLabel: 'Previous clip',
                      onPressed: current > 0 ? () {} : null,
                    ),
                  ),
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    end: 6,
                    child: TtStageArrow(
                      side: TtArrowSide.next,
                      semanticLabel: 'Next clip',
                      onPressed: current < total - 1 ? () {} : null,
                    ),
                  ),
                ],
              ),
            ),
            _SeekDemo(long: long),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.tt.spacing.m,
                vertical: context.tt.spacing.s,
              ),
              child: Row(
                spacing: context.tt.spacing.xs,
                children: [
                  TtButton(
                    label: 'Skip',
                    icon: Symbols.redo_rounded,
                    kind: TtButtonKind.ghost,
                    semanticLabel: 'Skip this clip',
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TtSameAsPreviousButton(
                      label: 'Same as previous',
                      detail: hasPrevious ? names.take(3).join(', ') : null,
                      semanticLabel: 'Same as previous',
                      onPressed: hasPrevious ? () {} : null,
                    ),
                  ),
                ],
              ),
            ),
            TtTagPanel(
              title: multi ? 'Pick reels for this clip' : 'Add to reel',
              headerAction: TtButton(
                label: multi ? 'Cancel' : 'Pick several',
                icon: multi ? null : Symbols.library_add_check_rounded,
                kind: TtButtonKind.text,
                size: TtButtonSize.small,
                onPressed: () {},
              ),
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
                    state: multi && i < 2
                        ? TtReelChipState.picked
                        : TtReelChipState.idle,
                    onTap: () {},
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
      large: widget.long,
      hint: widget.long ? 'Drag to skim · 4:32 clip' : null,
      onSeek: (value) => setState(() => _progress = value),
    );
  }
}
