import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

/// Width of a tile in a three-column grid on a 360 dp phone:
/// (360 - 2 x 16 - 2 x 4) / 3, rounded.
const _tileWidth = 107.0;

void main() {
  ttGoldenTest(
    'Clip tile',
    fileName: 'clip_tile',
    scenarios: [
      TtScenario('default', _tile(), width: _tileWidth),
      TtScenario('in 3 reels', _tile(reelCount: 3), width: _tileWidth),
      TtScenario('horizontal', _tile(horizontal: true), width: _tileWidth),
      TtScenario(
        'horizontal, in 2 reels',
        _tile(horizontal: true, reelCount: 2),
        width: _tileWidth,
      ),
      TtScenario(
        'selecting, not selected',
        _tile(selected: false),
        width: _tileWidth,
      ),
      TtScenario(
        'selecting, selected',
        _tile(selected: true, reelCount: 2),
        width: _tileWidth,
      ),
      TtScenario(
        'mark',
        _tile(
          mark: const TtClipMark(
            icon: Symbols.visibility_off_rounded,
            label: 'Skipped',
          ),
        ),
        width: _tileWidth,
      ),
      TtScenario(
        'in the VN folder',
        _tile(vnLabel: 'In VN folder'),
        width: _tileWidth,
      ),
      TtScenario('disabled', _tile(enabled: false), width: _tileWidth),
      TtScenario(
        'broken image',
        _tile(thumbnail: brokenImage),
        width: _tileWidth,
      ),
      TtScenario(
        'long text',
        _tile(
          timeText: '12:41:59 AM tomorrow',
          durationText: '1:02:03',
          reelCount: 12,
          vnLabel: 'In the VN folder already',
        ),
        width: _tileWidth,
      ),
      // The row fills the phone.
      const TtScenario('a grid row', _Row()),
    ],
  );

  ttGoldenTest(
    'Missing clip tile',
    fileName: 'missing_clip_tile',
    scenarios: [
      TtScenario(
        'with Remove',
        TtMissingClipTile(
          label: 'Missing from phone',
          removeLabel: 'Remove',
          onRemove: () {},
        ),
        width: _tileWidth,
      ),
      const TtScenario(
        'without Remove',
        TtMissingClipTile(label: 'Missing from phone'),
        width: _tileWidth,
      ),
      TtScenario(
        'long text',
        TtMissingClipTile(
          label: 'Missing from phone, deleted in the gallery app',
          removeLabel: 'Remove from reel',
          onRemove: () {},
        ),
        width: _tileWidth,
      ),
    ],
  );
}

Widget _tile({
  ImageProvider? thumbnail,
  String timeText = '9:41 AM',
  String durationText = '0:32',
  int reelCount = 1,
  bool horizontal = false,
  bool? selected,
  TtClipMark? mark,
  String? vnLabel,
  bool enabled = true,
}) => TtClipTile(
  thumbnail: thumbnail ?? fixtureThumb(1),
  semanticLabel: 'Clip, $timeText, $durationText',
  timeText: timeText,
  durationText: durationText,
  reelCount: reelCount,
  horizontal: horizontal,
  selected: selected,
  mark: mark,
  vnLabel: vnLabel,
  enabled: enabled,
  onTap: () {},
);

/// Three tiles in a row with the grid's 16 dp gutters and 4 dp gaps.
class _Row extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final spacing = context.tt.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.gutter),
      child: Row(
        spacing: spacing.gridGap,
        children: [
          Expanded(child: _tile(thumbnail: fixtureThumb(2), reelCount: 2)),
          Expanded(child: _tile(thumbnail: fixtureThumb(4), horizontal: true)),
          Expanded(child: _tile(thumbnail: fixtureThumb(5), selected: true)),
        ],
      ),
    );
  }
}
