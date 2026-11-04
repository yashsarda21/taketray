import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

/// The width of a chip in the 2-column grid at 360 dp: (360 - 2 x 12 - 8) / 2.
const _chip = 164.0;

/// A chip plus 8 dp of panel colour around it.
const double _cell = _chip + 16;

/// At 2x text the panel gives each chip a whole row: 360 - 2 x 12, plus the
/// same 8 dp of panel colour around it (D-47, D-93).
const double _largeCell = 336 + 16;

void main() {
  ttGoldenTest(
    'Reel chip',
    fileName: 'reel_chip',
    width: _cell,
    scenarios: [
      TtScenario(
        'idle, with cover',
        _chipOnPanel(cover: fixtureThumb(1)),
        largeWidth: _largeCell,
      ),
      TtScenario('idle, no cover', _chipOnPanel(), largeWidth: _largeCell),
      TtScenario(
        'idle, multi-select',
        _chipOnPanel(cover: fixtureThumb(2), multi: true),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'picked, multi-select',
        _chipOnPanel(
          cover: fixtureThumb(3),
          multi: true,
          state: TtReelChipState.picked,
        ),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'done',
        _chipOnPanel(cover: fixtureThumb(4), state: TtReelChipState.done),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'long name',
        _chipOnPanel(
          cover: fixtureThumb(5),
          name: 'Saturday morning market walk with the whole family',
          count: '1234 clips',
        ),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'long name, picked, multi-select',
        _chipOnPanel(
          cover: fixtureThumb(6),
          name: 'Saturday morning market walk with the whole family',
          count: '1234 clips',
          multi: true,
          state: TtReelChipState.picked,
        ),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'image fails to load',
        _chipOnPanel(cover: brokenImage),
        largeWidth: _largeCell,
      ),
    ],
  );

  ttGoldenTest(
    'New reel chip',
    fileName: 'new_reel_chip',
    width: _cell,
    scenarios: [
      TtScenario(
        'with subtitle',
        _newChipOnPanel(subtitle: 'Add this clip to it'),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'long title',
        _newChipOnPanel(
          title: 'Make a brand new reel for this clip',
          subtitle: 'Add this clip to it right away',
        ),
        largeWidth: _largeCell,
      ),
      // The no-reels panel: the chip takes the panel's whole row (336 dp).
      TtScenario(
        'full width, no subtitle',
        _newChipOnPanel(fullWidth: true),
        width: _largeCell,
      ),
    ],
  );
}

Widget _newChipOnPanel({
  String title = 'New reel',
  String? subtitle,
  bool fullWidth = false,
}) => TtVideoSurface(
  child: Builder(
    builder: (context) => ColoredBox(
      color: context.scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TtNewReelChip(
          title: title,
          subtitle: subtitle,
          fullWidth: fullWidth,
          onTap: () {},
        ),
      ),
    ),
  ),
);

Widget _chipOnPanel({
  ImageProvider? cover,
  String name = 'Lisbon trip',
  String count = '12 clips',
  bool multi = false,
  TtReelChipState state = TtReelChipState.idle,
}) => TtVideoSurface(
  child: Builder(
    builder: (context) => ColoredBox(
      color: context.scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TtReelChip(
          name: name,
          countText: count,
          semanticLabel: 'Add to $name, $count',
          cover: cover,
          state: state,
          multiSelect: multi,
          onTap: () {},
        ),
      ),
    ),
  ),
);
