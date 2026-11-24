import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// A button, a gap and 8 dp of the clip around it.
const double _cell = 96;

/// Wide enough for the 2x button with its detail (about 120 dp).
const double _largeCell = 152;

void main() {
  // The player is always dark, so there is only a dark golden.
  ttGoldenTest(
    'Rail button',
    fileName: 'rail_button',
    brightnesses: const [Brightness.dark],
    width: _cell,
    scenarios: [
      TtScenario(
        'Skip',
        _onClip(
          TtRailButton(
            icon: Symbols.redo_rounded,
            label: 'Skip',
            semanticLabel: 'Skip this clip',
            onPressed: () {},
          ),
        ),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'Same, with the reel names',
        _onClip(_same(detail: 'London Food')),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'Same, a short name',
        _onClip(_same(detail: 'Paris')),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'Same, off: nothing tagged yet',
        _onClip(_same(enabled: false)),
        largeWidth: _largeCell,
      ),
      TtScenario(
        'Same, names that are cut',
        _onClip(_same(detail: 'London Food, Paris Trip, Rome')),
        largeWidth: _largeCell,
      ),
    ],
  );
}

Widget _same({String? detail, bool enabled = true}) => TtRailButton(
  icon: Symbols.repeat_rounded,
  label: 'Same',
  detail: detail,
  semanticLabel: detail == null
      ? 'Same as previous: nothing tagged yet'
      : 'Same as previous: $detail',
  onPressed: enabled ? () {} : null,
);

/// [child] over a stand-in for the clip: a warm to cool gradient with a white
/// and a black bar behind the button, so its blur and its fill show.
Widget _onClip(Widget child) => DecoratedBox(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE8873A), Color(0xFF2F8F83), Color(0xFF3B4C9B)],
    ),
  ),
  child: Stack(
    children: [
      const Positioned(
        left: 20,
        top: 0,
        bottom: 0,
        width: 10,
        child: ColoredBox(color: Color(0xFFFFFFFF)),
      ),
      const Positioned(
        left: 44,
        top: 0,
        bottom: 0,
        width: 6,
        child: ColoredBox(color: Color(0xFF000000)),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ],
  ),
);
