import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Record dot',
    fileName: 'rec_dot',
    // The live dot never settles: show it 0.3 s into a pulse.
    pumpBeforeTest: (tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
    scenarios: const [
      TtScenario('live (0.3 s into a pulse)', _Labelled(live: true)),
      TtScenario('not live', _Labelled(live: false)),
      TtScenario('live, animations removed', _Reduced()),
    ],
  );
}

class _Labelled extends StatelessWidget {
  const new({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.tt.spacing.m),
    child: Row(
      children: [
        TtRecDot(live: live),
        SizedBox(width: context.tt.spacing.s),
        const Text('Recording'),
      ],
    ),
  );
}

class _Reduced extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: const _Labelled(live: true),
  );
}
