import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

TtIllustratedSteps _steps(List<TtIllustratedStep> steps) =>
    TtIllustratedSteps(steps: steps);

void main() {
  ttGoldenTest(
    'Illustrated steps',
    fileName: 'illustrated_steps',
    scenarios: [
      TtScenario(
        'the three steps of VN',
        _steps([
          const TtIllustratedStep.newProject(
            number: 'Step 1',
            title: 'Open VN, tap New project',
            body: "It's the big + button.",
          ),
          TtIllustratedStep.folders(
            number: 'Step 2',
            title: 'Open the Café Hopping Bengaluru folder',
            body: 'Inside Movies › TakeTray.',
            folders: [
              'Camera',
              'Download',
              'Café Hopping Bengaluru',
              'WhatsApp Video',
            ],
            highlighted: 2,
          ),
          TtIllustratedStep.tiles(
            number: 'Step 3',
            title: 'Select all the clips',
            body: "They're already in shooting order.",
            thumbnails: [for (var i = 1; i <= 6; i++) fixtureThumb(i)],
          ),
        ]),
      ),
      TtScenario(
        'two folders, the first highlighted; two tiles',
        _steps([
          TtIllustratedStep.folders(
            number: 'Step 2',
            title: 'Open the Reel 1 folder',
            body: 'Inside Movies › TakeTray, a very long folder name.',
            folders: ['Reel 1', 'A very long folder name that is cut'],
            highlighted: 0,
          ),
          TtIllustratedStep.tiles(
            number: 'Step 3',
            title: 'Select the clips',
            body: 'Two clips only.',
            thumbnails: [fixtureThumb(1), fixtureThumb(2)],
          ),
        ]),
      ),
      TtScenario(
        'seven thumbnails (six shown); none',
        _steps([
          TtIllustratedStep.tiles(
            number: 'Step 3',
            title: 'Select all the clips',
            body: 'A reel with more clips than the picture holds.',
            thumbnails: [for (var i = 0; i < 7; i++) fixtureThumb(i % 6 + 1)],
          ),
          const TtIllustratedStep.tiles(
            number: 'Step 3',
            title: 'Select all the clips',
            body: 'Every clip is gone.',
            thumbnails: [],
          ),
        ]),
      ),
    ],
  );
}
