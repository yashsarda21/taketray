import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The width of the floating snack on a 360 dp screen (16 dp each side).
const _width = 328.0;

void main() {
  ttGoldenTest(
    'Snack',
    fileName: 'snack',
    scenarios: [
      const TtScenario('plain', TtSnack(message: 'Undone'), width: _width),
      const TtScenario(
        'with icon',
        TtSnack(message: 'Backup saved', icon: Symbols.check_circle_rounded),
        width: _width,
      ),
      TtScenario(
        'with Undo',
        TtSnack(
          message: 'Added to London Food',
          icon: Symbols.check_circle_rounded,
          actionLabel: 'Undo',
          onAction: () {},
        ),
        width: _width,
      ),
      TtScenario(
        'long message',
        TtSnack(
          message:
              'Removed 3 clips from Autumn recipes from the farmers market '
              'and the old town',
          icon: Symbols.check_circle_rounded,
          actionLabel: 'Undo',
          onAction: () {},
        ),
        width: _width,
      ),
    ],
  );
}
