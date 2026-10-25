import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

/// The width of a chip in the 2-column grid at 360 dp: (360 - 2 x 12 - 8) / 2.
const _chip = 164.0;

/// A chip plus 8 dp of panel colour around it.
const double _cell = _chip + 16;

void main() {
  ttGoldenTest(
    'Reel chip',
    fileName: 'reel_chip',
    width: _cell,
    scenarios: [
      TtScenario('idle, with cover', _chipOnPanel(cover: fixtureThumb(1))),
      TtScenario('idle, no cover', _chipOnPanel()),
      TtScenario(
        'idle, multi-select',
        _chipOnPanel(cover: fixtureThumb(2), multi: true),
      ),
      TtScenario(
        'picked, multi-select',
        _chipOnPanel(
          cover: fixtureThumb(3),
          multi: true,
          state: TtReelChipState.picked,
        ),
      ),
      TtScenario(
        'done',
        _chipOnPanel(cover: fixtureThumb(4), state: TtReelChipState.done),
      ),
      TtScenario(
        'long name',
        _chipOnPanel(
          cover: fixtureThumb(5),
          name: 'Saturday morning market walk with the whole family',
          count: '1234 clips',
        ),
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
      ),
      TtScenario('image fails to load', _chipOnPanel(cover: brokenImage)),
    ],
  );
}

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
