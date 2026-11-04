import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Tag player chrome',
    fileName: 'player_chrome',
    scenarios: [
      TtScenario('segments 5 of 12', _bar(total: 12, current: 4)),
      TtScenario('segments 30 of 120', _bar(total: 120, current: 29)),
      TtScenario('segments, first of 120', _bar(total: 120, current: 0)),
      TtScenario('segments, last of 120', _bar(total: 120, current: 119)),
      TtScenario('segments, a single clip', _bar(total: 1, current: 0)),
      TtScenario(
        'header with close and mute',
        _onVideo(
          _header(title: '5 of 12', subtitle: 'Scene 2 of 4 · 0:12–0:48'),
        ),
      ),
      TtScenario(
        'header, long text',
        _onVideo(
          _header(
            title: 'Saturday morning market walk with the whole family',
            subtitle: 'Scene 12 of 40 · 12:34:56–12:59:59 and a long tail',
          ),
        ),
      ),
      TtScenario(
        'header, subtitle that wraps at large text',
        _onVideo(
          _header(
            title: '5 of 12',
            subtitle: '11:50 AM–12:10 PM and a long tail',
            wrapSubtitle: true,
          ),
        ),
      ),
      TtScenario('arrows enabled', _onVideo(_arrows(enabled: true))),
      TtScenario('arrows disabled', _onVideo(_arrows(enabled: false))),
      TtScenario(
        'scrub at 0 %',
        _onVideo(
          const TtScrubBar(
            progress: 0,
            positionText: '0:00',
            durationText: '0:12',
            semanticLabel: 'Playback position',
            semanticValue: '0:00 of 0:12',
          ),
        ),
      ),
      TtScenario(
        'scrub at 26 %, large, with hint',
        _onVideo(
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: TtScrubBar(
              progress: 0.26,
              positionText: '1:12',
              durationText: '4:32',
              semanticLabel: 'Playback position',
              semanticValue: '1:12 of 4:32',
              large: true,
              hint: 'Drag to skim · 4:32 clip',
            ),
          ),
        ),
      ),
      TtScenario(
        'scrub at 100 %, large',
        _onVideo(
          const TtScrubBar(
            progress: 1,
            positionText: '4:32',
            durationText: '4:32',
            semanticLabel: 'Playback position',
            semanticValue: '4:32 of 4:32',
            large: true,
          ),
        ),
      ),
      TtScenario(
        'scrub, long times',
        _onVideo(
          const TtScrubBar(
            progress: 0.6,
            positionText: '12:34:56',
            durationText: '23:59:59',
            semanticLabel: 'Playback position',
            semanticValue: '12:34:56 of 23:59:59',
          ),
        ),
      ),
    ],
  );
}

Widget _onVideo(Widget child) => TtVideoSurface(child: child);

Widget _bar({required int total, required int current}) => _onVideo(
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: TtSegmentBar(
      total: total,
      current: current,
      done: {for (var i = 0; i < current; i += 2) i},
    ),
  ),
);

Widget _header({
  required String title,
  required String subtitle,
  bool wrapSubtitle = false,
}) => TtPlayerHeader(
  leading: TtIconButton(
    icon: Symbols.close_rounded,
    semanticLabel: 'Close tagging',
    style: TtIconButtonStyle.onVideo,
    onPressed: () {},
  ),
  title: title,
  subtitle: subtitle,
  wrapSubtitle: wrapSubtitle,
  trailing: TtIconButton(
    icon: Symbols.volume_up_rounded,
    semanticLabel: 'Mute',
    style: TtIconButtonStyle.onVideo,
    pressed: true,
    onPressed: () {},
  ),
);

Widget _arrows({required bool enabled}) => Padding(
  padding: const EdgeInsets.all(8),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      TtStageArrow(
        side: TtArrowSide.previous,
        semanticLabel: 'Previous clip',
        onPressed: enabled ? () {} : null,
      ),
      TtStageArrow(
        side: TtArrowSide.next,
        semanticLabel: 'Next clip',
        onPressed: enabled ? () {} : null,
      ),
    ],
  ),
);
