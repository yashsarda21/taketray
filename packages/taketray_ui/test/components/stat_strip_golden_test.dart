import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Stat strip',
    fileName: 'stat_strip',
    // The live dot never settles: show it 0.3 s into a pulse.
    pumpBeforeTest: (tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
    scenarios: [
      TtScenario(
        'live (record dot)',
        TtStatStrip(
          leading: const TtRecDot(compact: true),
          text: 'Shooting since 9:41 AM',
          action: TtButton(
            label: 'Open camera',
            icon: Symbols.videocam_rounded,
            kind: TtButtonKind.text,
            onPressed: () {},
          ),
        ),
      ),
      TtScenario(
        'muted',
        TtStatStrip(
          leading: const Icon(Symbols.videocam_off_rounded),
          text: 'Shooting mode off',
          muted: true,
          action: TtButton(
            label: 'Turn on',
            kind: TtButtonKind.text,
            onPressed: () {},
          ),
        ),
      ),
      const TtScenario(
        'without an action',
        TtStatStrip(
          leading: TtRecDot(compact: true),
          text: 'Shooting since 9:41 AM',
        ),
      ),
      TtScenario(
        'long text',
        TtStatStrip(
          leading: const TtRecDot(compact: true),
          text:
              'Shooting since 9:41 AM, with a much longer description than '
              'there is room for on one line',
          action: TtButton(
            label: 'Open camera',
            icon: Symbols.videocam_rounded,
            kind: TtButtonKind.text,
            onPressed: () {},
          ),
        ),
      ),
    ],
  );
}
