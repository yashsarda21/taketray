import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Nav pill',
    fileName: 'nav_pill',
    scenarios: [
      for (var i = 0; i < 3; i++)
        TtScenario('selected $i', _OverContent(currentIndex: i)),
      const TtScenario('badge 7', _OverContent(currentIndex: 0, badge: 7)),
      const TtScenario(
        'badge 120, To tag selected',
        _OverContent(currentIndex: 1, badge: 120),
      ),
      const TtScenario(
        'long label',
        _OverContent(currentIndex: 2, third: 'Settings and preferences'),
      ),
    ],
  );
}

/// The pill at the bottom of a screen with a photo behind it, so the glass
/// shows.
class _OverContent extends StatelessWidget {
  const new({
    required this.currentIndex,
    this.badge = 0,
    this.third = 'Settings',
  });

  final int currentIndex;
  final int badge;
  final String third;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(image: fixtureThumb(3), fit: BoxFit.cover),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: TtNavPill(
          currentIndex: currentIndex,
          onSelected: (_) {},
          items: [
            const TtNavItem(
              icon: Symbols.video_library_rounded,
              label: 'Reels',
            ),
            TtNavItem(
              icon: Symbols.sell_rounded,
              label: 'To tag',
              badgeCount: badge,
              badgeSemanticLabel: '$badge clips waiting',
            ),
            TtNavItem(icon: Symbols.settings_rounded, label: third),
          ],
        ),
      ),
    ),
  );
}
