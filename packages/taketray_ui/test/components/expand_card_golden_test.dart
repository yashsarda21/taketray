import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The width of a card in a page with 16 dp margins.
const _card = 328.0;

const _samsung = [
  'Open Settings › Battery › Background usage limits.',
  'Tap Never sleeping apps and add TakeTray.',
  'If TakeTray is under Sleeping apps, remove it.',
];

TtExpandCard _samsungCard({required bool expanded, String? badge}) =>
    TtExpandCard(
      title: 'Samsung',
      badge: badge,
      expanded: expanded,
      onToggle: () {},
      // The theme's spacing, not a raw number (D-102 item 4: 12 dp).
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: context.tt.spacing.s,
          children: [
            const TtStepList(_samsung),
            TtButton(
              label: 'Open battery settings',
              icon: Symbols.open_in_new_rounded,
              kind: TtButtonKind.tonal,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

void main() {
  ttGoldenTest(
    'Expandable card and step list',
    fileName: 'expand_card',
    scenarios: [
      TtScenario('collapsed', _samsungCard(expanded: false), width: _card),
      TtScenario(
        'collapsed, badge',
        _samsungCard(expanded: false, badge: 'Your phone'),
        width: _card,
      ),
      TtScenario(
        'expanded, badge, steps and button',
        _samsungCard(expanded: true, badge: 'Your phone'),
        width: _card,
      ),
      TtScenario(
        'expanded, long title and badge',
        TtExpandCard(
          title: 'Xiaomi, Redmi, POCO',
          badge: 'Your phone',
          expanded: true,
          onToggle: () {},
          child: const TtStepList([
            'Long-press the TakeTray icon › App info.',
            'Turn on Autostart.',
            'Tap Battery saver › No restrictions.',
          ]),
        ),
        width: _card,
      ),
      const TtScenario(
        'step list on its own',
        TtStepList(_samsung),
        width: _card,
      ),
    ],
  );
}
