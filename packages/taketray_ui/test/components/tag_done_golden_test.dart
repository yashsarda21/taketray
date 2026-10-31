import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  // The screen is always dark, so only the dark image is made.
  ttGoldenTest(
    'Tag done',
    fileName: 'tag_done',
    brightnesses: const [Brightness.dark],
    scenarios: [
      TtScenario(
        'reels and skipped',
        _done(const [
          TtTagDoneRow(name: 'Lisbon trip', count: '+5'),
          TtTagDoneRow(name: 'Garden', count: '+2'),
          TtTagDoneRow(name: 'Skipped', count: '3'),
        ]),
      ),
      TtScenario(
        'one reel',
        _done(const [TtTagDoneRow(name: 'Lisbon trip', count: '+12')]),
      ),
      TtScenario('nothing to list', _done(const [])),
      TtScenario(
        'long names',
        _done(const [
          TtTagDoneRow(
            name: 'Saturday morning market walk with the whole family',
            count: '+12',
          ),
          TtTagDoneRow(
            name: 'Autumn recipes from the farm kitchen',
            count: '+3',
          ),
        ]),
      ),
      TtScenario(
        'many reels (scrolls)',
        _done([
          for (var i = 1; i <= 12; i++)
            TtTagDoneRow(name: 'Reel number $i', count: '+$i'),
        ]),
      ),
    ],
  );
}

/// The screen on a phone-sized frame.
Widget _done(List<TtTagDoneRow> rows) => SizedBox(
  height: 780,
  child: TtTagDone(
    title: 'All done!',
    body: '10 clips sorted. Nice work.',
    rows: rows,
    primaryLabel: 'See your reels',
    onPrimary: () {},
    secondaryLabel: 'Back to To tag',
    onSecondary: () {},
  ),
);
