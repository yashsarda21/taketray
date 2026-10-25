import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Skeleton',
    fileName: 'skeleton',
    // The shimmer never settles: show it 0.4 s into a sweep, when the band
    // is across the middle of the tile.
    pumpBeforeTest: (tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
    scenarios: const [
      TtScenario('tile (0.4 s into a sweep)', TtClipTileSkeleton(), width: 107),
      TtScenario('line', _Line(), width: 360),
      TtScenario('lines, 40 % and 75 %', _Lines(), width: 360),
      TtScenario('tile, animations removed', _Reduced(), width: 107),
    ],
  );
}

class _Line extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.tt.spacing.m),
    child: const TtSkeletonLine(),
  );
}

class _Lines extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.tt.spacing.m),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.tt.spacing.xs,
      children: const [TtSkeletonLine(), TtSkeletonLine(widthFactor: 0.75)],
    ),
  );
}

/// The tile with "remove animations" on: plain, with no band.
class _Reduced extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: const TtClipTileSkeleton(),
  );
}
