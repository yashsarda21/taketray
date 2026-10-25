import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Scene and day headers',
    fileName: 'headers',
    scenarios: [
      TtScenario('scene header', _scene(title: '9:41 – 10:05 AM')),
      TtScenario(
        'scene header, long title',
        _scene(
          title:
              'Friday 12 June, 9:41 AM – Saturday 13 June, 10:05 AM '
              '(the whole weekend away)',
          subtitle: '1,204 clips · 12:30:45 in total',
        ),
      ),
      const TtScenario(
        'day header with trailing text',
        TtDayHeader(title: 'Day 2 · Sat 13 Jun', trailing: '14 clips'),
      ),
      const TtScenario('day header', TtDayHeader(title: 'Today')),
      const TtScenario(
        'day header, long title',
        TtDayHeader(
          title: 'Day 12 · Wednesday 12 November, in a long place name',
          trailing: '1,204 clips',
        ),
      ),
    ],
  );
}

Widget _scene({required String title, String subtitle = '8 clips · 2:14'}) =>
    TtSceneHeader(
      title: title,
      subtitle: subtitle,
      action: TtButton(
        label: 'Tag scene',
        icon: Symbols.sell_rounded,
        kind: TtButtonKind.tonal,
        size: TtButtonSize.small,
        onPressed: () {},
      ),
    );
