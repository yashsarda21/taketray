import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

const _items = [
  TtMenuItem<TtStatusKind>(
    TtStatusKind.collecting,
    'Collecting',
    icon: Symbols.radio_button_checked_rounded,
    iconFilled: true,
    subtitle: 'Still shooting clips for it',
    checked: true,
  ),
];

const _long =
    'Open on the tram, then the market stalls. Get the fish counter, the '
    'tile shop and the street musician. End on the view from the castle '
    'at golden hour, with the whole city below.';

Widget _header({
  String name = 'Lisbon trip',
  TtStatusKind kind = TtStatusKind.collecting,
  String label = 'Collecting',
  String meta = '12 clips · 4:32',
  String? missing,
  String? ideas,
  bool open = false,
}) => TtReelHeader<TtStatusKind>(
  name: name,
  statusKind: kind,
  statusLabel: label,
  statusSemanticLabel: 'Status: $label. Change',
  statusItems: _items,
  onStatusSelected: (_) {},
  metaText: meta,
  missingText: missing,
  shotIdeas: ideas,
  shotIdeasTitle: ideas == null ? null : 'Shot ideas',
  showMoreLabel: ideas == null ? null : 'Show more',
  showLessLabel: ideas == null ? null : 'Show less',
  shotIdeasOpen: open,
);

void main() {
  ttGoldenTest(
    'Reel header',
    fileName: 'reel_header',
    scenarios: [
      TtScenario(
        'collecting, short ideas (no button)',
        _header(ideas: 'Market stalls, the tram, the view from the castle.'),
      ),
      TtScenario(
        'ready, long ideas folded',
        _header(kind: TtStatusKind.ready, label: 'Ready to edit', ideas: _long),
      ),
      TtScenario(
        'published, long ideas open, 2 missing',
        _header(
          kind: TtStatusKind.published,
          label: 'Published',
          missing: '2 missing',
          ideas: _long,
          open: true,
        ),
      ),
      TtScenario('no ideas, no clips yet', _header(meta: 'No clips yet')),
      TtScenario(
        'long name wraps',
        _header(
          name: 'Saturday morning market walk with the whole family',
          missing: '12 missing',
        ),
      ),
    ],
  );
}
