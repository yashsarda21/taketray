import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The bar in a page with 16 dp margins.
const _width = 328.0;

void main() {
  ttGoldenTest(
    'Progress bar',
    fileName: 'progress',
    // The indeterminate bar never settles: show it 0.7 s into a slide.
    pumpBeforeTest: (tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    },
    scenarios: const [
      TtScenario('0 %', TtProgressBar(value: 0), width: _width),
      TtScenario('40 %', TtProgressBar(value: 0.4), width: _width),
      TtScenario('100 %', TtProgressBar(value: 1), width: _width),
      TtScenario(
        'indeterminate (0.7 s into a slide)',
        TtProgressBar(),
        width: _width,
      ),
      TtScenario(
        'with label',
        TtProgressBar(value: 0.58, label: '7 of 12 clips'),
        width: _width,
      ),
      TtScenario(
        'long label',
        TtProgressBar(
          value: 0.58,
          label: '7 of 12 clips copied into Movies/TakeTray/London Food',
        ),
        width: _width,
      ),
      TtScenario(
        'indeterminate, animations removed',
        _Reduced(),
        width: _width,
      ),
    ],
  );
}

/// The indeterminate bar with "remove animations" on: still, in the middle.
class _Reduced extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: const TtProgressBar(label: 'Looking for clips'),
  );
}
