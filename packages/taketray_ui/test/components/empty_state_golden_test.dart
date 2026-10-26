import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The width of an illustration.
const _ill = 168.0;

String _title(TtIllustrationKind kind) => switch (kind) {
  TtIllustrationKind.caught => 'caught',
  TtIllustrationKind.shootOff => 'shoot off',
  TtIllustrationKind.noReels => 'no reels',
  TtIllustrationKind.emptyReel => 'empty reel',
  TtIllustrationKind.folder => 'folder',
  TtIllustrationKind.permission => 'permission',
  TtIllustrationKind.skipped => 'skipped',
};

void main() {
  ttGoldenTest(
    'Illustrations',
    fileName: 'illustrations',
    scenarios: [
      for (final kind in TtIllustrationKind.values)
        TtScenario(_title(kind), TtIllustration(kind), width: _ill),
    ],
  );

  ttGoldenTest(
    'Empty state',
    fileName: 'empty_state',
    scenarios: [
      const TtScenario(
        '0 actions',
        TtEmptyState(
          illustration: TtIllustrationKind.skipped,
          title: 'No skipped clips',
          body:
              'Clips you skip in To tag show up here, in case you change '
              'your mind.',
        ),
      ),
      TtScenario(
        '1 action',
        TtEmptyState(
          illustration: TtIllustrationKind.caught,
          title: 'All caught up',
          body: 'New clips you shoot will show up here.',
          actions: [
            TtButton(
              label: 'Open camera',
              icon: Symbols.videocam_rounded,
              kind: TtButtonKind.tonal,
              onPressed: () {},
            ),
          ],
        ),
      ),
      TtScenario(
        '2 actions',
        TtEmptyState(
          illustration: TtIllustrationKind.shootOff,
          title: 'Nothing to tag',
          body:
              'Turn on Shooting mode before you start filming. New videos '
              'will show up here.',
          actions: [
            TtButton(
              label: 'Turn on Shooting mode',
              icon: Symbols.videocam_rounded,
              onPressed: () {},
            ),
            TtButton(
              label: 'Add videos',
              icon: Symbols.library_add_rounded,
              kind: TtButtonKind.text,
              onPressed: () {},
            ),
          ],
        ),
      ),
      TtScenario(
        'long body, 1 action',
        TtEmptyState(
          illustration: TtIllustrationKind.noReels,
          title: 'Plan your first reel',
          body:
              "A reel is a video you're planning, like London Food or Day 1 "
              'Vlog. Clips you tag go into it. You can also share a reel from '
              'Instagram to save it here as a reference.',
          actions: [
            TtButton(
              label: 'New reel',
              icon: Symbols.add_rounded,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ],
  );
}
