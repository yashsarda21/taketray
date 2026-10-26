import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Count badge',
    fileName: 'badges',
    scenarios: [
      for (final count in const [1, 9, 99, 100])
        TtScenario('count $count', _Hosted(count)),
      const TtScenario('count 0 (hidden)', _Hosted(0)),
    ],
  );
}

/// A badge on the corner of a glass nav icon, then on its own.
class _Hosted extends StatelessWidget {
  const new(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.tt.spacing.m),
    child: Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            TtGlass(
              radius: 26,
              shadow: false,
              child: Padding(
                padding: EdgeInsets.all(context.tt.spacing.s),
                child: const Icon(Symbols.video_library_rounded),
              ),
            ),
            PositionedDirectional(
              start: 30,
              top: -4,
              child: TtCountBadge(count: count),
            ),
          ],
        ),
        SizedBox(width: context.tt.spacing.l),
        TtCountBadge(count: count),
      ],
    ),
  );
}
