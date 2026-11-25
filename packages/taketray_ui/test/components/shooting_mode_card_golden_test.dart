import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

/// The width of a full-width card at 360 dp (16 + 328 + 16).
const _full = 328.0;

void main() {
  ttGoldenTest(
    'Shooting mode card',
    fileName: 'shooting_mode_card',
    width: _full,
    // The record dot never settles: decode the pictures, then show it 0.3 s
    // into a pulse.
    pumpBeforeTest: (tester) async {
      await ttDecodeImages(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
    scenarios: [
      const TtScenario(
        'off, nothing waiting',
        _Card(on: false, subtitle: 'Off · turn it on before you film'),
      ),
      const TtScenario(
        'off, 23 waiting',
        _Card(on: false, subtitle: 'Off · 23 clips still to tag'),
      ),
      TtScenario(
        'on, backdrop, both chips',
        _Card(backdrop: fixtureThumb(2), chips: 2),
      ),
      const TtScenario(
        'on, Manual mode, no chips',
        _Card(subtitle: 'Since 9:41 AM · Manual mode'),
      ),
      const TtScenario('on, no backdrop', _Card(chips: 2)),
    ],
  );
}

class _Card extends StatelessWidget {
  const new({
    this.on = true,
    this.subtitle = 'Since 9:41 AM',
    this.backdrop,
    this.chips = 0,
  });

  final bool on;
  final String subtitle;
  final ImageProvider? backdrop;
  final int chips;

  @override
  Widget build(BuildContext context) => TtShootingModeCard(
    on: on,
    title: on ? 'Shooting' : 'Shooting mode',
    subtitle: subtitle,
    semanticLabel: on ? 'Shooting mode, on' : 'Shooting mode, off',
    switchSemanticLabel: 'Shooting mode',
    onChanged: (_) {},
    backdrop: backdrop,
    cameraLabel: 'Open camera',
    onOpenCamera: () {},
    chips: [
      if (chips > 0)
        TtShootingCardChip(
          icon: Symbols.link_rounded,
          label: 'References · 4',
          semanticLabel: 'References, 4, from your Collecting reels',
          onPressed: () {},
        ),
      if (chips > 1)
        TtShootingCardChip(
          icon: Symbols.history_rounded,
          label: 'Earlier videos',
          semanticLabel: 'Add earlier videos, shot before Shooting mode was on',
          onPressed: () {},
        ),
    ],
  );
}
