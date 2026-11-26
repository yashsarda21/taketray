import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtSegmentBar`: the per-clip progress bar along the top of the tag player.
final WidgetbookComponent ttSegmentBarComponent = WidgetbookComponent(
  name: 'TtSegmentBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final total = context.knobs.int.slider(
          label: 'clips (above 40 it collapses to 3 segments)',
          initialValue: 12,
          min: 1,
          max: 150,
        );
        final current = context.knobs.int.slider(
          label: 'current clip',
          initialValue: 4,
          max: 149,
        );
        final step = context.knobs.int.slider(
          label: 'every n-th clip before current is done',
          initialValue: 2,
          min: 1,
          max: 5,
        );
        final at = current.clamp(0, total - 1);
        return TtVideoSurface(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: context.tt.spacing.xl),
              child: TtSegmentBar(
                total: total,
                current: at,
                done: {for (var i = 0; i < at; i += step) i},
              ),
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtPlayerHeader`: the close button, clip counter and mute button above the
/// video.
final WidgetbookComponent ttPlayerHeaderComponent = WidgetbookComponent(
  name: 'TtPlayerHeader',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: '5 of 12',
        );
        final withSubtitle = context.knobs.boolean(
          label: 'subtitle',
          initialValue: true,
        );
        final subtitle = context.knobs.string(
          label: 'subtitle text',
          initialValue: 'Scene 2 of 4 · 11:02–11:10 am',
        );
        final withTrailing = context.knobs.boolean(
          label: 'trailing control',
          initialValue: true,
        );
        final muted = context.knobs.boolean(label: 'muted');
        final wrap = context.knobs.boolean(
          label: 'subtitle wraps (never cut)',
          initialValue: true,
        );
        final chevrons = context.knobs.object.dropdown<_ChevronState>(
          label: 'previous / next chevrons',
          options: _ChevronState.values,
          labelBuilder: (v) => v.label,
        );
        return TtVideoSurface(
          child: Align(
            alignment: Alignment.topCenter,
            child: TtPlayerHeader(
              leading: TtIconButton(
                icon: Symbols.close_rounded,
                semanticLabel: 'Close tagging',
                style: TtIconButtonStyle.onVideo,
                onPressed: () {},
              ),
              title: title,
              subtitle: withSubtitle ? subtitle : null,
              wrapSubtitle: wrap,
              previous: chevrons.hasPrevious
                  ? TtHeaderChevron(
                      semanticLabel: 'Previous clip',
                      onPressed: chevrons.previousOn ? () {} : null,
                    )
                  : null,
              next: chevrons.hasNext
                  ? TtHeaderChevron(
                      semanticLabel: 'Next clip',
                      onPressed: chevrons.nextOn ? () {} : null,
                    )
                  : null,
              trailing: withTrailing
                  ? TtIconButton(
                      icon: muted
                          ? Symbols.volume_off_rounded
                          : Symbols.volume_up_rounded,
                      semanticLabel: muted ? 'Unmute' : 'Mute',
                      style: TtIconButtonStyle.onVideo,
                      pressed: !muted,
                      onPressed: () {},
                    )
                  : null,
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtStageArrow`: the round previous and next arrows at the sides of the
/// video.
final WidgetbookComponent ttStageArrowComponent = WidgetbookComponent(
  name: 'TtStageArrow',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final side = context.knobs.object.dropdown<TtArrowSide>(
          label: 'side',
          options: TtArrowSide.values,
          labelBuilder: (v) => v.name,
        );
        final enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        return TtVideoSurface(
          child: Center(
            child: TtStageArrow(
              side: side,
              semanticLabel: side == TtArrowSide.previous
                  ? 'Previous clip'
                  : 'Next clip',
              onPressed: enabled ? () {} : null,
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtScrubBar`: the seek bar under the video. Drag or tap to move it.
final WidgetbookComponent ttScrubBarComponent = WidgetbookComponent(
  name: 'TtScrubBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final progress = context.knobs.double.slider(
          label: 'progress (clamped to 0..1)',
          initialValue: 0.26,
          min: -0.2,
          max: 1.4,
        );
        final large = context.knobs.boolean(label: 'large');
        final hint = context.knobs.boolean(label: 'hint');
        final position = context.knobs.string(
          label: 'position',
          initialValue: '1:12',
        );
        final duration = context.knobs.string(
          label: 'duration',
          initialValue: '4:32',
        );
        final seekable = context.knobs.boolean(
          label: 'seekable (drag and tap)',
          initialValue: true,
        );
        return TtVideoSurface(
          child: Center(
            child: _Seekable(
              // A new knob value restarts the demo from it.
              key: ValueKey(progress),
              initial: progress,
              builder: (value, onSeek) => TtScrubBar(
                progress: value,
                positionText: position,
                durationText: duration,
                semanticLabel: 'Playback position',
                semanticValue: '$position of $duration',
                semanticIncreasedValue: '5 percent later',
                semanticDecreasedValue: '5 percent earlier',
                large: large,
                hint: hint ? 'Drag to skim · $duration clip' : null,
                onSeek: seekable ? onSeek : null,
              ),
            ),
          ),
        );
      },
    ),
  ],
);

/// Holds the progress so a drag moves the bar.
class _Seekable extends StatefulWidget {
  const new({required this.initial, required this.builder, super.key});

  final double initial;
  final Widget Function(double value, ValueChanged<double> onSeek) builder;

  @override
  State<_Seekable> createState() => _SeekableState();
}

class _SeekableState extends State<_Seekable> {
  late double _value = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(_value, (v) => setState(() => _value = v));
}

/// How the header's two chevrons look in the playground.
enum _ChevronState {
  none('none (the clip viewer)'),
  both(
    'both on',
    hasPrevious: true,
    previousOn: true,
    hasNext: true,
    nextOn: true,
  ),
  firstClip(
    'first clip: Previous off',
    hasPrevious: true,
    hasNext: true,
    nextOn: true,
  ),
  lastClip(
    'last clip: Next off',
    hasPrevious: true,
    previousOn: true,
    hasNext: true,
  );

  new(
    this.label, {
    this.hasPrevious = false,
    this.previousOn = false,
    this.hasNext = false,
    this.nextOn = false,
  });

  final String label;
  final bool hasPrevious;
  final bool previousOn;
  final bool hasNext;
  final bool nextOn;
}

/// `TtPlayerTopScrim`: the dark gradient behind the tag player's top bar
/// (78 %, then 70 % until 24 dp above its bottom, then clear), over a bright
/// sample clip.
final WidgetbookComponent ttPlayerTopScrimComponent = WidgetbookComponent(
  name: 'TtPlayerTopScrim',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final photo = context.knobs.int.slider(
          label: 'clip',
          initialValue: 2,
          min: 1,
          max: 12,
        );
        final white = context.knobs.boolean(
          label: 'pure white frame (the worst case)',
        );
        final top = context.knobs.double.slider(
          label: 'top padding (the status bar)',
          initialValue: 34,
          max: 60,
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
              alignment: Alignment.topCenter,
              child: TtPlayerTopScrim(
                child: Padding(
                  padding: EdgeInsets.only(top: top, bottom: 24),
                  child: TtPlayerHeader(
                    leading: TtIconButton(
                      icon: Symbols.close_rounded,
                      semanticLabel: 'Close tagging',
                      style: TtIconButtonStyle.onVideo,
                      onPressed: () {},
                    ),
                    title: '5 of 12',
                    subtitle: 'Scene 2 of 4 · 11:02–11:10 am',
                    wrapSubtitle: true,
                    previous: TtHeaderChevron(
                      semanticLabel: 'Previous clip',
                      onPressed: () {},
                    ),
                    next: TtHeaderChevron(
                      semanticLabel: 'Next clip',
                      onPressed: () {},
                    ),
                    trailing: TtIconButton(
                      icon: Symbols.volume_up_rounded,
                      semanticLabel: 'Mute',
                      style: TtIconButtonStyle.onVideo,
                      onPressed: () {},
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
