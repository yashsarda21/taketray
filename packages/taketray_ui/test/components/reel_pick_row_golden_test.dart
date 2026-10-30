import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

Widget _row({
  String name = 'Lisbon trip',
  String count = '12 clips',
  bool selected = false,
  bool multi = true,
  ImageProvider? cover,
}) => TtReelPickRow(
  name: name,
  countText: count,
  semanticLabel: '$name, $count',
  selected: selected,
  multi: multi,
  cover: cover,
  onTap: () {},
);

void main() {
  ttGoldenTest(
    'Reel pick row',
    fileName: 'reel_pick_row',
    scenarios: [
      TtScenario('multi, not chosen', _row(cover: fixtureThumb(1))),
      TtScenario('multi, chosen', _row(cover: fixtureThumb(2), selected: true)),
      TtScenario(
        'single, not chosen, no cover',
        _row(name: 'London Food', multi: false),
      ),
      TtScenario(
        'single, chosen',
        _row(cover: fixtureThumb(3), multi: false, selected: true),
      ),
      TtScenario(
        'long name',
        _row(
          name: 'Saturday morning market walk with the whole family',
          count: '1 clip',
          cover: fixtureThumb(4),
          selected: true,
        ),
      ),
      TtScenario(
        'new reel row',
        TtReelPickNewRow(label: 'New reel', onTap: () {}),
      ),
    ],
  );
}
